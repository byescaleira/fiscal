package ingest

import (
	"context"
	"encoding/json"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"liveresults/internal/datastore"
	"liveresults/internal/publicdata"
	"liveresults/internal/publish"
	"liveresults/internal/sources/comprova"
	"liveresults/internal/sources/ibge"
	"liveresults/internal/sources/tse"
)

func (in *Ingest) UseStore(db *datastore.Store) {
	in.db = db
}

func (in *Ingest) runID() int64 {
	if in.run == nil {
		return 0
	}
	return in.run.ID
}

func (in *Ingest) begin(ctx context.Context, kind string) {
	in.run = nil
	if in.db == nil {
		return
	}
	run, err := in.db.BeginRun(ctx, kind)
	if err != nil {
		in.logger.Printf("store: begin %s run: %v", kind, err)
		return
	}
	in.run = run
}

func (in *Ingest) end(ctx context.Context, rep Report, err error) {
	if in.db == nil || in.run == nil {
		return
	}
	status := datastore.StatusOK
	if err != nil {
		status = datastore.StatusFailed
	}
	counts := map[string]int{"people": rep.People, "votes": rep.Votes, "cities": rep.Cities, "cityPeople": rep.CityPeople, "checks": rep.Checks, "files": rep.Files, "written": rep.Written, "removed": rep.Removed, "warnings": len(rep.Warnings)}
	if e := in.run.Finish(context.WithoutCancel(ctx), status, counts, err); e != nil {
		in.logger.Printf("store: finish run: %v", e)
	}
	if in.run.Kind == "full" {
		if e := in.db.Checkpoint(context.WithoutCancel(ctx)); e != nil {
			in.logger.Printf("store: checkpoint: %v", e)
		}
	}
	in.run = nil
	in.WriteStatus(context.WithoutCancel(ctx))
}

func (in *Ingest) WriteStatus(ctx context.Context) {
	if in.db == nil {
		return
	}
	st, err := in.db.Status(ctx)
	if err != nil {
		in.logger.Printf("store: status: %v", err)
		return
	}
	data, err := json.Marshal(st)
	if err != nil {
		return
	}
	if _, err := publish.WritePair(filepath.Join(in.cfg.PublicDir, "v1", "status.json"), data); err != nil {
		in.logger.Printf("store: status.json: %v", err)
	}
}

type tracker struct {
	in *Ingest
	sr *datastore.SourceRun
}

func (in *Ingest) track(ctx context.Context, source string) tracker {
	t := tracker{in: in}
	if in.db == nil || in.run == nil {
		return t
	}
	sr, err := in.run.Source(ctx, source)
	if err != nil {
		in.logger.Printf("store: track %s: %v", source, err)
		return t
	}
	t.sr = sr
	return t
}

func (t tracker) done(ctx context.Context, status string, counts map[string]int, err error) {
	if t.sr == nil {
		return
	}
	if e := t.sr.Finish(context.WithoutCancel(ctx), status, counts, err); e != nil {
		t.in.logger.Printf("store: finish source: %v", e)
	}
}

type sourceIO struct {
	id, name, url string
	load          func() error
	save          func() (datastore.Counts, error)
	restore       func() (bool, error)
}

func (in *Ingest) withSource(ctx context.Context, rep *Report, srcs *sourceSet, s sourceIO) (bool, error) {
	t := in.track(ctx, s.id)
	err := s.load()
	if err == nil {
		counts := map[string]int{}
		if in.db != nil {
			c, serr := s.save()
			if serr != nil {
				in.warn(rep, "store %s: %v", s.id, serr)
				t.done(ctx, datastore.StatusOK, map[string]int{"storeFailed": 1}, serr)
				return true, nil
			}
			counts = c.Map()
		}
		t.done(ctx, datastore.StatusOK, counts, nil)
		return true, nil
	}
	if in.db != nil && s.restore != nil {
		ok, rerr := s.restore()
		if rerr != nil {
			in.warn(rep, "store %s: restore: %v", s.id, rerr)
		}
		if ok {
			in.warn(rep, "%s: %v (published the last stored read)", s.id, err)
			srcs.keep(s.id, s.name, s.url)
			t.done(ctx, datastore.StatusFallback, nil, err)
			return false, nil
		}
	}
	t.done(ctx, datastore.StatusFailed, nil, err)
	return false, err
}

func (in *Ingest) skipped(ctx context.Context, source string) {
	in.track(ctx, source).done(ctx, datastore.StatusSkipped, nil, nil)
}

func pseudonymizePeople(people []*publicdata.Person) {
	for _, p := range people {
		p.CPF = datastore.Pseudonym(p.CPF)
		for i := range p.Candidacies {
			p.Candidacies[i].CPF = datastore.Pseudonym(p.Candidacies[i].CPF)
		}
	}
}

