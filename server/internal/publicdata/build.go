package publicdata

import (
	"fmt"
	"sort"
	"strings"
	"time"
)

type File struct {
	Path  string
	Value any
}

type Output struct {
	Files []File
	Slugs map[*Person]string
}

const RecentVotes = 60

var lawKinds = map[string]bool{"PL": true, "PLP": true, "PEC": true, "PDL": true, "PLS": true, "PLC": true, "PLN": true, "PLV": true, "MPV": true, "PDS": true}

func CanBecomeLaw(kind string) bool {
	return lawKinds[strings.ToUpper(strings.TrimSpace(kind))]
}

type builder struct {
	ds      *Dataset
	slugs   map[*Person]string
	byKey   map[string]*Person
	votesBy map[string][]personBallot
	files   []File
}

type personBallot struct {
	vote   *HouseVote
	ballot Ballot
}

func Build(ds *Dataset, registry *Slugs) Output {
	b := &builder{ds: ds, byKey: map[string]*Person{}, votesBy: map[string][]personBallot{}}
	b.slugs = registry.Assign(ds.People)
	for _, p := range ds.People {
		for _, k := range p.Keys {
			b.byKey[k] = p
		}
	}
	for _, v := range ds.Votes {
		for _, bl := range v.Ballots {
			if bl.PersonKey == "" {
				continue
			}
			b.votesBy[bl.PersonKey] = append(b.votesBy[bl.PersonKey], personBallot{vote: v, ballot: bl})
		}
	}
	people := append([]*Person(nil), ds.People...)
	sort.SliceStable(people, func(i, j int) bool { return lessPerson(people[i], people[j], b.slugs) })
	cards := make([]PersonCard, 0, len(people))
	counts := Counts{}
	for _, p := range people {
		card := b.card(p, p.Primary())
		cards = append(cards, card)
		if Federal(card.Office) {
			counts.Federal++
		} else {
			counts.State++
		}
		b.person(p)
	}
	counts.People = len(cards)
	b.add("index/people.json", cards)
	places := b.places()
	counts.Places = len(places)
	b.add("index/places.json", places)
	b.placeFiles(people)
	b.votes()
	b.agenda()
	b.money()
	b.today()
	b.add("meta.json", Meta{GeneratedAt: stamp(ds.GeneratedAt), Sources: b.sources(sortedSourceIDs(ds.Sources)...), Counts: counts})
	return Output{Files: b.files, Slugs: b.slugs}
}

func (b *builder) add(path string, v any) {
	b.files = append(b.files, File{Path: path, Value: v})
}

func stamp(t time.Time) string {
	loc, err := time.LoadLocation("America/Sao_Paulo")
	if err != nil {
		loc = time.FixedZone("BRT", -3*3600)
	}
	return t.In(loc).Format(time.RFC3339)
}

