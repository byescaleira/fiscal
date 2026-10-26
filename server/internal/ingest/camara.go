package ingest

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/camara"
)

const (
	maxCSVBytes = 512 << 20
	maxZipBytes = 256 << 20
	speechTrip  = 40
)

var errSpeechesDown = errors.New("camara speeches: source failing, skipped")

type camaraResult struct {
	people          []*publicdata.Person
	votes           []*publicdata.HouseVote
	laws            []publicdata.LawEvent
	quotaTotal      *int64
	quotaByCategory map[string]int64
}

type camaraDeputy struct {
	detail    camara.Detail
	history   []camara.Status
	historyOK bool
	onLeave   bool
	person    *publicdata.Person
}

func (in *Ingest) api() camara.API {
	return camara.API{Get: in.get}
}

func (in *Ingest) openCSV(ctx context.Context, url string, fn func(f *os.File) error) error {
	c, err := in.get.Cache(ctx, url, maxCSVBytes)
	if err != nil {
		return err
	}
	f, err := os.Open(c.Path)
	if err != nil {
		return err
	}
	defer f.Close()
	return fn(f)
}

func (in *Ingest) loadCamara(ctx context.Context, rep *Report) (camaraResult, error) {
	var res camaraResult
	api := in.api()
	list, err := api.Deputies(ctx)
	if err != nil {
		return res, err
	}
	if len(list) < 400 && len(in.cfg.UFs) == 0 {
		return res, fmt.Errorf("only %d deputies listed; refusing to publish a partial chamber", len(list))
	}
	deps := map[int64]*camaraDeputy{}
	var ids []int64
	for _, d := range list {
		if !in.cfg.wantUF(d.UF) {
			continue
		}
		deps[d.ID] = &camaraDeputy{detail: camara.Detail{Deputy: d}}
		ids = append(ids, d.ID)
	}
	in.forEach(ids, func(id int64) {
		cd := deps[id]
		if det, err := api.Deputy(ctx, id); err == nil {
			cd.detail = det
		} else {
			in.warn(rep, "camara deputy %d detail: %v", id, err)
		}
		if h, err := api.History(ctx, id); err == nil {
			cd.history, cd.historyOK = h, true
		} else {
			in.warn(rep, "camara deputy %d history: %v", id, err)
		}
	})
	years := in.cfg.Years
	byYear := map[int]*camaraYear{}
	quota := map[string]int64{}
	var quotaTotal int64
	quotaLoaded := false
	extra := map[int64]bool{}
	for _, y := range years {
		cy, err := in.loadCamaraYear(ctx, y, deps)
		if err != nil {
			return res, fmt.Errorf("%d: %w", y, err)
		}
		byYear[y] = cy
		for id, uf := range cy.voters {
			if _, ok := deps[id]; !ok && in.cfg.wantUF(uf) {
				extra[id] = true
			}
		}
		res.laws = append(res.laws, cy.laws...)
		if y == in.currentYear() {
			quotaLoaded = cy.quotaLoaded
			quotaTotal = cy.quotaTotal
			for k, v := range cy.quotaByCategory {
				quota[k] += v
			}
		}
	}
	var extraIDs []int64
	for id := range extra {
		extraIDs = append(extraIDs, id)
	}
	sort.Slice(extraIDs, func(i, j int) bool { return extraIDs[i] < extraIDs[j] })
	var mu sync.Mutex
	in.forEach(extraIDs, func(id int64) {
		det, err := api.Deputy(ctx, id)
		if err != nil || det.Situation != "Licença" {
			return
		}
		cd := &camaraDeputy{detail: det, onLeave: true}
		if h, err := api.History(ctx, id); err == nil {
			cd.history, cd.historyOK = h, true
		}
		mu.Lock()
		deps[id] = cd
		ids = append(ids, id)
		mu.Unlock()
	})
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	committees := map[int64][]publicdata.Committee{}
	err = in.openCSV(ctx, camara.CommitteesURL(camara.Legislature), func(f *os.File) error {
		return camara.ReadCommittees(f, func(c camara.Committee) {
			if _, ok := deps[c.DeputyID]; !ok {
				return
			}
			committees[c.DeputyID] = append(committees[c.DeputyID], publicdata.Committee{Name: c.Name, Role: c.Role, Start: dateOnly(c.Start), End: dateOnly(c.End)})
		})
	})
	if err != nil {
		in.warn(rep, "camara committees: %v", err)
	}
	for _, id := range ids {
		cd := deps[id]
		p := deputyPerson(cd)
		p.Committees = committees[id]
		p.Activity = map[int]*publicdata.YearActivity{}
		for _, y := range years {
			cy := byYear[y]
			act := &publicdata.YearActivity{Year: y, Proposals: cy.proposals[id], Expenses: cy.expenses[id]}
			if cd.historyOK {
				pres, elig := attendance(cy, id, exercise(cd.history))
				act.Present, act.Eligible = &pres, &elig
			}
			p.Activity[y] = act
		}
		if !cd.historyOK {
			p.Coverage = map[string]publicdata.Coverage{"attendance": {Kind: "attendance", Status: publicdata.CoverageNotLoaded, Source: "camara"}}
		}
		cd.person = p
		res.people = append(res.people, p)
	}
	speechFailed := map[int64]bool{}
	type job struct {
		id   int64
		year int
	}
	var jobs []job
	for _, id := range ids {
		for _, y := range years {
			jobs = append(jobs, job{id, y})
		}
	}
	var smu sync.Mutex
	streak, tripped := 0, false
	forEachJob(in.cfg.Workers, len(jobs), func(i int) {
		j := jobs[i]
		smu.Lock()
		skip := tripped
		smu.Unlock()
		var sp []camara.Speech
		err := errSpeechesDown
		if !skip {
			sp, err = in.camaraSpeeches(ctx, j.id, j.year)
		}
		smu.Lock()
		defer smu.Unlock()
		if err != nil {
			speechFailed[j.id] = true
			if skip {
				return
			}
			in.warn(rep, "camara speeches %d/%d: %v", j.id, j.year, err)
			if streak++; streak >= speechTrip && !tripped {
				tripped = true
				in.warn(rep, "camara speeches: %d failures in a row, skipping the remaining deputies", streak)
			}
			return
		}
		streak = 0
		act := deps[j.id].person.Activity[j.year]
		for _, s := range sp {
			act.Speeches = append(act.Speeches, publicdata.RawSpeech{Date: in.isoLocal(s.Start), Kind: s.Kind, Summary: s.Summary, Keywords: s.Keywords, URL: s.URL})
		}
	})
	for id := range speechFailed {
		p := deps[id].person
		if p.Coverage == nil {
			p.Coverage = map[string]publicdata.Coverage{}
		}
		p.Coverage["speeches"] = publicdata.Coverage{Kind: "speeches", Status: publicdata.CoverageNotLoaded, Source: "camara"}
	}
	for _, y := range years {
		res.votes = append(res.votes, byYear[y].votes...)
	}
	if quotaLoaded {
		res.quotaTotal = &quotaTotal
	}
	res.quotaByCategory = quota
	return res, nil
}