func pseudonymizeCandidacies(cands []publicdata.Candidacy) {
	for i := range cands {
		cands[i].CPF = datastore.Pseudonym(cands[i].CPF)
	}
}

type quotaSnapshot struct {
	Year       int
	Total      *int64
	ByCategory map[string]int64
}

func quotaPoints(house string, year int, total *int64) []datastore.Point {
	if total == nil || year == 0 {
		return nil
	}
	return []datastore.Point{{Series: "quota.total", Scope: house, Date: strconv.Itoa(year), Value: float64(*total)}}
}

func (in *Ingest) saveHouse(ctx context.Context, house string, people []*publicdata.Person, votes []*publicdata.HouseVote, quota quotaSnapshot, extra []datastore.Snapshot) (datastore.Counts, error) {
	run := in.runID()
	c, err := in.db.PutSourcePeople(ctx, run, house, people, true)
	if err != nil {
		return c, err
	}
	v, err := in.db.PutVotes(ctx, run, house, votes, true)
	if err != nil {
		return c, err
	}
	c = c.Add(v)
	snaps := append([]datastore.Snapshot{{Key: "quota", Value: quota}}, extra...)
	sn, err := in.db.PutSnapshots(ctx, run, house, "", snaps, false)
	if err != nil {
		return c, err
	}
	c = c.Add(sn)
	sr, err := in.db.PutSeries(ctx, run, house, quotaPoints(house, quota.Year, quota.Total))
	return c.Add(sr), err
}

func (in *Ingest) restoreHouse(ctx context.Context, house string, quota *quotaSnapshot) ([]*publicdata.Person, []*publicdata.HouseVote, bool, error) {
	people, err := in.db.SourcePeople(ctx, house)
	if err != nil || len(people) == 0 {
		return nil, nil, false, err
	}
	votes, err := in.db.Votes(ctx, house)
	if err != nil {
		return nil, nil, false, err
	}
	if _, err := in.db.Snapshot(ctx, house, "quota", quota); err != nil {
		return nil, nil, false, err
	}
	return people, votes, true, nil
}

func (in *Ingest) camaraIO(ctx context.Context, rep *Report, cam *camaraResult) sourceIO {
	return sourceIO{
		id: "camara", name: "Câmara dos Deputados", url: "https://dadosabertos.camara.leg.br",
		load: func() error {
			r, err := in.loadCamara(ctx, rep)
			*cam = r
			return err
		},
		save: func() (datastore.Counts, error) {
			return in.saveHouse(ctx, publicdata.HouseCamara, cam.people, cam.votes, quotaSnapshot{Year: in.currentYear(), Total: cam.quotaTotal, ByCategory: cam.quotaByCategory}, []datastore.Snapshot{{Key: "laws", Value: cam.laws}})
		},
		restore: func() (bool, error) {
			var q quotaSnapshot
			people, votes, ok, err := in.restoreHouse(ctx, publicdata.HouseCamara, &q)
			if !ok {
				return false, err
			}
			var laws []publicdata.LawEvent
			if _, err := in.db.Snapshot(ctx, publicdata.HouseCamara, "laws", &laws); err != nil {
				return false, err
			}
			*cam = camaraResult{people: people, votes: votes, laws: laws, quotaTotal: q.Total, quotaByCategory: q.ByCategory}
			return true, nil
		},
	}
}

func (in *Ingest) senadoIO(ctx context.Context, rep *Report, sen *senadoResult) sourceIO {
	return sourceIO{
		id: "senado", name: "Senado Federal", url: "https://legis.senado.leg.br/dadosabertos",
		load: func() error {
			r, err := in.loadSenado(ctx, rep)
			*sen = r
			return err
		},
		save: func() (datastore.Counts, error) {
			return in.saveHouse(ctx, publicdata.HouseSenado, sen.people, sen.votes, quotaSnapshot{Year: in.currentYear(), Total: sen.quotaTotal, ByCategory: sen.quotaByCategory}, nil)
		},
		restore: func() (bool, error) {
			var q quotaSnapshot
			people, votes, ok, err := in.restoreHouse(ctx, publicdata.HouseSenado, &q)
			if !ok {
				return false, err
			}
			*sen = senadoResult{people: people, votes: votes, quotaTotal: q.Total, quotaByCategory: q.ByCategory}
			return true, nil
		},
	}
}

