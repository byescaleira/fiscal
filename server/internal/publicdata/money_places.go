package publicdata

import (
	"sort"
	"strings"
)

const MoneyPlaceCountry = "br"

type MoneySpender struct {
	Person           PersonCard `json:"person"`
	House            string     `json:"house"`
	MonthlyCents     int64      `json:"monthlyCents"`
	MedianCents      int64      `json:"medianCents"`
	P75Cents         int64      `json:"p75Cents"`
	Band             string     `json:"band"`
	TopCategory      *string    `json:"topCategory"`
	TopCategoryCents *int64     `json:"topCategoryCents"`
}

type MoneyPlaceQuota struct {
	TotalCents int64           `json:"totalCents"`
	People     int             `json:"people"`
	Classified int             `json:"classified"`
	ByCategory []CategoryCents `json:"byCategory"`
	Spenders   []MoneySpender  `json:"spenders"`
}

type MoneyPlaceCampaigns struct {
	Years        []int `json:"years"`
	RevenueCents int64 `json:"revenueCents"`
	People       int   `json:"people"`
}

type MoneyPlace struct {
	UF                  string               `json:"uf"`
	Deputies            int                  `json:"deputies"`
	Senators            int                  `json:"senators"`
	CeilingMonthlyCents *int64               `json:"ceilingMonthlyCents"`
	Quota               MoneyPlaceQuota      `json:"quota"`
	Campaigns           *MoneyPlaceCampaigns `json:"campaigns"`
}

type MoneyPlacesFile struct {
	GeneratedAt string       `json:"generatedAt"`
	Year        int          `json:"year"`
	Places      []MoneyPlace `json:"places"`
	Sources     []Source     `json:"sources"`
}

type moneyMember struct {
	person *Person
	role   Role
	uf     string
}

func (b *builder) moneyPlaces(people []*Person) {
	members := []moneyMember{}
	for _, p := range people {
		r := p.Primary()
		if r.Status != StatusInOffice || (r.Office != OfficeFederalDeputy && r.Office != OfficeSenator) {
			continue
		}
		members = append(members, moneyMember{person: p, role: r, uf: strings.ToLower(r.UF)})
	}
	if len(members) == 0 {
		return
	}
	y := b.moneyYear(members)
	byUF := map[string][]moneyMember{}
	ufs := []string{}
	for _, m := range members {
		if _, ok := byUF[m.uf]; !ok {
			ufs = append(ufs, m.uf)
		}
		byUF[m.uf] = append(byUF[m.uf], m)
	}
	sort.Strings(ufs)
	places := []MoneyPlace{b.moneyPlace(MoneyPlaceCountry, members, y)}
	for _, uf := range ufs {
		places = append(places, b.moneyPlace(uf, byUF[uf], y))
	}
	ids := []string{HouseCamara, HouseSenado, "tse"}
	ids = append(ids, b.ds.MandateSources...)
	b.add("money/places.json", MoneyPlacesFile{GeneratedAt: stamp(b.ds.GeneratedAt), Year: y, Places: places, Sources: b.sources(ids...)})
}

func (b *builder) moneyYear(members []moneyMember) int {
	counts := map[int]int{}
	for _, m := range members {
		if c := b.classes[m.person]; c != nil && c.Quota != nil {
			counts[c.Year]++
		}
	}
	best, most := b.ds.Quota.Year, 0
	for y, n := range counts {
		if n > most || (n == most && y > best) {
			best, most = y, n
		}
	}
	return best
}

func (b *builder) moneyPlace(uf string, members []moneyMember, y int) MoneyPlace {
	out := MoneyPlace{UF: uf}
	var ceiling int64
	ceilingKnown := b.ds.Mandate != nil
	for _, m := range members {
		switch m.role.Office {
		case OfficeFederalDeputy:
			out.Deputies++
		case OfficeSenator:
			out.Senators++
		}
		total, ok := b.roleMonthly(m.role.Office, m.uf)
		if !ok {
			ceilingKnown = false
		}
		ceiling += total
	}
	if ceilingKnown && ceiling > 0 {
		out.CeilingMonthlyCents = ptr(ceiling)
	}
	out.Quota = b.placeQuota(members, y)
	out.Campaigns = placeCampaigns(members)
	return out
}

