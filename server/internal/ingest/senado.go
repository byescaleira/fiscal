package ingest

import (
	"context"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"sync"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/senado"
)

type senadoResult struct {
	people          []*publicdata.Person
	votes           []*publicdata.HouseVote
	quotaTotal      *int64
	quotaByCategory map[string]int64
}

func (in *Ingest) senadoAPI() senado.API {
	return senado.API{Get: in.get}
}

func (in *Ingest) loadSenado(ctx context.Context, rep *Report) (senadoResult, error) {
	var res senadoResult
	api := in.senadoAPI()
	list, err := api.Current(ctx)
	if err != nil {
		return res, err
	}
	if len(list) < 70 && len(in.cfg.UFs) == 0 {
		return res, fmt.Errorf("only %d senators listed; refusing to publish a partial house", len(list))
	}
	var sens []senado.Senator
	for _, s := range list {
		if in.cfg.wantUF(s.UF) {
			sens = append(sens, s)
		}
	}
	people := make([]*publicdata.Person, len(sens))
	codes := map[int64]*publicdata.Person{}
	var mu sync.Mutex
	years := in.cfg.Years
	forEachJob(in.cfg.Workers, len(sens), func(i int) {
		s := sens[i]
		p := senatorPerson(s)
		if d, err := api.Detail(ctx, s.Code); err == nil {
			p.BirthDate = d.BirthDate
			if d.BirthPlace != "" {
				p.BirthPlace = d.BirthPlace
				if d.BirthUF != "" {
					p.BirthPlace += ", " + d.BirthUF
				}
			}
			if d.Address != "" && p.Contact != nil {
				p.Contact.Office = nilIfEmpty(d.Address)
			}
		} else {
			in.warn(rep, "senado %d detail: %v", s.Code, err)
		}
		if ms, err := api.Mandates(ctx, s.Code); err == nil {
			for _, m := range ms {
				if m.Start != "" && m.Start <= in.today() && (m.End == "" || m.End >= in.today()) {
					p.Roles[0].MandateStart, p.Roles[0].MandateEnd = m.Start, m.End
				}
			}
		} else {
			in.warn(rep, "senado %d mandates: %v", s.Code, err)
		}
		if cs, err := api.Committees(ctx, s.Code); err == nil {
			for _, c := range cs {
				p.Committees = append(p.Committees, publicdata.Committee{Name: c.Name, Role: c.Role, Start: dateOnly(c.Start), End: dateOnly(c.End)})
			}
		} else {
			in.warn(rep, "senado %d committees: %v", s.Code, err)
		}
		cov := map[string]publicdata.Coverage{}
		procs, perr := api.Authored(ctx, s.Code)
		if perr != nil {
			in.warn(rep, "senado %d processes: %v", s.Code, perr)
			cov["proposals"] = publicdata.Coverage{Kind: "proposals", Status: publicdata.CoverageNotLoaded, Source: "senado"}
		}
		for _, y := range years {
			act := &publicdata.YearActivity{Year: y}
			p.Activity[y] = act
			for _, pr := range procs {
				if year(pr.Presented) == y {
					act.Proposals = append(act.Proposals, publicdata.RawProposal{ID: "senado-" + strconv.FormatInt(pr.ID, 10), Kind: pr.Kind, Number: pr.Number, Year: pr.Year, Ementa: pr.Ementa, URL: pr.URL, Date: dateOnlyStr(pr.Presented)})
				}
			}
			sp, err := api.Speeches(ctx, s.Code, y)
			if err != nil {
				in.warn(rep, "senado %d speeches %d: %v", s.Code, y, err)
				cov["speeches"] = publicdata.Coverage{Kind: "speeches", Status: publicdata.CoverageNotLoaded, Source: "senado"}
				continue
			}
			for _, x := range sp {
				act.Speeches = append(act.Speeches, publicdata.RawSpeech{Date: x.Date, Kind: x.Kind, Summary: x.Summary, Keywords: x.Keywords, URL: x.URL})
			}
		}
		if len(cov) > 0 {
			p.Coverage = cov
		}
		mu.Lock()
		people[i] = p
		codes[s.Code] = p
		mu.Unlock()
	})
	res.quotaByCategory = map[string]int64{}
	for _, y := range years {
		from, to := yearRange(y, in.today())
		vs, err := api.Votes(ctx, from, to)
		if err != nil {
			return res, fmt.Errorf("votes %d: %w", y, err)
		}
		for _, v := range vs {
			res.votes = append(res.votes, senadoHouseVote(v))
		}
		ex, err := api.Expenses(ctx, y)
		if err != nil {
			return res, fmt.Errorf("ceaps %d: %w", y, err)
		}
		var total int64
		for _, e := range ex {
			total += e.Cents
			if y == in.currentYear() {
				res.quotaByCategory[categoryName(e.Category)] += e.Cents
			}
			p, ok := codes[e.SenatorCode]
			if !ok {
				continue
			}
			act := p.Activity[y]
			act.Expenses = append(act.Expenses, publicdata.Expense{ID: "senado-" + strconv.FormatInt(e.ID, 10), Year: e.Year, Month: e.Month, Category: categoryName(e.Category), Supplier: strings.TrimSpace(e.Supplier), Document: cnpj(e.SupplierID), Cents: e.Cents})
		}
		if y == in.currentYear() {
			res.quotaTotal = &total
		}
	}
	sort.SliceStable(people, func(i, j int) bool { return people[i].HouseID < people[j].HouseID })
	res.people = people
	return res, nil
}