func (in *Ingest) ibgeIO(ctx context.Context, muns *[]publicdata.PlaceEntry) sourceIO {
	return sourceIO{
		id: "ibge", name: "IBGE", url: ibge.SiteURL,
		load: func() error {
			r, err := in.loadIBGE(ctx)
			*muns = r
			return err
		},
		save: func() (datastore.Counts, error) {
			return in.db.PutPlaces(ctx, in.runID(), "ibge", "municipality", *muns)
		},
		restore: func() (bool, error) {
			r, err := in.db.Places(ctx, "ibge", "municipality")
			if err != nil || len(r) < 5000 {
				return false, err
			}
			*muns = r
			return true, nil
		},
	}
}

func (in *Ingest) tseIO(ctx context.Context, rep *Report, t *tseResult) sourceIO {
	return sourceIO{
		id: "tse", name: "Tribunal Superior Eleitoral", url: "https://dadosabertos.tse.jus.br",
		load: func() error {
			r, err := in.loadTSE(ctx, rep)
			*t = r
			return err
		},
		save: func() (datastore.Counts, error) {
			byYear := map[int][]publicdata.Candidacy{}
			for _, c := range t.candidacies {
				c.CPF = datastore.Pseudonym(c.CPF)
				byYear[c.Year] = append(byYear[c.Year], c)
			}
			years := make([]int, 0, len(byYear))
			for y := range byYear {
				years = append(years, y)
			}
			sort.Ints(years)
			var snaps []datastore.Snapshot
			for _, y := range years {
				snaps = append(snaps, datastore.Snapshot{Key: strconv.Itoa(y), Value: byYear[y]})
			}
			c, err := in.db.PutSnapshots(ctx, in.runID(), "tse", "candidacies:", snaps, true)
			if err != nil {
				return c, err
			}
			cc, err := in.db.PutSnapshot(ctx, in.runID(), "tse", "campaigns", t.campaigns)
			return c.Add(cc), err
		},
		restore: func() (bool, error) {
			var cands []publicdata.Candidacy
			err := in.db.Snapshots(ctx, "tse", "candidacies:", func(_ string, payload []byte) error {
				var part []publicdata.Candidacy
				if err := json.Unmarshal(payload, &part); err != nil {
					return err
				}
				cands = append(cands, part...)
				return nil
			})
			if err != nil || len(cands) == 0 {
				return false, err
			}
			var camp *publicdata.CampaignTotals
			if _, err := in.db.Snapshot(ctx, "tse", "campaigns", &camp); err != nil {
				return false, err
			}
			*t = tseResult{candidacies: cands, campaigns: camp}
			return true, nil
		},
	}
}

func (in *Ingest) receitaIO(ctx context.Context, rev **publicdata.RevenueBlock) sourceIO {
	return sourceIO{
		id: "receita", name: "Receita Federal", url: "https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/dados-abertos",
		load: func() error {
			r, err := in.loadReceita(ctx)
			*rev = r
			return err
		},
		save: func() (datastore.Counts, error) {
			if *rev == nil {
				return datastore.Counts{}, nil
			}
			c, err := in.db.PutSnapshot(ctx, in.runID(), "receita", "revenue", *rev)
			if err != nil {
				return c, err
			}
			y := strconv.Itoa((*rev).Year)
			points := []datastore.Point{{Series: "revenue.total", Scope: "br", Date: y, Value: float64((*rev).TotalCents)}}
			for _, s := range (*rev).ByState {
				points = append(points, datastore.Point{Series: "revenue.total", Scope: s.UF, Date: y, Value: float64(s.Cents)})
			}
			sr, err := in.db.PutSeries(ctx, in.runID(), "receita", points)
			return c.Add(sr), err
		},
		restore: func() (bool, error) {
			var r *publicdata.RevenueBlock
			ok, err := in.db.Snapshot(ctx, "receita", "revenue", &r)
			if !ok || r == nil {
				return false, err
			}
			*rev = r
			return true, nil
		},
	}
}

func (in *Ingest) storeCities(ctx context.Context, rep *Report, srcs *sourceSet, cities []publicdata.City) []publicdata.City {
	t := in.track(ctx, "cidades")
	if in.db == nil {
		return cities
	}
	if cities != nil {
		c, err := in.db.PutCities(ctx, in.runID(), publicdata.CitySource, cities)
		if err != nil {
			in.warn(rep, "store cidades: %v", err)
		}
		t.done(ctx, datastore.StatusOK, c.Map(), err)
		return cities
	}
	stored, err := in.db.Cities(ctx, publicdata.CitySource)
	if err != nil || len(stored) == 0 {
		t.done(ctx, datastore.StatusFailed, nil, err)
		return cities
	}
	in.warn(rep, "cities: published the last stored read (%d municipalities)", len(stored))
	srcs.keep(publicdata.CitySource, "Tribunal Superior Eleitoral", tse.SiteURL)
	rep.Cities = len(stored)
	for _, c := range stored {
		rep.CityPeople += len(c.Officials)
	}
	t.done(ctx, datastore.StatusFallback, nil, nil)
	return stored
}