func sortedSourceIDs(m map[string]Source) []string {
	ids := make([]string, 0, len(m))
	for id := range m {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

func (b *builder) sources(ids ...string) []Source {
	out := []Source{}
	seen := map[string]bool{}
	for _, id := range ids {
		if seen[id] {
			continue
		}
		seen[id] = true
		if s, ok := b.ds.Sources[id]; ok {
			out = append(out, s)
		}
	}
	return out
}

func lessPerson(a, c *Person, slugs map[*Person]string) bool {
	fa, fc := Fold(a.Name), Fold(c.Name)
	if fa != fc {
		return fa < fc
	}
	return slugs[a] < slugs[c]
}

func (b *builder) card(p *Person, r Role) PersonCard {
	return PersonCard{Slug: b.slugs[p], Name: p.Name, Office: r.Office, UF: r.UF, Party: r.Party, Photo: strPtr(p.Photo), Status: r.Status}
}

func (b *builder) ballotsOf(p *Person) []personBallot {
	var out []personBallot
	seen := map[string]bool{}
	for _, k := range p.Keys {
		for _, pb := range b.votesBy[k] {
			if seen[pb.vote.ID] {
				continue
			}
			seen[pb.vote.ID] = true
			out = append(out, pb)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].vote.Date != out[j].vote.Date {
			return out[i].vote.Date > out[j].vote.Date
		}
		if out[i].vote.Time != out[j].vote.Time {
			return out[i].vote.Time > out[j].vote.Time
		}
		return out[i].vote.ID > out[j].vote.ID
	})
	return out
}

func guidanceFor(v *HouseVote, party string) *string {
	if party == "" {
		return nil
	}
	target := Fold(party)
	for _, g := range v.Guidance {
		for _, tok := range strings.Fields(Fold(g.Party)) {
			if tok == target {
				return ptr(g.Guidance)
			}
		}
		if Fold(g.Party) == target {
			return ptr(g.Guidance)
		}
	}
	return nil
}

func voteThemes(v *HouseVote) []string {
	return Classify(v.Ementa, v.Description)
}

func (b *builder) person(p *Person) {
	slug := b.slugs[p]
	role := p.Primary()
	houseVotes := p.House == HouseCamara || p.House == HouseSenado
	ballots := b.ballotsOf(p)
	votesByYear := map[int][]PersonVote{}
	for _, pb := range ballots {
		y := year(pb.vote.Date)
		votesByYear[y] = append(votesByYear[y], PersonVote{
			VoteID:        pb.vote.ID,
			Date:          pb.vote.Date,
			Proposition:   strPtr(pb.vote.Proposition),
			Summary:       pb.vote.Description,
			Vote:          pb.ballot.Vote,
			PartyGuidance: guidanceFor(pb.vote, pb.ballot.Party),
			Approved:      pb.vote.Approved,
			Themes:        voteThemes(pb.vote),
		})
	}
	themeCounts := map[string]*ThemeCount{}
	theme := func(key string) *ThemeCount {
		t := themeCounts[key]
		if t == nil {
			t = &ThemeCount{Key: key}
			themeCounts[key] = t
		}
		return t
	}
	cov := func(kind string) Coverage {
		if c, ok := p.Coverage[kind]; ok {
			return c
		}
		return Coverage{Kind: kind, Status: CoverageNotLoaded, Source: ""}
	}
	proposalsOn := cov("proposals").Status == CoverageAvailable
	speechesOn := cov("speeches").Status == CoverageAvailable
	expensesOn := cov("expenses").Status == CoverageAvailable
	attendanceOn := cov("attendance").Status == CoverageAvailable
	votesOn := houseVotes && cov("votes").Status == CoverageAvailable
	var years []YearSummary
	var totProposals, totLaws, totSpeeches, totVotes, present, eligible int
	var totQuota int64
	attendanceSeen := false
	for _, y := range b.ds.Years {
		act := p.Activity[y]
		if act == nil {
			continue
		}
		ys := YearSummary{Year: y}
		if attendanceOn && act.Present != nil && act.Eligible != nil {
			ys.Present, ys.Eligible = ptr(*act.Present), ptr(*act.Eligible)
			present += *act.Present
			eligible += *act.Eligible
			attendanceSeen = true
		}
		if proposalsOn {
			items := make([]Proposal, 0, len(act.Proposals))
			laws := 0
			for _, rp := range act.Proposals {
				pr := proposal(rp)
				if pr.CanBecomeLaw {
					laws++
				}
				for _, k := range pr.Themes {
					theme(k).Proposals++
				}
				items = append(items, pr)
			}
			sort.SliceStable(items, func(i, j int) bool { return items[i].ID > items[j].ID })
			ys.Proposals, ys.Laws = ptr(len(items)), ptr(laws)
			totProposals += len(items)
			totLaws += laws
			b.add(fmt.Sprintf("people/%s/proposals-%d.json", slug, y), ListFile[Proposal]{Items: items, Total: len(items)})
		}
		if speechesOn {
			items := make([]Speech, 0, len(act.Speeches))
			for _, rs := range act.Speeches {
				for _, k := range Classify(rs.Summary, rs.Keywords) {
					theme(k).Speeches++
				}
				items = append(items, Speech{Date: rs.Date, Kind: rs.Kind, Summary: rs.Summary, URL: strPtr(rs.URL)})
			}
			sort.SliceStable(items, func(i, j int) bool { return items[i].Date > items[j].Date })
			ys.Speeches = ptr(len(items))
			totSpeeches += len(items)
			b.add(fmt.Sprintf("people/%s/speeches-%d.json", slug, y), ListFile[Speech]{Items: items, Total: len(items)})
		}
		if votesOn {
			items := votesByYear[y]
			if items == nil {
				items = []PersonVote{}
			}
			ys.Votes = ptr(len(items))
			totVotes += len(items)
			b.add(fmt.Sprintf("people/%s/votes-%d.json", slug, y), ListFile[PersonVote]{Items: items, Total: len(items)})
		}
		if expensesOn {
			ef := expenseFile(act.Expenses)
			ys.QuotaCents = ptr(ef.TotalCents)
			totQuota += ef.TotalCents
			b.add(fmt.Sprintf("people/%s/expenses-%d.json", slug, y), ef)
		}
		if ys.Present != nil || ys.Proposals != nil || ys.Speeches != nil || ys.Votes != nil || ys.QuotaCents != nil {
			years = append(years, ys)
		}
	}
	sort.SliceStable(years, func(i, j int) bool { return years[i].Year > years[j].Year })
	nums := Numbers{}
	if attendanceSeen {
		nums.Attendance = &Attendance{Present: present, Eligible: eligible}
	}
	if proposalsOn {
		nums.Proposals, nums.Laws = ptr(totProposals), ptr(totLaws)
	}
	if speechesOn {
		nums.Speeches = ptr(totSpeeches)
	}
	if votesOn {
		nums.Votes = ptr(totVotes)
	}
	if expensesOn {
		nums.QuotaCents = ptr(totQuota)
	}
	assets, campaigns, timeline := b.electoral(p, &nums)
	themes := []ThemeCount{}
	for _, k := range ThemeKeys() {
		if t, ok := themeCounts[k]; ok {
			themes = append(themes, *t)
		}
	}
	committees := append([]Committee{}, p.Committees...)
	sort.SliceStable(committees, func(i, j int) bool {
		ai, aj := deref(committees[i].End) == "", deref(committees[j].End) == ""
		if ai != aj {
			return ai
		}
		if deref(committees[i].Start) != deref(committees[j].Start) {
			return deref(committees[i].Start) > deref(committees[j].Start)
		}
		return committees[i].Name < committees[j].Name
	})
	coverage := []Coverage{}
	for _, k := range coverageKinds(role.Office) {
		c := cov(k)
		c.Kind = k
		coverage = append(coverage, c)
	}
	var salary *Salary
	for _, s := range b.ds.Salaries {
		if s.Office == role.Office {
			salary = &Salary{MonthlyCents: s.MonthlyCents, Law: s.Law}
		}
	}
	srcIDs := append([]string{}, p.SourceIDs...)
	if salary != nil {
		if id := b.ds.SalarySource[role.Office]; id != "" {
			srcIDs = append(srcIDs, id)
		}
	}
	sort.Strings(srcIDs)
	profile := Profile{
		Slug:       slug,
		Name:       p.Name,
		CivilName:  strPtr(p.CivilName),
		Office:     role.Office,
		UF:         role.UF,
		Party:      role.Party,
		Photo:      strPtr(p.Photo),
		Status:     role.Status,
		Mandate:    Mandate{Start: strPtr(role.MandateStart), End: strPtr(role.MandateEnd)},
		BirthDate:  strPtr(p.BirthDate),
		BirthPlace: strPtr(p.BirthPlace),
		Education:  strPtr(p.Education),
		Contact:    p.Contact,
		Salary:     salary,
		Numbers:    nums,
		Years:      nonNil(years),
		Themes:     themes,
		Committees: committees,
		Assets:     assets,
		Campaigns:  campaigns,
		Timeline:   timeline,
		Coverage:   coverage,
		Sources:    b.sources(srcIDs...),
	}
	b.add("people/"+slug+".json", profile)
}

func coverageKinds(office string) []string {
	switch office {
	case OfficeSenator, OfficeFederalDeputy, OfficeStateDeputy:
		return []string{"attendance", "votes", "proposals", "speeches", "expenses", "assets", "campaigns", "salary"}
	}
	return []string{"assets", "campaigns", "salary"}
}

func (b *builder) electoral(p *Person, nums *Numbers) ([]AssetYear, []Campaign, []TimelineEntry) {
	assets := []AssetYear{}
	campaigns := []Campaign{}
	timeline := []TimelineEntry{}
	cands := append([]Candidacy(nil), p.Candidacies...)
	sort.SliceStable(cands, func(i, j int) bool {
		if cands[i].Year != cands[j].Year {
			return cands[i].Year > cands[j].Year
		}
		return officeRank(cands[i].Office) < officeRank(cands[j].Office)
	})
	for _, c := range cands {
		if c.AssetsLoaded {
			items := mergeAssets(c.Assets)
			var total int64
			for _, it := range items {
				total += it.Cents
			}
			assets = append(assets, AssetYear{Year: c.Year, TotalCents: total, Items: items})
			if nums.AssetsCents == nil {
				nums.AssetsCents = ptr(total)
			}
		}
		campaigns = append(campaigns, Campaign{Year: c.Year, Office: c.Office, Result: strPtr(ResultLabel(c.Result)), RevenueCents: c.RevenueCents, ExpenseCents: c.ExpenseCents})
		if nums.CampaignRevenueCents == nil && c.RevenueCents != nil {
			nums.CampaignRevenueCents = ptr(*c.RevenueCents)
		}
		if nums.LastElectionVotes == nil && c.Votes != nil {
			nums.LastElectionVotes = ptr(*c.Votes)
		}
		timeline = append(timeline, TimelineEntry{Year: c.Year, Office: c.Office, Place: b.placeName(c.UF), Party: strPtr(c.Party), Result: strPtr(ResultLabel(c.Result)), Votes: c.Votes})
	}
	return assets, campaigns, timeline
}

func (b *builder) placeName(uf string) string {
	if uf == "br" {
		return "Brasil"
	}
	for _, s := range b.ds.States {
		if s.Code == uf {
			return s.Name
		}
	}
	return strings.ToUpper(uf)
}

func mergeAssets(in []AssetItem) []AssetItem {
	sum := map[string]int64{}
	var order []string
	for _, a := range in {
		if _, ok := sum[a.Kind]; !ok {
			order = append(order, a.Kind)
		}
		sum[a.Kind] += a.Cents
	}
	out := make([]AssetItem, 0, len(order))
	for _, k := range order {
		out = append(out, AssetItem{Kind: k, Cents: sum[k]})
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Cents != out[j].Cents {
			return out[i].Cents > out[j].Cents
		}
		return out[i].Kind < out[j].Kind
	})
	return out
}

