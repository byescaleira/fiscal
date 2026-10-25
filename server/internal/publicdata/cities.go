package publicdata

import (
	"fmt"
	"sort"
	"strings"
)

const (
	OfficeMayor         = "mayor"
	OfficeViceMayor     = "viceMayor"
	OfficeCityCouncilor = "cityCouncilor"
	LevelCity           = "city"
	CitySource          = "tse-cidades"
	cityGroupHall       = "Prefeitura"
	cityGroupCouncil    = "Câmara Municipal"
)

type CityFile struct {
	Code    string                `json:"code"`
	Name    string                `json:"name"`
	UF      string                `json:"uf"`
	Groups  []RepresentativeGroup `json:"groups"`
	Note    *string               `json:"note"`
	Sources []Source              `json:"sources"`
}

type City struct {
	Code      string
	Name      string
	UF        string
	Unit      string
	Officials []*Person
}

func (c City) has(office string) bool {
	for _, p := range c.Officials {
		if p.Primary().Office == office {
			return true
		}
	}
	return false
}

func (c City) Note() string {
	if c.Unit == "" {
		if c.UF == "df" {
			return "Brasília não tem prefeito nem vereadores: o Distrito Federal é governado pelo governador, e as leis locais saem da Câmara Legislativa."
		}
		return c.Name + " não elege prefeito nem vereadores: é administrado pelo governo do estado."
	}
	var parts []string
	if !c.has(OfficeMayor) {
		parts = append(parts, "O TSE não registra prefeito eleito em "+c.Name+" nos dados abertos (eleição anulada, sub judice ou suplementar ainda sem resultado).")
	}
	if !c.has(OfficeCityCouncilor) {
		parts = append(parts, "O TSE ainda não publica os vereadores eleitos de "+c.Name+" nos dados abertos (resultado em nova totalização).")
	}
	return strings.Join(parts, " ")
}

func CityOffice(office string) bool {
	switch office {
	case OfficeMayor, OfficeViceMayor, OfficeCityCouncilor:
		return true
	}
	return false
}

type Unit struct {
	UF   string
	Code string
	Name string
}

type UnitReview struct {
	Kind     string `json:"kind"`
	UF       string `json:"uf"`
	TSE      string `json:"tse,omitempty"`
	TSEName  string `json:"tseName,omitempty"`
	IBGE     string `json:"ibge,omitempty"`
	IBGEName string `json:"ibgeName,omitempty"`
}

type UnitMatch struct {
	ByUnit  map[string]string
	Reviews []UnitReview
}

func UnitKey(uf, code string) string {
	return strings.ToLower(uf) + ":" + code
}

var unitRenames = map[string]string{
	"rn:17035": "2405306",
}

var particles = map[string]bool{"d": true, "da": true, "de": true, "do": true, "das": true, "dos": true, "e": true}

func withoutParticles(s string) string {
	var out []string
	for _, w := range strings.Fields(s) {
		if !particles[w] {
			out = append(out, w)
		}
	}
	return strings.Join(out, " ")
}

func spelling(s string) string {
	var out []string
	for _, w := range strings.Fields(withoutParticles(s)) {
		w = strings.NewReplacer("th", "t", "ph", "f", "y", "i", "z", "s", "w", "v", "k", "c").Replace(w)
		var b strings.Builder
		var last rune
		for _, r := range w {
			if r != last {
				b.WriteRune(r)
			}
			last = r
		}
		w = b.String()
		if n := len(w); n > 3 && (w[n-1] == 'n' || w[n-1] == 'm') && strings.ContainsRune("aeiou", rune(w[n-2])) {
			w = w[:n-1]
		}
		out = append(out, w)
	}
	return strings.Join(out, " ")
}

