package datastore

import (
	"context"
	"encoding/json"
	"sort"
	"strconv"
	"strings"

	"liveresults/internal/publicdata"
)

const SourceFiscal = "fiscal"

type item[T any] struct {
	Person string
	City   string `json:",omitempty"`
	Year   int    `json:",omitempty"`
	Item   T
}

func Pseudonym(cpf string) string {
	if cpf == "" {
		return ""
	}
	return publicdata.CPFKey(cpf)
}

func PersonKey(p *publicdata.Person) string {
	if len(p.Keys) > 0 {
		return p.Keys[0]
	}
	r := p.Primary()
	return "name:" + publicdata.Fold(p.Name) + "|" + r.Office + "|" + r.UF
}

func stripped(p *publicdata.Person) publicdata.Person {
	cp := *p
	cp.CPF = Pseudonym(p.CPF)
	if len(p.Candidacies) > 0 {
		cp.Candidacies = make([]publicdata.Candidacy, len(p.Candidacies))
		for i, c := range p.Candidacies {
			c.CPF = Pseudonym(c.CPF)
			cp.Candidacies[i] = c
		}
	}
	if p.Activity != nil {
		cp.Activity = make(map[int]*publicdata.YearActivity, len(p.Activity))
		for y, a := range p.Activity {
			if a == nil {
				continue
			}
			c := *a
			c.Proposals, c.Expenses = nil, nil
			cp.Activity[y] = &c
		}
	}
	return cp
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func (b *batch) person(table table, source string, p *publicdata.Person, slug string) error {
	r := p.Primary()
	sp := stripped(p)
	return b.put(table, source, PersonKey(p), []any{p.Name, nullable(r.Office), nullable(r.UF), nullable(r.Party), nullable(r.Status), nullable(p.House), nullable(slug)}, sp)
}

func (b *batch) activity(source string, p *publicdata.Person, expenses bool) error {
	key := PersonKey(p)
	years := make([]int, 0, len(p.Activity))
	for y := range p.Activity {
		years = append(years, y)
	}
	sort.Ints(years)
	for _, y := range years {
		a := p.Activity[y]
		if a == nil {
			continue
		}
		for _, pr := range a.Proposals {
			k := key + "|" + strconv.Itoa(y) + "|" + pr.ID
			if err := b.put(tablePropositions, source, k, []any{key, y, nullable(pr.Kind), pr.Number}, item[publicdata.RawProposal]{Person: key, Year: y, Item: pr}); err != nil {
				return err
			}
		}
		if !expenses {
			continue
		}
		for i, e := range a.Expenses {
			id := e.ID
			if id == "" {
				id = "#" + strconv.Itoa(i)
			}
			k := key + "|" + strconv.Itoa(y) + "|" + id
			if err := b.put(tableExpenses, source, k, []any{key, y, e.Month, nullable(e.Category), e.Cents}, item[publicdata.Expense]{Person: key, Year: y, Item: e}); err != nil {
				return err
			}
		}
	}
	return nil
}

func (s *Store) PutSourcePeople(ctx context.Context, run int64, source string, people []*publicdata.Person, full bool) (Counts, error) {
	return s.batch(ctx, run, func(b *batch) error {
		for _, p := range people {
			if err := b.person(tablePeople, source, p, ""); err != nil {
				return err
			}
			if err := b.activity(source, p, true); err != nil {
				return err
			}
		}
		if !full {
			return nil
		}
		for _, t := range []table{tablePeople, tablePropositions, tableExpenses} {
			if err := b.closeMissing(t, source, ""); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Store) PutFinalPeople(ctx context.Context, run int64, people []*publicdata.Person, slugs map[*publicdata.Person]string, assemblies []string) (Counts, error) {
	return s.batch(ctx, run, func(b *batch) error {
		for _, p := range people {
			if err := b.person(tablePeople, SourceFiscal, p, slugs[p]); err != nil {
				return err
			}
			key := PersonKey(p)
			for _, r := range p.Roles {
				k := key + "|" + r.Office + "|" + r.UF + "|" + r.MandateStart
				if err := b.put(tableMandates, SourceFiscal, k, []any{key, nullable(r.Office), nullable(r.UF), nullable(r.Status), nullable(r.Party), nullable(r.MandateStart), nullable(r.MandateEnd)}, item[publicdata.Role]{Person: key, Item: r}); err != nil {
					return err
				}
			}
			if p.Assembly != "" {
				if err := b.activity(p.Assembly, p, false); err != nil {
					return err
				}
			}
		}
		for _, t := range []table{tablePeople, tableMandates} {
			if err := b.closeMissing(t, SourceFiscal, ""); err != nil {
				return err
			}
		}
		for _, a := range assemblies {
			if err := b.closeMissing(tablePropositions, a, ""); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Store) SourcePeople(ctx context.Context, source string) ([]*publicdata.Person, error) {
	var people []*publicdata.Person
	byKey := map[string]*publicdata.Person{}
	err := s.current(ctx, tablePeople, source, "", func(key string, payload []byte) error {
		var p publicdata.Person
		if err := json.Unmarshal(payload, &p); err != nil {
			return err
		}
		people = append(people, &p)
		byKey[key] = &p
		return nil
	})
	if err != nil || len(people) == 0 {
		return nil, err
	}
	year := func(p *publicdata.Person, y int) *publicdata.YearActivity {
		if p.Activity == nil {
			p.Activity = map[int]*publicdata.YearActivity{}
		}
		a := p.Activity[y]
		if a == nil {
			a = &publicdata.YearActivity{Year: y}
			p.Activity[y] = a
		}
		return a
	}
	err = s.current(ctx, tablePropositions, source, "", func(_ string, payload []byte) error {
		var it item[publicdata.RawProposal]
		if err := json.Unmarshal(payload, &it); err != nil {
			return err
		}
		if p, ok := byKey[it.Person]; ok {
			a := year(p, it.Year)
			a.Proposals = append(a.Proposals, it.Item)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	err = s.current(ctx, tableExpenses, source, "", func(_ string, payload []byte) error {
		var it item[publicdata.Expense]
		if err := json.Unmarshal(payload, &it); err != nil {
			return err
		}
		if p, ok := byKey[it.Person]; ok {
			a := year(p, it.Year)
			a.Expenses = append(a.Expenses, it.Item)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.SliceStable(people, func(i, j int) bool { return people[i].HouseID < people[j].HouseID })
	return people, nil
}

func ballotKey(voteID string, i int, b publicdata.Ballot) string {
	if b.PersonKey != "" {
		return voteID + "|" + b.PersonKey
	}
	return voteID + "|#" + strconv.Itoa(i) + "|" + publicdata.Fold(b.Name)
}

func (s *Store) PutVotes(ctx context.Context, run int64, house string, votes []*publicdata.HouseVote, full bool) (Counts, error) {
	return s.batch(ctx, run, func(b *batch) error {
		for _, v := range votes {
			if v == nil || v.House != house {
				continue
			}
			bare := *v
			bare.Ballots = nil
			if err := b.put(tableVotes, house, v.ID, []any{house, nullable(v.Date), nullable(v.Proposition)}, bare); err != nil {
				return err
			}
			for i, bl := range v.Ballots {
				if err := b.put(tableBallots, house, ballotKey(v.ID, i, bl), []any{v.ID, nullable(bl.PersonKey), nullable(bl.Vote), nullable(bl.Party), nullable(bl.UF)}, bl); err != nil {
					return err
				}
			}
		}
		if !full {
			return nil
		}
		for _, t := range []table{tableVotes, tableBallots} {
			if err := b.closeMissing(t, house, ""); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Store) Votes(ctx context.Context, house string) ([]*publicdata.HouseVote, error) {
	var votes []*publicdata.HouseVote
	byID := map[string]*publicdata.HouseVote{}
	err := s.current(ctx, tableVotes, house, "", func(key string, payload []byte) error {
		var v publicdata.HouseVote
		if err := json.Unmarshal(payload, &v); err != nil {
			return err
		}
		votes = append(votes, &v)
		byID[key] = &v
		return nil
	})
	if err != nil || len(votes) == 0 {
		return nil, err
	}
	err = s.current(ctx, tableBallots, house, "", func(key string, payload []byte) error {
		id, _, _ := strings.Cut(key, "|")
		v, ok := byID[id]
		if !ok {
			return nil
		}
		var bl publicdata.Ballot
		if err := json.Unmarshal(payload, &bl); err != nil {
			return err
		}
		v.Ballots = append(v.Ballots, bl)
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.SliceStable(votes, func(i, j int) bool {
		if votes[i].Date != votes[j].Date {
			return votes[i].Date < votes[j].Date
		}
		return votes[i].ID < votes[j].ID
	})
	return votes, nil
}

func (s *Store) PutPlaces(ctx context.Context, run int64, source, kind string, places []publicdata.PlaceEntry) (Counts, error) {
	return s.batch(ctx, run, func(b *batch) error {
		for _, p := range places {
			if err := b.put(tablePlaces, source, kind+":"+p.Code, []any{kind, p.Code, p.Name, nullable(p.UF)}, p); err != nil {
				return err
			}
		}
		return b.closeMissing(tablePlaces, source, kind+":")
	})
}

func (s *Store) Places(ctx context.Context, source, kind string) ([]publicdata.PlaceEntry, error) {
	var out []publicdata.PlaceEntry
	err := s.current(ctx, tablePlaces, source, kind+":", func(_ string, payload []byte) error {
		var p publicdata.PlaceEntry
		if err := json.Unmarshal(payload, &p); err != nil {
			return err
		}
		out = append(out, p)
		return nil
	})
	sort.SliceStable(out, func(i, j int) bool { return out[i].Code < out[j].Code })
	return out, err
}

type Snapshot struct {
	Key   string
	Value any
}

func (s *Store) PutSnapshots(ctx context.Context, run int64, source, prefix string, items []Snapshot, full bool) (Counts, error) {
	return s.batch(ctx, run, func(b *batch) error {
		w, err := b.w(tableSnapshots, source)
		if err != nil {
			return err
		}
		for _, it := range items {
			if err := w.put(prefix+it.Key, []any{w.at}, it.Value); err != nil {
				return err
			}
		}
		if full {
			return w.closeMissing(prefix)
		}
		return nil
	})
}

func (s *Store) PutSnapshot(ctx context.Context, run int64, source, key string, v any) (Counts, error) {
	return s.PutSnapshots(ctx, run, source, "", []Snapshot{{Key: key, Value: v}}, false)
}

func (s *Store) Snapshot(ctx context.Context, source, key string, v any) (bool, error) {
	var found []byte
	err := s.current(ctx, tableSnapshots, source, key, func(k string, payload []byte) error {
		if k == key {
			found = payload
		}
		return nil
	})
	if err != nil || found == nil {
		return false, err
	}
	return true, json.Unmarshal(found, v)
}

func (s *Store) Snapshots(ctx context.Context, source, prefix string, fn func(key string, payload []byte) error) error {
	return s.current(ctx, tableSnapshots, source, prefix, func(k string, payload []byte) error {
		return fn(strings.TrimPrefix(k, prefix), payload)
	})
}

type Point struct {
	Series string
	Scope  string
	Date   string
	Value  float64
}

func (s *Store) PutSeries(ctx context.Context, run int64, source string, points []Point) (Counts, error) {
	return s.batch(ctx, run, func(b *batch) error {
		for _, p := range points {
			key := p.Series + "|" + p.Scope + "|" + p.Date
			if err := b.put(tableSeries, source, key, []any{p.Series, p.Scope, p.Date, p.Value}, p); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Store) Series(ctx context.Context, series, scope string) ([]Point, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT date, value FROM series WHERE series_id = ? AND scope = ? AND valid_to IS NULL ORDER BY date`, series, scope)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Point
	for rows.Next() {
		p := Point{Series: series, Scope: scope}
		if err := rows.Scan(&p.Date, &p.Value); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

type cityMeta struct {
	Code string
	Name string
	UF   string
	Unit string
}

func (s *Store) PutCities(ctx context.Context, run int64, source string, cities []publicdata.City) (Counts, error) {
	return s.batch(ctx, run, func(b *batch) error {
		meta, err := b.w(tableSnapshots, source)
		if err != nil {
			return err
		}
		for _, c := range cities {
			if err := meta.put("city:"+c.Code, []any{meta.at}, cityMeta{Code: c.Code, Name: c.Name, UF: c.UF, Unit: c.Unit}); err != nil {
				return err
			}
			for _, p := range c.Officials {
				key := PersonKey(p)
				r := p.Primary()
				if err := b.put(tableCityOfficials, source, c.Code+"|"+key, []any{c.Code, key, nullable(r.Office), nullable(r.Party), nil}, item[publicdata.Person]{Person: key, City: c.Code, Item: stripped(p)}); err != nil {
					return err
				}
			}
		}
		if err := meta.closeMissing("city:"); err != nil {
			return err
		}
		return b.closeMissing(tableCityOfficials, source, "")
	})
}

func (s *Store) Cities(ctx context.Context, source string) ([]publicdata.City, error) {
	var out []publicdata.City
	idx := map[string]int{}
	err := s.Snapshots(ctx, source, "city:", func(_ string, payload []byte) error {
		var m cityMeta
		if err := json.Unmarshal(payload, &m); err != nil {
			return err
		}
		idx[m.Code] = len(out)
		out = append(out, publicdata.City{Code: m.Code, Name: m.Name, UF: m.UF, Unit: m.Unit})
		return nil
	})
	if err != nil || len(out) == 0 {
		return nil, err
	}
	err = s.current(ctx, tableCityOfficials, source, "", func(_ string, payload []byte) error {
		var it item[publicdata.Person]
		if err := json.Unmarshal(payload, &it); err != nil {
			return err
		}
		if i, ok := idx[it.City]; ok {
			p := it.Item
			out[i].Officials = append(out[i].Officials, &p)
		}
		return nil
	})
	sort.SliceStable(out, func(i, j int) bool { return out[i].Code < out[j].Code })
	return out, err
}

func (s *Store) Checkpoint(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `PRAGMA wal_checkpoint(TRUNCATE)`)
	return err
}