var resultLabels = map[string]string{
	"ELEITO":           "Eleito",
	"ELEITO POR QP":    "Eleito por QP",
	"ELEITO POR MÉDIA": "Eleito por média",
	"SUPLENTE":         "Suplente",
	"NÃO ELEITO":       "Não eleito",
	"2º TURNO":         "2º turno",
	"RENÚNCIA":         "Renúncia",
	"CASSADO":          "Cassado",
	"INDEFERIDO":       "Indeferido",
}

func ResultLabel(r string) string {
	r = strings.TrimSpace(r)
	if r == "" {
		return ""
	}
	if l, ok := resultLabels[strings.ToUpper(r)]; ok {
		return l
	}
	return strings.TrimSuffix(Sentence(strings.ToLower(r)), ".")
}

func proposal(rp RawProposal) Proposal {
	return Proposal{
		ID:           rp.ID,
		Kind:         rp.Kind,
		Number:       rp.Number,
		Year:         rp.Year,
		Summary:      rp.Ementa,
		PlainSummary: PlainSummary(rp.Ementa),
		CanBecomeLaw: CanBecomeLaw(rp.Kind),
		Themes:       Classify(rp.Ementa, rp.Keywords),
		URL:          strPtr(rp.URL),
	}
}

func expenseFile(in []Expense) ExpenseFile {
	items := append([]Expense{}, in...)
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Month != items[j].Month {
			return items[i].Month > items[j].Month
		}
		if items[i].Cents != items[j].Cents {
			return items[i].Cents > items[j].Cents
		}
		return items[i].ID < items[j].ID
	})
	var total int64
	months := map[int]int64{}
	cats := map[string]*CategoryTotal{}
	for _, e := range items {
		total += e.Cents
		months[e.Month] += e.Cents
		c := cats[e.Category]
		if c == nil {
			c = &CategoryTotal{Category: e.Category}
			cats[e.Category] = c
		}
		c.Cents += e.Cents
		c.Count++
	}
	byMonth := []MonthCents{}
	for m := 1; m <= 12; m++ {
		if c, ok := months[m]; ok {
			byMonth = append(byMonth, MonthCents{Month: m, Cents: c})
		}
	}
	byCat := []CategoryTotal{}
	for _, c := range cats {
		byCat = append(byCat, *c)
	}
	sort.SliceStable(byCat, func(i, j int) bool {
		if byCat[i].Cents != byCat[j].Cents {
			return byCat[i].Cents > byCat[j].Cents
		}
		return byCat[i].Category < byCat[j].Category
	})
	return ExpenseFile{Items: items, TotalCents: total, ByMonth: byMonth, ByCategory: byCat}
}