func (in *Ingest) storeChecks(ctx context.Context, rep *Report, srcs *sourceSet, checks []publicdata.RawCheck) []publicdata.RawCheck {
	t := in.track(ctx, "comprova")
	if in.db == nil {
		return checks
	}
	if checks != nil {
		snaps := make([]datastore.Snapshot, 0, len(checks))
		months := map[string]int{}
		for _, c := range checks {
			snaps = append(snaps, datastore.Snapshot{Key: c.ID, Value: c})
			if len(c.Date) >= 7 {
				months[c.Date[:7]]++
			}
		}
		c, err := in.db.PutSnapshots(ctx, in.runID(), "comprova", "check:", snaps, true)
		if err == nil {
			var points []datastore.Point
			for m, n := range months {
				points = append(points, datastore.Point{Series: "checks.published", Scope: "br", Date: m, Value: float64(n)})
			}
			var sr datastore.Counts
			sr, err = in.db.PutSeries(ctx, in.runID(), "comprova", points)
			c = c.Add(sr)
		}
		if err != nil {
			in.warn(rep, "store comprova: %v", err)
		}
		t.done(ctx, datastore.StatusOK, c.Map(), err)
		return checks
	}
	var stored []publicdata.RawCheck
	err := in.db.Snapshots(ctx, "comprova", "check:", func(_ string, payload []byte) error {
		var c publicdata.RawCheck
		if err := json.Unmarshal(payload, &c); err != nil {
			return err
		}
		stored = append(stored, c)
		return nil
	})
	if err != nil || len(stored) == 0 {
		t.done(ctx, datastore.StatusFailed, nil, err)
		return checks
	}
	in.warn(rep, "comprova: published the last stored read (%d checks)", len(stored))
	srcs.keep("comprova", comprova.Name, comprova.SiteURL)
	t.done(ctx, datastore.StatusFallback, nil, nil)
	return stored
}

func (in *Ingest) storeAssemblies(ctx context.Context, srcs *sourceSet, people []*publicdata.Person) []string {
	var ids []string
	srcs.mu.Lock()
	for id := range srcs.list {
		if strings.HasPrefix(id, "assembleia-") {
			ids = append(ids, id)
		}
	}
	srcs.mu.Unlock()
	sort.Strings(ids)
	members := 0
	for _, p := range people {
		if p.Assembly != "" {
			members++
		}
	}
	status := datastore.StatusOK
	if len(ids) == 0 {
		status = datastore.StatusFailed
	}
	in.track(ctx, "assembleias").done(ctx, status, map[string]int{"houses": len(ids), "members": members}, nil)
	return ids
}

func (in *Ingest) storeFinal(ctx context.Context, rep *Report, people []*publicdata.Person, slugs map[*publicdata.Person]string, assemblies []string) {
	if in.db == nil {
		return
	}
	t := in.track(ctx, datastore.SourceFiscal)
	c, err := in.db.PutFinalPeople(ctx, in.runID(), people, slugs, assemblies)
	if err != nil {
		in.warn(rep, "store fiscal: %v", err)
		t.done(ctx, datastore.StatusFailed, nil, err)
		return
	}
	t.done(ctx, datastore.StatusOK, c.Map(), nil)
}

func (in *Ingest) storeLive(ctx context.Context, rep *Report, ds *publicdata.Dataset) {
	if in.db == nil {
		return
	}
	today := ds.Today
	for _, house := range []string{publicdata.HouseCamara, publicdata.HouseSenado} {
		var votes []*publicdata.HouseVote
		for _, v := range ds.Votes {
			if v != nil && v.House == house && v.Date == today {
				votes = append(votes, v)
			}
		}
		if len(votes) > 0 {
			if _, err := in.db.PutVotes(ctx, in.runID(), house, votes, false); err != nil {
				in.warn(rep, "store %s votes today: %v", house, err)
			}
		}
	}
	for _, h := range ds.Agenda {
		if _, err := in.db.PutSnapshot(ctx, in.runID(), h.House, "agenda:"+today, h); err != nil {
			in.warn(rep, "store %s agenda: %v", h.House, err)
		}
	}
}

func (in *Ingest) storedAgenda(ctx context.Context, today string) []publicdata.RawAgendaHouse {
	if in.db == nil {
		return nil
	}
	var out []publicdata.RawAgendaHouse
	for _, house := range []string{publicdata.HouseCamara, publicdata.HouseSenado} {
		var h publicdata.RawAgendaHouse
		if ok, err := in.db.Snapshot(ctx, house, "agenda:"+today, &h); err == nil && ok && h.House != "" {
			out = append(out, h)
		}
	}
	return out
}