func deputyPerson(cd *camaraDeputy) *publicdata.Person {
	d := cd.detail
	status := publicdata.StatusInOffice
	if cd.onLeave {
		status = publicdata.StatusOnLeave
	}
	start := ""
	for _, h := range cd.history {
		if h.Legislature == camara.Legislature && h.Situation == "Exercício" {
			start = dateOnlyStr(h.Time)
			break
		}
	}
	name := d.Name
	if name == "" {
		name = publicdata.TitleName(d.ElectoralName)
	}
	p := &publicdata.Person{
		Keys:      []string{"camara:" + strconv.FormatInt(d.ID, 10)},
		Name:      strings.TrimSpace(name),
		CivilName: publicdata.TitleName(d.CivilName),
		CPF:       digits(d.CPF),
		Roles:     []publicdata.Role{{Office: publicdata.OfficeFederalDeputy, UF: strings.ToLower(d.UF), Status: status, Party: d.Party, MandateStart: start, MandateEnd: "2027-01-31"}},
		Photo:     d.Photo,
		BirthDate: d.BirthDate,
		Education: d.Education,
		House:     publicdata.HouseCamara,
		HouseID:   d.ID,
		SourceIDs: []string{"camara"},
	}
	if d.BirthCity != "" {
		p.BirthPlace = d.BirthCity
		if d.BirthUF != "" {
			p.BirthPlace += ", " + d.BirthUF
		}
	}
	email := d.OfficeEmail
	if email == "" {
		email = d.Email
	}
	office := ""
	if d.Room != "" {
		office = "Gabinete " + d.Room
		if d.Building != "" {
			office += ", Anexo " + d.Building
		}
	}
	phone := ""
	if d.Phone != "" {
		phone = "(61) " + d.Phone
	}
	if email != "" || phone != "" || office != "" {
		p.Contact = &publicdata.Contact{Email: nilIfEmpty(email), Phone: nilIfEmpty(phone), Office: nilIfEmpty(office)}
	}
	return p
}