func (b *builder) places() []PlaceEntry {
	out := []PlaceEntry{}
	states := append([]PlaceEntry(nil), b.ds.States...)
	sort.SliceStable(states, func(i, j int) bool { return Fold(states[i].Name) < Fold(states[j].Name) })
	out = append(out, states...)
	muns := append([]PlaceEntry(nil), b.ds.Municipalities...)
	sort.SliceStable(muns, func(i, j int) bool {
		a, c := Fold(muns[i].Name), Fold(muns[j].Name)
		if a != c {
			return a < c
		}
		return muns[i].UF < muns[j].UF
	})
	return append(out, muns...)
}

func groupTitle(office, uf string, elected bool) string {
	t := map[string]string{
		OfficePresident:     "Presidente da República",
		OfficeVicePresident: "Vice-presidente da República",
		OfficeSenator:       "Senadores",
		OfficeFederalDeputy: "Deputados federais",
		OfficeGovernor:      "Governador",
		OfficeViceGovernor:  "Vice-governador",
		OfficeStateDeputy:   "Deputados estaduais",
	}[office]
	if office == OfficeStateDeputy && uf == "df" {
		t = "Deputados distritais"
	}
	if elected {
		t += " (eleitos em 2026, aguardando posse)"
	}
	return t
}

func (b *builder) placeFiles(people []*Person) {
	offices := []struct {
		level, office string
		country       bool
	}{
		{"country", OfficePresident, true},
		{"country", OfficeVicePresident, true},
		{"state", OfficeGovernor, false},
		{"state", OfficeViceGovernor, false},
		{"state", OfficeSenator, false},
		{"state", OfficeFederalDeputy, false},
		{"state", OfficeStateDeputy, false},
	}
	for _, st := range b.ds.States {
		uf := st.Code
		var groups []RepresentativeGroup
		for _, o := range offices {
			for _, elected := range []bool{false, true} {
				var cards []PersonCard
				for _, p := range people {
					for _, r := range p.Roles {
						if r.Office != o.office {
							continue
						}
						if o.country {
							if r.UF != "br" {
								continue
							}
						} else if r.UF != uf {
							continue
						}
						if (r.Status == StatusElected) != elected {
							continue
						}
						cards = append(cards, b.card(p, r))
						break
					}
				}
				if len(cards) == 0 {
					continue
				}
				groups = append(groups, RepresentativeGroup{Level: o.level, Office: o.office, Title: groupTitle(o.office, uf, elected), People: cards})
			}
		}
		if groups == nil {
			groups = []RepresentativeGroup{}
		}
		b.add("places/"+uf+".json", PlaceFile{UF: uf, Name: st.Name, Groups: groups, Sources: b.sources("camara", "senado", "tse", "ibge")})
	}
}

