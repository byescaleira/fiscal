package ingest

import (
	"context"
	"errors"
	"os"
	"sort"
	"strconv"
	"strings"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/assembleias"
	"liveresults/internal/sources/ibge"
	"liveresults/internal/sources/receita"
)

func (in *Ingest) loadIBGE(ctx context.Context) ([]publicdata.PlaceEntry, error) {
	c, err := in.get.Cache(ctx, ibge.MunicipalitiesURL, 32<<20)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(c.Path)
	if err != nil {
		return nil, err
	}
	muns, err := ibge.ParseMunicipalities(data)
	if err != nil {
		return nil, err
	}
	if len(muns) < 5000 {
		return nil, errors.New("fewer than 5000 municipalities; refusing to publish a partial index")
	}
	out := make([]publicdata.PlaceEntry, 0, len(muns))
	for _, m := range muns {
		out = append(out, publicdata.PlaceEntry{Code: m.Code, Name: m.Name, UF: strings.ToLower(m.UF)})
	}
	return out, nil
}

func (in *Ingest) loadReceita(ctx context.Context) (*publicdata.RevenueBlock, error) {
	c, err := in.get.Cache(ctx, receita.RevenueURL, 64<<20)
	if err != nil {
		return nil, err
	}
	f, err := os.Open(c.Path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	rev, err := receita.Parse(f)
	if err != nil {
		return nil, err
	}
	y, ok := rev.LatestComplete()
	if !ok {
		return nil, errors.New("no complete year in the file")
	}
	block := &publicdata.RevenueBlock{Year: y.Year, TotalCents: y.TotalCents()}
	for uf, c := range y.ByUF {
		block.ByState = append(block.ByState, publicdata.StateCents{UF: strings.ToLower(uf), Cents: c})
	}
	sort.Slice(block.ByState, func(i, j int) bool { return block.ByState[i].UF < block.ByState[j].UF })
	return block, nil
}

func (in *Ingest) loadAssemblies(ctx context.Context, rep *Report, people []*publicdata.Person, cands []publicdata.Candidacy, prevYear int, states map[string]string, srcs *sourceSet) []*publicdata.Person {
	year := in.currentYear()
	for _, h := range assembleias.Houses {
		if !in.cfg.wantUF(h.UF) {
			continue
		}
		data, err := assembleias.Load(ctx, in.get, h, year, in.today())
		if err != nil {
			in.warn(rep, "assembleia %s: %v", h.UF, err)
			continue
		}
		source := data.Members
		if data.CurrentKnown {
			source = data.CurrentMembers()
		} else {
			in.warn(rep, "assembleia %s: current legislature not found, statuses kept from the TSE", h.UF)
		}
		var members []publicdata.AssemblyMember
		for _, m := range source {
			members = append(members, publicdata.AssemblyMember{ID: m.ID, Name: m.Name, FullName: m.FullName, Email: m.Email, Phone: m.Phone, Photo: m.Photo})
		}
		id := "assembleia-" + h.UF
		var matched map[int64]*publicdata.Person
		people, matched = publicdata.LinkAssembly(people, cands, h.UF, prevYear, members, data.CurrentKnown, id, states)
		if len(matched) == 0 {
			in.warn(rep, "assembleia %s: no member matched the TSE", h.UF)
			continue
		}
		srcs.add(id, h.Name, h.Base)
		matters := data.Matters
		loaded := map[int]bool{year: true}
		for _, y := range in.cfg.Years {
			if y == year {
				continue
			}
			more, err := assembleias.Load(ctx, in.get, h, y, in.today())
			if err != nil {
				in.warn(rep, "assembleia %s %d: %v", h.UF, y, err)
				continue
			}
			matters = append(matters, more.Matters...)
			loaded[y] = true
		}
		for _, p := range matched {
			if p.Activity == nil {
				p.Activity = map[int]*publicdata.YearActivity{}
			}
			for y := range loaded {
				if p.Activity[y] == nil {
					p.Activity[y] = &publicdata.YearActivity{Year: y}
				}
			}
		}
		for _, mt := range matters {
			y := mt.Year
			if year > 0 && y == 0 {
				y = year
			}
			rp := publicdata.RawProposal{ID: id + "-" + strconv.FormatInt(mt.ID, 10), Kind: mt.Kind, Number: mt.Number, Year: mt.Year, Ementa: mt.Ementa, URL: mt.URL}
			for _, a := range mt.AuthorIDs {
				if p, ok := matched[a]; ok && p.Activity[y] != nil {
					p.Activity[y].Proposals = append(p.Activity[y].Proposals, rp)
				}
			}
		}
	}
	return people
}
