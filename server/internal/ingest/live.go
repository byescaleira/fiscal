package ingest

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/camara"
	"liveresults/internal/sources/senado"
)

func (in *Ingest) refreshLive(ctx context.Context, ds *publicdata.Dataset, rep *Report) {
	prev := map[string]publicdata.RawAgendaHouse{}
	for _, h := range ds.Agenda {
		prev[h.House] = h
	}
	var agenda []publicdata.RawAgendaHouse
	if in.cfg.Enabled("camara") {
		h, err := in.camaraAgenda(ctx)
		if err != nil {
			in.warn(rep, "camara agenda: %v", err)
			if p, ok := prev[publicdata.HouseCamara]; ok {
				h = p
			}
		}
		if h.House != "" {
			agenda = append(agenda, h)
		}
		votes, err := in.camaraTodayVotes(ctx)
		if err != nil {
			in.warn(rep, "camara votes today: %v", err)
		}
		ds.Votes = upsertVotes(ds.Votes, votes)
	}
	if in.cfg.Enabled("senado") {
		h, err := in.senadoAgenda(ctx)
		if err != nil {
			in.warn(rep, "senado agenda: %v", err)
			if p, ok := prev[publicdata.HouseSenado]; ok {
				h = p
			}
		}
		if h.House != "" {
			agenda = append(agenda, h)
		}
		vs, err := in.senadoAPI().Votes(ctx, in.today(), in.today())
		if err != nil {
			in.warn(rep, "senado votes today: %v", err)
		}
		var hv []*publicdata.HouseVote
		for _, v := range vs {
			hv = append(hv, senadoHouseVote(v))
		}
		ds.Votes = upsertVotes(ds.Votes, hv)
	}
	ds.Agenda = agenda
	ds.Races = in.races()
}

func upsertVotes(all, fresh []*publicdata.HouseVote) []*publicdata.HouseVote {
	if len(fresh) == 0 {
		return all
	}
	idx := map[string]int{}
	for i, v := range all {
		idx[v.ID] = i
	}
	for _, v := range fresh {
		if i, ok := idx[v.ID]; ok {
			all[i] = v
			continue
		}
		idx[v.ID] = len(all)
		all = append(all, v)
	}
	return all
}