func (b *builder) summary(v *HouseVote) VoteSummary {
	s := VoteSummary{
		ID:          v.ID,
		House:       v.House,
		Date:        v.Date,
		Time:        strPtr(v.Time),
		Proposition: strPtr(v.Proposition),
		Kind:        strPtr(v.Kind),
		Summary:     v.Description,
		Themes:      voteThemes(v),
		Result:      strPtr(v.Result),
		Approved:    v.Approved,
		Nominal:     v.Nominal,
		Yes:         v.Yes,
		No:          v.No,
		Others:      v.Others,
	}
	if v.Ementa != "" {
		s.PlainSummary = strPtr(PlainSummary(v.Ementa))
	}
	return s
}

func quorum(kind, house string) *string {
	k := strings.ToUpper(kind)
	members := map[string][2]int{HouseCamara: {513, 257}, HouseSenado: {81, 41}}[house]
	switch k {
	case "PEC":
		n := 308
		if house == HouseSenado {
			n = 49
		}
		return ptr(fmt.Sprintf("Para passar, uma proposta de emenda à Constituição precisa de 3/5 dos votos (%d de %d) em dois turnos.", n, members[0]))
	case "PLP", "PLS-C", "PLC-C":
		return ptr(fmt.Sprintf("Para passar, um projeto de lei complementar precisa da maioria absoluta (%d de %d).", members[1], members[0]))
	case "":
		return nil
	}
	return ptr(fmt.Sprintf("Para passar, precisa da maioria dos votos, com pelo menos %d de %d presentes.", members[1], members[0]))
}