func MatchUnits(units []Unit, muns []PlaceEntry) UnitMatch {
	m := UnitMatch{ByUnit: map[string]string{}}
	byCode := map[string]PlaceEntry{}
	free := map[string]bool{}
	for _, p := range muns {
		byCode[p.Code] = p
		free[p.Code] = true
	}
	sorted := append([]Unit(nil), units...)
	sort.Slice(sorted, func(i, j int) bool {
		return UnitKey(sorted[i].UF, sorted[i].Code) < UnitKey(sorted[j].UF, sorted[j].Code)
	})
	pending := map[string]Unit{}
	for _, u := range sorted {
		pending[UnitKey(u.UF, u.Code)] = u
	}
	accept := func(kind string, u Unit, code string) {
		key := UnitKey(u.UF, u.Code)
		m.ByUnit[key] = code
		delete(pending, key)
		delete(free, code)
		if kind != "" {
			m.Reviews = append(m.Reviews, UnitReview{Kind: kind, UF: strings.ToLower(u.UF), TSE: u.Code, TSEName: u.Name, IBGE: code, IBGEName: byCode[code].Name})
		}
	}
	for key, code := range unitRenames {
		if u, ok := pending[key]; ok && free[code] {
			accept("renamed", u, code)
		}
	}
	stages := []struct {
		kind string
		norm func(string) string
		test func(tse, ibge string) bool
	}{
		{"", Fold, nil},
		{"particles", func(s string) string { return withoutParticles(Fold(s)) }, nil},
		{"spelling", func(s string) string { return spelling(Fold(s)) }, nil},
		{"prefix", func(s string) string { return withoutParticles(Fold(s)) }, func(tse, ibge string) bool { return strings.HasPrefix(ibge, tse+" ") }},
	}
	for _, st := range stages {
		index := map[string][]string{}
		for code := range free {
			p := byCode[code]
			index[p.UF] = append(index[p.UF], code)
		}
		norms := map[string]string{}
		for _, codes := range index {
			for _, code := range codes {
				norms[code] = st.norm(byCode[code].Name)
			}
		}
		cands := map[string][]string{}
		claims := map[string]int{}
		for _, u := range sorted {
			key := UnitKey(u.UF, u.Code)
			if _, ok := pending[key]; !ok {
				continue
			}
			tn := st.norm(u.Name)
			for _, code := range index[strings.ToLower(u.UF)] {
				in := norms[code]
				if (st.test == nil && in == tn) || (st.test != nil && st.test(tn, in)) {
					cands[key] = append(cands[key], code)
				}
			}
			if len(cands[key]) == 1 {
				claims[cands[key][0]]++
			}
		}
		for _, u := range sorted {
			key := UnitKey(u.UF, u.Code)
			if c := cands[key]; len(c) == 1 && claims[c[0]] == 1 {
				accept(st.kind, u, c[0])
			}
		}
	}
	for _, u := range sorted {
		if _, ok := pending[UnitKey(u.UF, u.Code)]; ok {
			m.Reviews = append(m.Reviews, UnitReview{Kind: "unmatchedUnit", UF: strings.ToLower(u.UF), TSE: u.Code, TSEName: u.Name})
		}
	}
	var left []string
	for code := range free {
		left = append(left, code)
	}
	sort.Strings(left)
	for _, code := range left {
		p := byCode[code]
		m.Reviews = append(m.Reviews, UnitReview{Kind: "noElection", UF: p.UF, IBGE: code, IBGEName: p.Name})
	}
	return m
}

func citySlugBase(p *Person, c City) string {
	return Slugify(fmt.Sprintf("%s %s %s", p.Name, c.Name, c.UF))
}

func cityRank(office string) int {
	switch office {
	case OfficeMayor:
		return 0
	case OfficeViceMayor:
		return 1
	}
	return 2
}

func (b *builder) cityFiles() {
	for _, c := range b.ds.Cities {
		var hall, council []PersonCard
		officials := append([]*Person(nil), c.Officials...)
		sort.SliceStable(officials, func(i, j int) bool {
			ri, rj := cityRank(officials[i].Primary().Office), cityRank(officials[j].Primary().Office)
			if ri != rj {
				return ri < rj
			}
			return lessPerson(officials[i], officials[j], b.slugs)
		})
		for _, p := range officials {
			r := p.Primary()
			card := b.card(p, r)
			if r.Office == OfficeCityCouncilor {
				council = append(council, card)
			} else {
				hall = append(hall, card)
			}
			b.person(p)
			b.cities = append(b.cities, "people/"+b.slugs[p]+".json")
		}
		groups := []RepresentativeGroup{}
		if len(hall) > 0 {
			groups = append(groups, RepresentativeGroup{Level: LevelCity, Office: OfficeMayor, Title: cityGroupHall, People: hall})
		}
		if len(council) > 0 {
			groups = append(groups, RepresentativeGroup{Level: LevelCity, Office: OfficeCityCouncilor, Title: cityGroupCouncil, People: council})
		}
		b.cities = append(b.cities, "places/city/"+c.Code+".json")
		b.add("places/city/"+c.Code+".json", CityFile{Code: c.Code, Name: c.Name, UF: c.UF, Groups: groups, Note: strPtr(c.Note()), Sources: b.sources(CitySource, "ibge")})
	}
}

func (b *builder) assignCities(registry *Slugs) {
	if len(b.ds.Cities) == 0 {
		return
	}
	taken := map[string]bool{}
	for _, slug := range b.slugs {
		taken[slug] = true
	}
	city := map[*Person]City{}
	var people []*Person
	for _, c := range b.ds.Cities {
		for _, p := range c.Officials {
			city[p] = c
			people = append(people, p)
		}
	}
	for p, slug := range registry.AssignScoped(people, func(p *Person) string { return citySlugBase(p, city[p]) }, taken) {
		b.slugs[p] = slug
	}
}