func (b *builder) roleMonthly(office, uf string) (int64, bool) {
	role := MandateFederalDeputy
	if office == OfficeSenator {
		role = MandateSenator
	}
	if b.ds.Mandate == nil {
		return 0, false
	}
	for _, r := range b.ds.Mandate.Roles {
		if r.Role != role {
			continue
		}
		var total int64
		for _, it := range r.Items {
			if c, ok := itemCents(it, uf); ok {
				total += c
			}
		}
		return total, total > 0
	}
	return 0, false
}

func itemCents(it MandateItem, uf string) (int64, bool) {
	if it.MonthlyCents != nil {
		return *it.MonthlyCents, true
	}
	for _, s := range it.ByState {
		if strings.EqualFold(s.UF, uf) {
			return s.MonthlyCents, true
		}
	}
	return 0, false
}

func (b *builder) placeQuota(members []moneyMember, y int) MoneyPlaceQuota {
	out := MoneyPlaceQuota{ByCategory: []CategoryCents{}, Spenders: []MoneySpender{}}
	cats := map[string]int64{}
	for _, m := range members {
		p := m.person
		if c, ok := p.Coverage["expenses"]; !ok || c.Status != CoverageAvailable {
			continue
		}
		act := p.Activity[y]
		if act == nil {
			continue
		}
		out.People++
		own := map[string]int64{}
		for _, e := range act.Expenses {
			out.TotalCents += e.Cents
			cats[e.Category] += e.Cents
			own[e.Category] += e.Cents
		}
		class := b.classes[p]
		if class == nil || class.Year != y || class.Quota == nil {
			continue
		}
		out.Classified++
		if class.Quota.Band != BandWorse {
			continue
		}
		s := MoneySpender{
			Person: b.card(p, m.role), House: class.House,
			MonthlyCents: int64(class.Quota.Value), MedianCents: int64(class.Quota.Median), P75Cents: int64(class.Quota.P75),
			Band: class.Quota.Band,
		}
		if name, cents := topCategory(own); name != "" {
			s.TopCategory, s.TopCategoryCents = ptr(name), ptr(cents)
		}
		out.Spenders = append(out.Spenders, s)
	}
	for c, v := range cats {
		out.ByCategory = append(out.ByCategory, CategoryCents{Category: c, Cents: v})
	}
	sort.SliceStable(out.ByCategory, func(i, j int) bool {
		if out.ByCategory[i].Cents != out.ByCategory[j].Cents {
			return out.ByCategory[i].Cents > out.ByCategory[j].Cents
		}
		return out.ByCategory[i].Category < out.ByCategory[j].Category
	})
	sort.SliceStable(out.Spenders, func(i, j int) bool {
		if out.Spenders[i].MonthlyCents != out.Spenders[j].MonthlyCents {
			return out.Spenders[i].MonthlyCents > out.Spenders[j].MonthlyCents
		}
		return out.Spenders[i].Person.Slug < out.Spenders[j].Person.Slug
	})
	return out
}

func topCategory(own map[string]int64) (string, int64) {
	name, best := "", int64(0)
	for c, v := range own {
		if v > best || (v == best && c < name) {
			name, best = c, v
		}
	}
	return name, best
}

func placeCampaigns(members []moneyMember) *MoneyPlaceCampaigns {
	out := MoneyPlaceCampaigns{Years: []int{}}
	years := map[int]bool{}
	for _, m := range members {
		var won *Candidacy
		for i := range m.person.Candidacies {
			c := &m.person.Candidacies[i]
			if !c.Elected || c.Office != m.role.Office || c.RevenueCents == nil {
				continue
			}
			if won == nil || c.Year > won.Year {
				won = c
			}
		}
		if won == nil {
			continue
		}
		out.People++
		out.RevenueCents += *won.RevenueCents
		years[won.Year] = true
	}
	if out.People == 0 {
		return nil
	}
	for y := range years {
		out.Years = append(out.Years, y)
	}
	sort.Ints(out.Years)
	return &out
}
