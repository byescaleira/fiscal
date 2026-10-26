package publicdata

import "sort"

const FactThemes = 3

type FactGuidance struct {
	Followed int     `json:"followed"`
	Against  int     `json:"against"`
	Other    int     `json:"other"`
	First    *string `json:"first"`
	Last     *string `json:"last"`
}

type PersonFacts struct {
	Slug     string        `json:"slug"`
	House    *string       `json:"house"`
	Guidance *FactGuidance `json:"guidance"`
	Checks   int           `json:"checks"`
	Themes   []string      `json:"themes"`
}

type FactFile struct {
	GeneratedAt string        `json:"generatedAt"`
	Items       []PersonFacts `json:"items"`
	Sources     []Source      `json:"sources"`
}

func topThemes(counts []ThemeCount) []string {
	sorted := append([]ThemeCount(nil), counts...)
	sort.SliceStable(sorted, func(i, j int) bool {
		a := sorted[i].Proposals + sorted[i].Speeches
		c := sorted[j].Proposals + sorted[j].Speeches
		if a != c {
			return a > c
		}
		return sorted[i].Key < sorted[j].Key
	})
	out := []string{}
	for _, t := range sorted {
		if len(out) == FactThemes || t.Proposals+t.Speeches == 0 {
			break
		}
		out = append(out, t.Key)
	}
	return out
}

func (b *builder) guidanceTally(p *Person) *FactGuidance {
	g := FactGuidance{}
	first, last := "", ""
	for _, pb := range b.ballotsOf(p) {
		guide := guidanceFor(pb.vote, pb.ballot.Party)
		if guide == nil {
			continue
		}
		want := Fold(*guide)
		if want != "sim" && want != "nao" {
			continue
		}
		switch got := Fold(pb.ballot.Vote); {
		case got == want:
			g.Followed++
		case got == "sim" || got == "nao":
			g.Against++
		default:
			g.Other++
		}
		if first == "" || pb.vote.Date < first {
			first = pb.vote.Date
		}
		if pb.vote.Date > last {
			last = pb.vote.Date
		}
	}
	if g.Followed+g.Against+g.Other == 0 {
		return nil
	}
	g.First, g.Last = strPtr(first), strPtr(last)
	return &g
}

func (b *builder) facts(people []*Person) {
	items := make([]PersonFacts, 0, len(people))
	for _, p := range people {
		house := p.House
		if house == "" && p.Assembly != "" {
			house = HouseAssembly
		}
		themes := b.themes[p]
		if themes == nil {
			themes = []string{}
		}
		items = append(items, PersonFacts{
			Slug:     b.slugs[p],
			House:    strPtr(house),
			Guidance: b.guidanceTally(p),
			Checks:   b.checkCounts[p],
			Themes:   themes,
		})
	}
	b.add("index/facts.json", FactFile{
		GeneratedAt: stamp(b.ds.GeneratedAt),
		Items:       items,
		Sources:     b.sources("camara", "senado", "comprova"),
	})
}