type camaraYear struct {
	year            int
	proposals       map[int64][]publicdata.RawProposal
	expenses        map[int64][]publicdata.Expense
	sessions        map[int64]string
	presence        map[int64]map[int64]bool
	votes           []*publicdata.HouseVote
	voters          map[int64]string
	laws            []publicdata.LawEvent
	quotaLoaded     bool
	quotaTotal      int64
	quotaByCategory map[string]int64
}

func (in *Ingest) loadCamaraYear(ctx context.Context, y int, deps map[int64]*camaraDeputy) (*camaraYear, error) {
	cy := &camaraYear{year: y, proposals: map[int64][]publicdata.RawProposal{}, expenses: map[int64][]publicdata.Expense{}, sessions: map[int64]string{}, presence: map[int64]map[int64]bool{}, voters: map[int64]string{}, quotaByCategory: map[string]int64{}}
	authors := map[int64][]int64{}
	err := in.openCSV(ctx, camara.AnnualURL("proposicoesAutores", y), func(f *os.File) error {
		return camara.ReadAuthors(f, func(a camara.Authorship) {
			if _, ok := deps[a.DeputyID]; ok && a.Proponent {
				authors[a.PropositionID] = append(authors[a.PropositionID], a.DeputyID)
			}
		})
	})
	if err != nil {
		return nil, fmt.Errorf("authors: %w", err)
	}
	since := in.now().In(in.loc).AddDate(0, 0, -7).Format("2006-01-02")
	err = in.openCSV(ctx, camara.AnnualURL("proposicoes", y), func(f *os.File) error {
		return camara.ReadPropositions(f, nil, func(p camara.Proposition) {
			if who, ok := authors[p.ID]; ok {
				rp := publicdata.RawProposal{ID: "camara-" + strconv.FormatInt(p.ID, 10), Kind: p.Kind, Number: p.Number, Year: p.Year, Ementa: p.Ementa, Keywords: p.Keywords, URL: camara.PropositionURL(p.ID), Date: dateOnlyStr(p.Presented)}
				for _, d := range who {
					cy.proposals[d] = append(cy.proposals[d], rp)
				}
			}
			if strings.Contains(strings.ToLower(p.Situation), "transformad") && dateOnlyStr(p.StatusDate) >= since {
				cy.laws = append(cy.laws, publicdata.LawEvent{ID: "camara-" + strconv.FormatInt(p.ID, 10), Title: fmt.Sprintf("%s %d/%d", p.Kind, p.Number, p.Year), Ementa: p.Ementa, Date: dateOnlyStr(p.StatusDate)})
			}
		})
	})
	if err != nil {
		return nil, fmt.Errorf("propositions: %w", err)
	}
	plenary := map[int64]bool{}
	if err := in.openCSV(ctx, camara.AnnualURL("eventosOrgaos", y), func(f *os.File) error {
		return camara.ReadEventOrgans(f, func(e, o int64) {
			if o == camara.PlenaryID {
				plenary[e] = true
			}
		})
	}); err != nil {
		return nil, fmt.Errorf("event organs: %w", err)
	}
	if err := in.openCSV(ctx, camara.AnnualURL("eventos", y), func(f *os.File) error {
		return camara.ReadEvents(f, func(e camara.Event) {
			if plenary[e.ID] && e.Type == "Sessão Deliberativa" && e.Situation == "Encerrada" {
				cy.sessions[e.ID] = dateOnlyStr(e.Start)
			}
		})
	}); err != nil {
		return nil, fmt.Errorf("events: %w", err)
	}
	if err := in.openCSV(ctx, camara.AnnualURL("eventosPresencaDeputados", y), func(f *os.File) error {
		return camara.ReadPresence(f, func(p camara.Presence) {
			if _, ok := cy.sessions[p.EventID]; !ok {
				return
			}
			if cy.presence[p.EventID] == nil {
				cy.presence[p.EventID] = map[int64]bool{}
			}
			cy.presence[p.EventID][p.DeputyID] = true
		})
	}); err != nil {
		return nil, fmt.Errorf("presence: %w", err)
	}
	votes, err := in.camaraVotes(ctx, y)
	if err != nil {
		return nil, err
	}
	cy.votes = votes
	for _, v := range votes {
		for _, b := range v.Ballots {
			if id, err := strconv.ParseInt(strings.TrimPrefix(b.PersonKey, "camara:"), 10, 64); err == nil {
				cy.voters[id] = strings.ToLower(b.UF)
			}
		}
	}
	c, err := in.get.Cache(ctx, camara.CEAPURL(y), maxZipBytes)
	if err != nil {
		return nil, fmt.Errorf("ceap: %w", err)
	}
	n := 0
	err = camara.ReadExpensesZip(c.Path, func(e camara.Expense) {
		cy.quotaLoaded = true
		cy.quotaTotal += e.Cents
		cy.quotaByCategory[categoryName(e.Category)] += e.Cents
		if _, ok := deps[e.DeputyID]; !ok {
			return
		}
		n++
		id := e.DocumentID
		if id == "" || id == "0" {
			id = fmt.Sprintf("%d-%d", e.DeputyID, n)
		}
		cy.expenses[e.DeputyID] = append(cy.expenses[e.DeputyID], publicdata.Expense{ID: "camara-" + id, Year: e.Year, Month: e.Month, Category: categoryName(e.Category), Supplier: strings.TrimSpace(e.Supplier), Document: cnpj(e.SupplierID), Cents: e.Cents, URL: nilIfEmpty(e.URL)})
	})
	if err != nil {
		return nil, fmt.Errorf("ceap: %w", err)
	}
	return cy, nil
}