func (b *builder) votes() {
	all := append([]*HouseVote(nil), b.ds.Votes...)
	sort.SliceStable(all, func(i, j int) bool {
		if all[i].Date != all[j].Date {
			return all[i].Date > all[j].Date
		}
		if all[i].Time != all[j].Time {
			return all[i].Time > all[j].Time
		}
		return all[i].ID > all[j].ID
	})
	recent := []VoteSummary{}
	for i, v := range all {
		s := b.summary(v)
		if i < RecentVotes {
			recent = append(recent, s)
		}
		guidance := append([]PartyGuidance{}, v.Guidance...)
		sort.SliceStable(guidance, func(i, j int) bool { return Fold(guidance[i].Party) < Fold(guidance[j].Party) })
		tally := map[string]*PartyTally{}
		people := []VotePerson{}
		for _, bl := range v.Ballots {
			t := tally[bl.Party]
			if t == nil {
				t = &PartyTally{Party: bl.Party}
				tally[bl.Party] = t
			}
			switch Fold(bl.Vote) {
			case "sim":
				t.Yes++
			case "nao":
				t.No++
			default:
				if bl.Present {
					t.Others++
				}
			}
			var slug *string
			if p, ok := b.byKey[bl.PersonKey]; ok {
				slug = ptr(b.slugs[p])
			}
			people = append(people, VotePerson{Slug: slug, Name: bl.Name, Party: bl.Party, UF: strings.ToLower(bl.UF), Vote: bl.Vote})
		}
		sort.SliceStable(people, func(i, j int) bool { return Fold(people[i].Name) < Fold(people[j].Name) })
		parties := []PartyTally{}
		for _, t := range tally {
			parties = append(parties, *t)
		}
		sort.SliceStable(parties, func(i, j int) bool { return Fold(parties[i].Party) < Fold(parties[j].Party) })
		detail := VoteDetail{VoteSummary: s, Quorum: quorum(v.Kind, v.House), Guidance: guidance, Parties: parties, People: people, Sources: b.sources(v.House)}
		b.add("votes/"+v.ID+".json", detail)
	}
	b.add("votes/recent.json", recent)
}

func (b *builder) agenda() {
	houses := []AgendaHouse{}
	for _, h := range b.ds.Agenda {
		items := []AgendaItem{}
		for _, it := range h.Items {
			items = append(items, AgendaItem{Proposition: it.Proposition, Summary: it.Ementa, Status: strPtr(it.Status), Themes: Classify(it.Ementa), URL: strPtr(it.URL)})
		}
		houses = append(houses, AgendaHouse{House: h.House, InSession: h.InSession, NextSession: strPtr(h.NextSession), Items: items})
	}
	b.add("agenda/today.json", AgendaFile{Date: b.ds.Today, Houses: houses})
}