func senatorPerson(s senado.Senator) *publicdata.Person {
	p := &publicdata.Person{
		Keys:      []string{"senado:" + strconv.FormatInt(s.Code, 10)},
		Name:      strings.TrimSpace(s.Name),
		CivilName: strings.TrimSpace(s.FullName),
		Roles:     []publicdata.Role{{Office: publicdata.OfficeSenator, UF: strings.ToLower(s.UF), Status: publicdata.StatusInOffice, Party: s.Party, MandateStart: s.MandateStart, MandateEnd: s.MandateEnd}},
		Photo:     s.Photo,
		House:     publicdata.HouseSenado,
		HouseID:   s.Code,
		SourceIDs: []string{"senado"},
		Activity:  map[int]*publicdata.YearActivity{},
	}
	if s.Email != "" || s.Phone != "" {
		p.Contact = &publicdata.Contact{Email: nilIfEmpty(s.Email), Phone: nilIfEmpty(s.Phone)}
	}
	return p
}

func senadoHouseVote(v senado.Vote) *publicdata.HouseVote {
	hv := &publicdata.HouseVote{
		ID:          "senado-" + strconv.FormatInt(v.Code, 10),
		House:       publicdata.HouseSenado,
		Date:        v.Date,
		Proposition: v.Identification,
		Kind:        v.Kind,
		Description: v.Description,
		Ementa:      v.Ementa,
	}
	switch v.Result {
	case "A":
		b := true
		hv.Approved = &b
		hv.Result = "Aprovada"
	case "R":
		b := false
		hv.Approved = &b
		hv.Result = "Rejeitada"
	}
	yes, no, others := 0, 0, 0
	for _, b := range v.Ballots {
		present := senado.Present(b.Vote)
		switch b.Vote {
		case "Sim":
			yes++
		case "Não":
			no++
		default:
			if present {
				others++
			}
		}
		hv.Ballots = append(hv.Ballots, publicdata.Ballot{PersonKey: "senado:" + strconv.FormatInt(b.Code, 10), Name: b.Name, Party: b.Party, UF: b.UF, Vote: senado.VoteLabel(b.Vote), Present: present})
	}
	hv.Nominal = len(v.Ballots) > 0
	if v.Secret {
		hv.Yes, hv.No = v.Yes, v.No
		if v.Abstention != nil {
			hv.Others = v.Abstention
		}
		return hv
	}
	if hv.Nominal {
		hv.Yes, hv.No, hv.Others = &yes, &no, &others
	}
	return hv
}

func year(date string) int {
	if len(date) < 4 {
		return 0
	}
	n, err := strconv.Atoi(date[:4])
	if err != nil {
		return 0
	}
	return n
}