func (in *Ingest) localTime(s string) (time.Time, bool) {
	for _, layout := range []string{"2006-01-02T15:04:05", "2006-01-02T15:04", "2006-01-02 15:04"} {
		if t, err := time.ParseInLocation(layout, s, in.loc); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

func (in *Ingest) isoLocal(s string) string {
	if t, ok := in.localTime(s); ok {
		return t.Format(time.RFC3339)
	}
	return dateOnlyStr(s)
}

func (in *Ingest) camaraAgenda(ctx context.Context) (publicdata.RawAgendaHouse, error) {
	api := in.api()
	today := in.today()
	h := publicdata.RawAgendaHouse{House: publicdata.HouseCamara}
	events, err := api.PlenaryEvents(ctx, today, today)
	if err != nil {
		return publicdata.RawAgendaHouse{}, err
	}
	for _, e := range events {
		if strings.EqualFold(e.Situation, "Cancelada") {
			continue
		}
		if strings.Contains(publicdata.Fold(e.Situation), "andamento") {
			h.InSession = true
		}
		title := "Sessão no Plenário da Câmara"
		summary := e.Description
		if t, ok := in.localTime(e.Start); ok {
			summary = fmt.Sprintf("%s, às %s.", strings.TrimSuffix(e.Description, "."), t.Format("15h04"))
		}
		h.Sessions = append(h.Sessions, publicdata.RawSession{Title: title, Summary: summary, URL: e.URL})
		items, err := api.Agenda(ctx, e.ID)
		if err != nil {
			return publicdata.RawAgendaHouse{}, err
		}
		for _, it := range items {
			prop := it.Title
			if it.Kind != "" && it.Number > 0 && it.Year > 0 {
				prop = fmt.Sprintf("%s %d/%d", it.Kind, it.Number, it.Year)
			}
			url := ""
			if it.PropositionID != 0 {
				url = camara.PropositionURL(it.PropositionID)
			}
			h.Items = append(h.Items, publicdata.RawAgendaItem{Proposition: prop, Ementa: it.Ementa, Status: it.Topic, URL: url})
		}
	}
	now := in.now()
	until := now.In(in.loc).AddDate(0, 0, 14).Format("2006-01-02")
	next, err := api.PlenaryEvents(ctx, today, until)
	if err != nil {
		return h, nil
	}
	for _, e := range next {
		t, ok := in.localTime(e.Start)
		if !ok || !t.After(now) || strings.EqualFold(e.Situation, "Cancelada") || strings.EqualFold(e.Situation, "Encerrada") {
			continue
		}
		h.NextSession = t.Format(time.RFC3339)
		break
	}
	return h, nil
}

func (in *Ingest) senadoAgenda(ctx context.Context) (publicdata.RawAgendaHouse, error) {
	api := in.senadoAPI()
	today := in.today()
	h := publicdata.RawAgendaHouse{House: publicdata.HouseSenado}
	sessions, err := api.Agenda(ctx, today)
	if err != nil {
		return publicdata.RawAgendaHouse{}, err
	}
	for _, s := range sessions {
		if strings.Contains(publicdata.Fold(s.Situation), "andamento") {
			h.InSession = true
		}
		summary := publicdata.TitleName(s.Type)
		if s.Hour != "" {
			summary = fmt.Sprintf("%s, às %s.", summary, strings.Replace(s.Hour, ":", "h", 1))
		}
		h.Sessions = append(h.Sessions, publicdata.RawSession{Title: "Sessão no Plenário do Senado", Summary: summary})
		for _, m := range s.Matters {
			url := ""
			if m.Code != 0 {
				url = senado.MatterURLBase + strconv.FormatInt(m.Code, 10)
			}
			h.Items = append(h.Items, publicdata.RawAgendaItem{Proposition: m.Identification, Ementa: m.Ementa, Status: m.Stage, URL: url})
		}
	}
	now := in.now()
	local := now.In(in.loc)
	nextMonth := time.Date(local.Year(), local.Month()+1, 1, 0, 0, 0, 0, in.loc).Format("2006-01-02")
	var upcoming []senado.AgendaSession
	for _, from := range []string{today, nextMonth} {
		list, err := api.AgendaMonth(ctx, from)
		if err != nil {
			break
		}
		upcoming = append(upcoming, list...)
	}
	sort.SliceStable(upcoming, func(i, j int) bool { return upcoming[i].Date+upcoming[i].Hour < upcoming[j].Date+upcoming[j].Hour })
	for _, s := range upcoming {
		t, ok := in.localTime(s.Date + " " + s.Hour)
		situation := publicdata.Fold(s.Situation)
		if !ok || !t.After(now) || strings.Contains(situation, "encerrada") || strings.Contains(situation, "cancelada") {
			continue
		}
		h.NextSession = t.Format(time.RFC3339)
		break
	}
	return h, nil
}

func (in *Ingest) camaraTodayVotes(ctx context.Context) ([]*publicdata.HouseVote, error) {
	api := in.api()
	today := in.today()
	list, err := api.PlenaryVotes(ctx, today, today)
	if err != nil {
		return nil, err
	}
	var out []*publicdata.HouseVote
	for _, v := range list {
		detail, props, err := api.VoteDetail(ctx, v.ID)
		if err == nil {
			v = detail
		}
		hv := camaraHouseVote(v)
		if hv == nil {
			continue
		}
		if len(props) > 0 {
			applyVoteProposition(hv, props[0])
		}
		if g, err := api.Guidance(ctx, v.ID); err == nil {
			for _, x := range g {
				hv.Guidance = append(hv.Guidance, publicdata.PartyGuidance{Party: x.Bloc, Guidance: x.Guidance})
			}
		}
		ballots, err := api.Ballots(ctx, v.ID)
		if err != nil {
			return out, err
		}
		yes, no, others := 0, 0, 0
		for _, b := range ballots {
			hv.Ballots = append(hv.Ballots, camaraBallot(b))
			switch publicdata.Fold(b.Vote) {
			case "sim":
				yes++
			case "nao":
				no++
			default:
				others++
			}
		}
		hv.Yes, hv.No, hv.Others = &yes, &no, &others
		finishCamaraVote(hv)
		out = append(out, hv)
	}
	return out, nil
}

type raceFile struct {
	Races []struct {
		ID       string `json:"id"`
		Office   string `json:"office"`
		UF       string `json:"uf"`
		Final    bool   `json:"final"`
		Round    int    `json:"round"`
		Sections struct {
			Percent float64 `json:"percent"`
		} `json:"sections"`
	} `json:"races"`
	FetchedAt string `json:"fetchedAt"`
}

func (in *Ingest) races() []publicdata.RaceEvent {
	data, err := os.ReadFile(filepath.Join(in.cfg.PublicDir, "v1", "races.json"))
	if err != nil {
		return nil
	}
	var rf raceFile
	if json.Unmarshal(data, &rf) != nil || len(rf.Races) == 0 {
		return nil
	}
	t, err := time.Parse(time.RFC3339, rf.FetchedAt)
	if err != nil || t.In(in.loc).Format("2006-01-02") != in.today() {
		return nil
	}
	return []publicdata.RaceEvent{raceSummary(rf)}
}

func raceSummary(rf raceFile) publicdata.RaceEvent {
	var govs []string
	president := ""
	final := true
	round := 0
	for _, r := range rf.Races {
		final = final && r.Final
		if r.Round > round {
			round = r.Round
		}
		if r.Office == "president" {
			president = strings.Replace(strconv.FormatFloat(r.Sections.Percent, 'f', 1, 64), ".", ",", 1) + "% das seções apuradas para presidente"
			continue
		}
		govs = append(govs, strings.ToUpper(r.UF))
	}
	sort.Strings(govs)
	parts := []string{}
	if president != "" {
		parts = append(parts, president)
	}
	if len(govs) > 0 {
		parts = append(parts, "governador em "+joinList(govs))
	}
	title := "Apuração"
	if round > 0 {
		title = fmt.Sprintf("Apuração do %dº turno", round)
	}
	if final {
		title += " encerrada"
	}
	return publicdata.RaceEvent{Title: title, Summary: publicdata.Sentence(strings.Join(parts, "; "))}
}

func joinList(items []string) string {
	switch len(items) {
	case 0:
		return ""
	case 1:
		return items[0]
	}
	return strings.Join(items[:len(items)-1], ", ") + " e " + items[len(items)-1]
}