func (in *Ingest) camaraVotes(ctx context.Context, y int) ([]*publicdata.HouseVote, error) {
	byID := map[string]*publicdata.HouseVote{}
	var order []*publicdata.HouseVote
	if err := in.openCSV(ctx, camara.AnnualURL("votacoes", y), func(f *os.File) error {
		return camara.ReadVotes(f, func(v camara.Vote) {
			if hv := camaraHouseVote(v); hv != nil {
				byID[v.ID] = hv
				order = append(order, hv)
			}
		})
	}); err != nil {
		return nil, fmt.Errorf("votes: %w", err)
	}
	if err := in.openCSV(ctx, camara.AnnualURL("votacoesProposicoes", y), func(f *os.File) error {
		return camara.ReadVotePropositions(f, func(p camara.VoteProposition) {
			if hv, ok := byID[p.VoteID]; ok && hv.Proposition == "" {
				applyVoteProposition(hv, p)
			}
		})
	}); err != nil {
		return nil, fmt.Errorf("vote propositions: %w", err)
	}
	if err := in.openCSV(ctx, camara.AnnualURL("votacoesOrientacoes", y), func(f *os.File) error {
		return camara.ReadGuidance(f, func(g camara.Guidance) {
			if hv, ok := byID[g.VoteID]; ok {
				hv.Guidance = append(hv.Guidance, publicdata.PartyGuidance{Party: g.Bloc, Guidance: g.Guidance})
			}
		})
	}); err != nil {
		return nil, fmt.Errorf("guidance: %w", err)
	}
	if err := in.openCSV(ctx, camara.AnnualURL("votacoesVotos", y), func(f *os.File) error {
		return camara.ReadBallots(f, func(b camara.Ballot) {
			if hv, ok := byID[b.VoteID]; ok {
				hv.Ballots = append(hv.Ballots, camaraBallot(b))
			}
		})
	}); err != nil {
		return nil, fmt.Errorf("ballots: %w", err)
	}
	for _, hv := range order {
		finishCamaraVote(hv)
	}
	return order, nil
}