func (b *builder) money() {
	q := b.ds.Quota
	cats := []CategoryCents{}
	for c, v := range q.ByCategory {
		cats = append(cats, CategoryCents{Category: c, Cents: v})
	}
	sort.SliceStable(cats, func(i, j int) bool {
		if cats[i].Cents != cats[j].Cents {
			return cats[i].Cents > cats[j].Cents
		}
		return cats[i].Category < cats[j].Category
	})
	var camp *CampaignBlock
	if c := b.ds.Campaigns; c != nil {
		origins := []OriginCents{}
		for o, v := range c.ByOrigin {
			origins = append(origins, OriginCents{Origin: o, Cents: v})
		}
		sort.SliceStable(origins, func(i, j int) bool {
			if origins[i].Cents != origins[j].Cents {
				return origins[i].Cents > origins[j].Cents
			}
			return origins[i].Origin < origins[j].Origin
		})
		camp = &CampaignBlock{Year: c.Year, RevenueCents: c.Revenue, ExpenseCents: c.Expense, ByOrigin: origins}
	}
	salaries := append([]OfficeSalary{}, b.ds.Salaries...)
	ids := []string{"camara", "senado"}
	for _, s := range salaries {
		if id := b.ds.SalarySource[s.Office]; id != "" {
			ids = append(ids, id)
		}
	}
	if camp != nil {
		ids = append(ids, "tse")
	}
	if b.ds.Revenue != nil {
		ids = append(ids, "receita")
	}
	b.add("money/overview.json", MoneyOverview{
		Year:      q.Year,
		Quota:     QuotaBlock{FederalDeputiesCents: q.FederalDeputies, SenatorsCents: q.Senators, ByCategory: cats},
		Salaries:  salaries,
		Campaigns: camp,
		Revenue:   b.ds.Revenue,
		Sources:   b.sources(ids...),
	})
}

func (b *builder) today() {
	events := []TodayEvent{}
	for _, r := range b.ds.Races {
		events = append(events, TodayEvent{Kind: "race", Title: r.Title, Summary: r.Summary, Themes: []string{"politica"}, Ref: ptr("races")})
	}
	for _, h := range b.ds.Agenda {
		for _, s := range h.Sessions {
			events = append(events, TodayEvent{Kind: "session", Title: s.Title, Summary: s.Summary, Themes: Classify(s.Summary), Ref: strPtr(s.URL)})
		}
	}
	var todays []*HouseVote
	for _, v := range b.ds.Votes {
		if v.Date == b.ds.Today {
			todays = append(todays, v)
		}
	}
	sort.SliceStable(todays, func(i, j int) bool {
		if todays[i].Time != todays[j].Time {
			return todays[i].Time > todays[j].Time
		}
		return todays[i].ID > todays[j].ID
	})
	for _, v := range todays {
		title := v.Proposition
		if title == "" {
			title = v.Description
		}
		summary := v.Description
		if v.Ementa != "" {
			summary = PlainSummary(v.Ementa)
		}
		events = append(events, TodayEvent{Kind: "vote", Title: title, Summary: summary, Themes: voteThemes(v), Ref: ptr(v.ID)})
	}
	for _, l := range b.ds.Laws {
		if l.Date != b.ds.Today {
			continue
		}
		events = append(events, TodayEvent{Kind: "law", Title: l.Title, Summary: PlainSummary(l.Ementa), Themes: Classify(l.Ementa), Ref: strPtr(l.ID)})
	}
	b.add("today.json", TodayDigest{Date: b.ds.Today, Events: events, Sources: b.sources("camara", "senado", "tse")})
}

func year(date string) int {
	if len(date) < 4 {
		return 0
	}
	n := 0
	for _, c := range date[:4] {
		if c < '0' || c > '9' {
			return 0
		}
		n = n*10 + int(c-'0')
	}
	return n
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func nonNil[T any](in []T) []T {
	if in == nil {
		return []T{}
	}
	return in
}