func camaraHouseVote(v camara.Vote) *publicdata.HouseVote {
	if v.OrganID != camara.PlenaryID || v.EventID == 0 {
		return nil
	}
	hv := &publicdata.HouseVote{ID: "camara-" + v.ID, House: publicdata.HouseCamara, Date: v.Date, Time: clock(v.Registered), Description: v.Description, Approved: v.Approved}
	hv.Result = resultFor(v.Approved, v.Description)
	hv.Yes, hv.No, hv.Others = ptrInt(v.Yes), ptrInt(v.No), ptrInt(v.Others)
	return hv
}

func applyVoteProposition(hv *publicdata.HouseVote, p camara.VoteProposition) {
	hv.Proposition = p.Title
	if hv.Proposition == "" && p.Kind != "" {
		hv.Proposition = fmt.Sprintf("%s %d/%d", p.Kind, p.Number, p.Year)
	}
	hv.Kind = p.Kind
	hv.Ementa = p.Ementa
}

func camaraBallot(b camara.Ballot) publicdata.Ballot {
	return publicdata.Ballot{PersonKey: "camara:" + strconv.FormatInt(b.DeputyID, 10), Name: b.Name, Party: b.Party, UF: b.UF, Vote: b.Vote, Present: true}
}

func finishCamaraVote(hv *publicdata.HouseVote) {
	hv.Nominal = len(hv.Ballots) > 0
	if !hv.Nominal {
		hv.Yes, hv.No, hv.Others = nil, nil, nil
		hv.Guidance = nil
	}
}

var otherResults = map[string]string{
	"mantido": "Mantido", "mantida": "Mantida", "prejudicado": "Prejudicado", "prejudicada": "Prejudicada",
	"retirado": "Retirado", "retirada": "Retirada", "adiada": "Adiada", "adiado": "Adiado", "encerrada": "Encerrada",
}

func resultFor(approved *bool, description string) string {
	if approved != nil {
		if *approved {
			return "Aprovada"
		}
		return "Rejeitada"
	}
	first := strings.ToLower(strings.Trim(strings.SplitN(strings.TrimSpace(description), " ", 2)[0], ",.;"))
	return otherResults[first]
}

func exercise(history []camara.Status) [][2]string {
	hs := append([]camara.Status(nil), history...)
	sort.SliceStable(hs, func(i, j int) bool { return hs[i].Time < hs[j].Time })
	var out [][2]string
	open := ""
	for _, h := range hs {
		switch {
		case h.Situation == "Exercício":
			if open == "" {
				open = dateOnlyStr(h.Time)
			}
		case h.Situation != "":
			if open != "" {
				out = append(out, [2]string{open, dateOnlyStr(h.Time)})
				open = ""
			}
		}
	}
	if open != "" {
		out = append(out, [2]string{open, "9999-12-31"})
	}
	return out
}

func attendance(cy *camaraYear, id int64, intervals [][2]string) (int, int) {
	present, eligible := 0, 0
	for ev, day := range cy.sessions {
		list := cy.presence[ev]
		if len(list) == 0 {
			continue
		}
		in := false
		for _, iv := range intervals {
			if day >= iv[0] && day < iv[1] {
				in = true
				break
			}
		}
		if !in {
			continue
		}
		eligible++
		if list[id] {
			present++
		}
	}
	return present, eligible
}

func categoryName(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return "Outros"
	}
	s = strings.Join(strings.Fields(s), " ")
	if s == strings.ToUpper(s) {
		s = strings.ToLower(s)
	}
	return strings.TrimSuffix(publicdata.Sentence(s), ".")
}

func (in *Ingest) camaraSpeeches(ctx context.Context, id int64, y int) ([]camara.Speech, error) {
	api := in.api()
	from, to := yearRange(y, in.today())
	sp, err := api.Speeches(ctx, id, from, to)
	if err == nil {
		return sp, nil
	}
	var out []camara.Speech
	for m := 1; m <= 12; m++ {
		start := fmt.Sprintf("%d-%02d-01", y, m)
		if start > to {
			break
		}
		end := fmt.Sprintf("%d-%02d-%02d", y, m, daysIn(y, m))
		if end > to {
			end = to
		}
		part, perr := api.Speeches(ctx, id, start, end)
		if perr != nil {
			return nil, fmt.Errorf("%s..%s: %w", start, end, perr)
		}
		out = append(out, part...)
	}
	return out, nil
}

func daysIn(y, m int) int {
	return time.Date(y, time.Month(m)+1, 0, 0, 0, 0, 0, time.UTC).Day()
}
