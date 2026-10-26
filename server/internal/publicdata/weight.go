package publicdata

import (
	"fmt"
	"math"
	"sort"
	"strings"
)

const (
	ActionProposal = "proposal"
	ActionVote     = "vote"
	ActionSpeech   = "speech"

	StagePresented       = "presented"
	StageCommittee       = "committeeApproved"
	StagePlenaryRejected = "plenaryRejected"
	StagePlenaryApproved = "plenaryApproved"
	StageEnacted         = "enacted"

	ScopeNational  = "national"
	ScopeState     = "state"
	ScopeMunicipal = "municipal"

	WeightMethodVersion = 2

	ConfidenceFull       = "full"
	ConfidencePartial    = "partial"
	ConfidenceImpactOnly = "impactOnly"

	SignalNews       = "news"
	SignalNewsPerson = "newsPerson"
	SignalWiki       = "wiki"
	SignalWikiTheme  = "wikiTheme"
	SignalBluesky    = "bluesky"
	ActionsPerPerson = 40
	actionYears      = 2
)

type Signals struct {
	WindowEnd  string
	News       map[string]int64
	PersonNews map[string]int64
	Wiki       map[string]int64
	ThemeWiki  map[string]int64
	Sources    []string
}

type ActionSignals struct {
	News       *int64 `json:"news"`
	NewsPerson *int64 `json:"newsPerson"`
	Wiki       *int64 `json:"wiki"`
	WikiTheme  *int64 `json:"wikiTheme"`
	Bluesky    *int64 `json:"bluesky"`
	Test       bool   `json:"test"`
}

type Action struct {
	ID           string        `json:"id"`
	Kind         string        `json:"kind"`
	Title        string        `json:"title"`
	Proposition  *string       `json:"proposition"`
	Date         string        `json:"date"`
	URL          *string       `json:"url"`
	Ref          *string       `json:"ref"`
	Ballot       *string       `json:"ballot"`
	Scope        string        `json:"scope"`
	Stage        string        `json:"stage"`
	Themes       []string      `json:"themes"`
	Weight       int           `json:"weight"`
	Repercussion *int          `json:"repercussion"`
	Impact       int           `json:"impact"`
	Signals      ActionSignals `json:"signals"`
	SignalCoverage
}

type SignalCoverage struct {
	Measured   []string `json:"measured"`
	Missing    []string `json:"missing"`
	Confidence string   `json:"confidence"`
}

type ActionFile struct {
	Items   []Action `json:"items"`
	Sources []Source `json:"sources"`
}

type kindFactor struct {
	Kinds []string
	Label string
	Value float64
}

var kindFactors = []kindFactor{
	{[]string{"PEC"}, "Proposta de emenda à Constituição", 1.0},
	{[]string{"PLP", "PLS-C", "PLC-C"}, "Projeto de lei complementar", 0.85},
	{[]string{"MPV"}, "Medida provisória", 0.8},
	{[]string{"PL", "PLS", "PLC", "PLN", "PLV"}, "Projeto de lei", 0.7},
	{[]string{"PDL", "PDS", "PDC"}, "Projeto de decreto legislativo", 0.45},
	{[]string{"PRC", "PRS", "PR"}, "Projeto de resolução", 0.3},
	{[]string{"REQ", "RIC", "RQS", "INC", "IND", "RQN"}, "Requerimento ou indicação", 0.1},
}

const (
	otherKind     = 0.2
	speechKind    = 0.1
	noThemeReach  = 0.5
	impactKindW   = 0.35
	impactScopeW  = 0.20
	impactStageW  = 0.25
	impactThemeW  = 0.20
	signalNewsW   = 0.40
	signalPersonW = 0.20
	signalWikiW   = 0.25
	signalThemeW  = 0.15
	weightRepW    = 0.5
	weightImpW    = 0.5
	capNews       = 200
	capPersonNews = 2000
	capWiki       = 300000
	capThemeWiki  = 100000
	halfLifeDays  = 14
	windowDays    = 90
	minVoteKind   = 0.45
)

var scopeFactors = map[string]float64{ScopeNational: 1.0, ScopeState: 0.5, ScopeMunicipal: 0.2}

var stageFactors = map[string]float64{
	StagePresented:       0.25,
	StageCommittee:       0.5,
	StagePlenaryRejected: 0.6,
	StagePlenaryApproved: 0.75,
	StageEnacted:         1.0,
}

type ThemeReach struct {
	Key     string  `json:"key"`
	Reach   float64 `json:"reach"`
	Reason  string  `json:"reason"`
	Article *string `json:"article"`
}

var themeReach = []ThemeReach{
	{"saude", 1.0, "Toda a população usa o SUS ou é atingida por regra sanitária.", ptr("Saúde pública")},
	{"economia", 1.0, "Emprego, preços e crédito atingem toda a população.", ptr("Economia do Brasil")},
	{"impostos", 1.0, "Tributo e orçamento público atingem toda a população.", ptr("Imposto")},
	{"seguranca", 1.0, "Lei penal e policiamento valem para toda a população.", ptr("Segurança pública")},
	{"consumidor", 1.0, "Toda a população compra produtos e serviços.", ptr("Código de Defesa do Consumidor")},
	{"ambiente", 1.0, "Água, ar e clima atingem toda a população.", ptr("Meio ambiente")},
	{"politica", 1.0, "Regra eleitoral e das instituições vale para todo eleitor.", ptr("Política do Brasil")},
	{"educacao", 0.7, "Estudantes, famílias e profissionais da educação, parte grande da população.", ptr("Educação no Brasil")},
	{"social", 0.7, "Quem recebe benefício ou assistência, parte grande da população.", ptr("Serviço social")},
	{"transporte", 0.7, "Quem usa transporte público, estradas ou trânsito, parte grande da população.", ptr("Transportes do Brasil")},
	{"cidade", 0.7, "Moradia e serviços urbanos, para a população das cidades.", ptr("Urbanismo")},
	{"mulheres", 0.7, "Metade da população, quando a regra é dirigida às mulheres.", ptr("Direitos das mulheres")},
	{"direitos", 0.7, "Grupos protegidos por direitos específicos.", ptr("Direitos humanos")},
	{"tecnologia", 0.7, "Quem usa internet e serviços digitais, parte grande da população.", ptr("Tecnologia")},
	{"campo", 0.4, "Produtores e trabalhadores rurais, um grupo específico.", ptr("Agricultura no Brasil")},
	{"cultura", 0.4, "Artistas, eventos e patrimônio, um grupo específico.", ptr("Cultura do Brasil")},
	{"homenagens", 0.1, "Datas e títulos simbólicos, sem efeito material sobre as pessoas.", nil},
}

func ThemeArticles() map[string]string {
	out := map[string]string{}
	for _, t := range themeReach {
		if t.Article != nil {
			out[t.Key] = *t.Article
		}
	}
	return out
}

func reachOf(themes []string) float64 {
	best := -1.0
	for _, k := range themes {
		for _, t := range themeReach {
			if t.Key == k && t.Reach > best {
				best = t.Reach
			}
		}
	}
	if best < 0 {
		return noThemeReach
	}
	return best
}

func kindValue(kind string) float64 {
	k := strings.ToUpper(strings.TrimSpace(kind))
	for _, f := range kindFactors {
		for _, x := range f.Kinds {
			if x == k {
				return f.Value
			}
		}
	}
	return otherKind
}

func PropositionKey(label string) string {
	r := strings.NewReplacer("nº", " ", "Nº", " ", "n°", " ", "N°", " ", ".", "")
	return Fold(r.Replace(label))
}

func propositionLabel(kind string, number, year int) string {
	if kind == "" || number == 0 || year == 0 {
		return ""
	}
	return fmt.Sprintf("%s %d/%d", strings.ToUpper(kind), number, year)
}

func kindOfLabel(label string) string {
	f := strings.Fields(label)
	if len(f) == 0 {
		return ""
	}
	return f[0]
}

func scopeOf(p *Person) string {
	switch {
	case p.House == HouseCamara || p.House == HouseSenado:
		return ScopeNational
	case Federal(p.Primary().Office):
		return ScopeNational
	}
	switch p.Primary().Office {
	case OfficeMayor, OfficeViceMayor, OfficeCityCouncilor:
		return ScopeMunicipal
	}
	return ScopeState
}

type draft struct {
	id, kind, title, date, url, ref, ballot, label, key string
	scope, stage                                        string
	themes                                              []string
	impact                                              float64
}

type stageIndex struct {
	laws    map[string]bool
	plenary map[string]bool
}

func newStageIndex(ds *Dataset) stageIndex {
	idx := stageIndex{laws: map[string]bool{}, plenary: map[string]bool{}}
	for _, l := range ds.Laws {
		idx.laws[l.ID] = true
		if k := PropositionKey(l.Title); k != "" {
			idx.laws[k] = true
		}
	}
	for _, v := range ds.Votes {
		k := PropositionKey(v.Proposition)
		if k == "" || v.Approved == nil {
			continue
		}
		idx.plenary[k] = idx.plenary[k] || *v.Approved
	}
	return idx
}

func (s stageIndex) of(id, key string) string {
	if s.laws[id] || (key != "" && s.laws[key]) {
		return StageEnacted
	}
	if approved, ok := s.plenary[key]; ok && key != "" {
		if approved {
			return StagePlenaryApproved
		}
		return StagePlenaryRejected
	}
	return StagePresented
}

func impactOf(kind, scope, stage string, themes []string) float64 {
	return 100 * (impactKindW*kind2(kind) + impactScopeW*scopeFactors[scope] + impactStageW*stageFactors[stage] + impactThemeW*reachOf(themes))
}

func kind2(kind string) float64 {
	if kind == ActionSpeech {
		return speechKind
	}
	return kindValue(kind)
}

func recentYears(ds *Dataset) map[int]bool {
	ys := append([]int(nil), ds.Years...)
	sort.Sort(sort.Reverse(sort.IntSlice(ys)))
	out := map[int]bool{}
	for i, y := range ys {
		if i >= actionYears {
			break
		}
		out[y] = true
	}
	return out
}

func voteTitle(v *HouseVote) string {
	if strings.TrimSpace(v.Ementa) != "" {
		return v.Ementa
	}
	return v.Description
}

func collectActions(ds *Dataset) map[*Person][]draft {
	idx := newStageIndex(ds)
	years := recentYears(ds)
	ballots := map[string][]personBallot{}
	for _, v := range ds.Votes {
		if !v.Nominal {
			continue
		}
		for _, bl := range v.Ballots {
			if bl.PersonKey != "" {
				ballots[bl.PersonKey] = append(ballots[bl.PersonKey], personBallot{vote: v, ballot: bl})
			}
		}
	}
	out := map[*Person][]draft{}
	for _, p := range ds.People {
		scope := scopeOf(p)
		var items []draft
		seen := map[string]bool{}
		for y, act := range p.Activity {
			if act == nil || !years[y] {
				continue
			}
			for _, rp := range act.Proposals {
				if seen[rp.ID] || strings.TrimSpace(rp.Ementa) == "" {
					continue
				}
				seen[rp.ID] = true
				label := propositionLabel(rp.Kind, rp.Number, rp.Year)
				key := PropositionKey(label)
				stage := idx.of(rp.ID, key)
				themes := Classify(rp.Ementa, rp.Keywords)
				date := rp.Date
				if date == "" {
					date = fmt.Sprintf("%04d-01-01", rp.Year)
				}
				items = append(items, draft{id: rp.ID, kind: ActionProposal, title: rp.Ementa, date: date, url: rp.URL, label: label, key: key, scope: scope, stage: stage, themes: themes, impact: impactOf(rp.Kind, scope, stage, themes)})
			}
			for i, rs := range act.Speeches {
				if strings.TrimSpace(rs.Summary) == "" {
					continue
				}
				themes := Classify(rs.Summary, rs.Keywords)
				id := fmt.Sprintf("speech-%s-%d-%d", rs.Date, y, i)
				items = append(items, draft{id: id, kind: ActionSpeech, title: rs.Summary, date: dateOnlyText(rs.Date), url: rs.URL, scope: scope, stage: StagePresented, themes: themes, impact: impactOf(ActionSpeech, scope, StagePresented, themes)})
			}
		}
		for _, k := range p.Keys {
			for _, pb := range ballots[k] {
				v := pb.vote
				id := "vote-" + v.ID
				if seen[id] || !years[year(v.Date)] {
					continue
				}
				kind := v.Kind
				if kind == "" {
					kind = kindOfLabel(v.Proposition)
				}
				if kindValue(kind) < minVoteKind {
					continue
				}
				seen[id] = true
				key := PropositionKey(v.Proposition)
				stage := StagePlenaryRejected
				if v.Approved != nil && *v.Approved {
					stage = StagePlenaryApproved
				}
				if key != "" && idx.laws[key] {
					stage = StageEnacted
				}
				themes := voteThemes(v)
				items = append(items, draft{id: id, kind: ActionVote, title: voteTitle(v), date: v.Date, ref: v.ID, ballot: pb.ballot.Vote, label: v.Proposition, key: key, scope: ScopeNational, stage: stage, themes: themes, impact: impactOf(kind, ScopeNational, stage, themes)})
			}
		}
		if len(items) > 0 {
			out[p] = items
		}
	}
	return out
}

func dateOnlyText(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 10 {
		return s[:10]
	}
	return s
}

func personKey(p *Person) string {
	return firstKey(p)
}

type SignalPlan struct {
	Propositions []string
	People       []*Person
}

func PlanSignals(ds *Dataset) SignalPlan {
	drafts := collectActions(ds)
	type ranked struct {
		label  string
		impact float64
		date   string
	}
	best := map[string]ranked{}
	authors := map[string][]*Person{}
	for p, items := range drafts {
		for _, d := range items {
			if d.key == "" {
				continue
			}
			r, ok := best[d.key]
			if !ok || d.impact > r.impact || (d.impact == r.impact && d.date > r.date) {
				best[d.key] = ranked{label: d.label, impact: d.impact, date: d.date}
			}
			if d.kind == ActionProposal {
				authors[d.key] = append(authors[d.key], p)
			}
		}
	}
	keys := make([]string, 0, len(best))
	for k := range best {
		keys = append(keys, k)
	}
	sort.SliceStable(keys, func(i, j int) bool {
		a, b := best[keys[i]], best[keys[j]]
		if a.impact != b.impact {
			return a.impact > b.impact
		}
		if a.date != b.date {
			return a.date > b.date
		}
		return keys[i] < keys[j]
	})
	plan := SignalPlan{}
	seen := map[*Person]bool{}
	for _, k := range keys {
		plan.Propositions = append(plan.Propositions, best[k].label)
		list := authors[k]
		sort.SliceStable(list, func(i, j int) bool { return Fold(list[i].Name) < Fold(list[j].Name) })
		for _, p := range list {
			if !seen[p] {
				seen[p] = true
				plan.People = append(plan.People, p)
			}
		}
	}
	rest := []*Person{}
	for p := range drafts {
		if !seen[p] {
			rest = append(rest, p)
		}
	}
	sort.SliceStable(rest, func(i, j int) bool {
		if Fold(rest[i].Name) != Fold(rest[j].Name) {
			return Fold(rest[i].Name) < Fold(rest[j].Name)
		}
		return personKey(rest[i]) < personKey(rest[j])
	})
	plan.People = append(plan.People, rest...)
	return plan
}

func PersonSignalKey(p *Person) string {
	return personKey(p)
}

func scaled(v *int64, cap float64) float64 {
	if v == nil || *v <= 0 {
		return 0
	}
	return math.Min(1, math.Log10(1+float64(*v))/math.Log10(1+cap))
}

func lookup(m map[string]int64, k string) *int64 {
	if m == nil || k == "" {
		return nil
	}
	if v, ok := m[k]; ok {
		return ptr(v)
	}
	return nil
}

func themeViews(s *Signals, themes []string) *int64 {
	if s == nil {
		return nil
	}
	var best *int64
	for _, t := range themes {
		if v := lookup(s.ThemeWiki, t); v != nil && (best == nil || *v > *best) {
			best = v
		}
	}
	return best
}

func signalsFor(s *Signals, p *Person, d draft) ActionSignals {
	if s == nil {
		return ActionSignals{}
	}
	out := ActionSignals{News: lookup(s.News, d.key), WikiTheme: themeViews(s, d.themes)}
	if p != nil {
		out.NewsPerson = lookup(s.PersonNews, personKey(p))
		out.Wiki = lookup(s.Wiki, personKey(p))
	}
	return out
}

type signalTerm struct {
	key      string
	value    *int64
	cap      float64
	share    float64
	personal bool
}

func terms(sig ActionSignals) []signalTerm {
	return []signalTerm{
		{SignalNews, sig.News, capNews, signalNewsW, false},
		{SignalNewsPerson, sig.NewsPerson, capPersonNews, signalPersonW, true},
		{SignalWiki, sig.Wiki, capWiki, signalWikiW, true},
		{SignalWikiTheme, sig.WikiTheme, capThemeWiki, signalThemeW, false},
	}
}

func repercussionOf(sig ActionSignals, personal bool) (*float64, SignalCoverage) {
	cov := SignalCoverage{Measured: []string{}, Missing: []string{}}
	sum, shares := 0.0, 0.0
	expected := 0
	for _, t := range terms(sig) {
		if t.personal && !personal {
			continue
		}
		expected++
		if t.value == nil {
			cov.Missing = append(cov.Missing, t.key)
			continue
		}
		cov.Measured = append(cov.Measured, t.key)
		sum += t.share * scaled(t.value, t.cap)
		shares += t.share
	}
	if sig.Bluesky == nil {
		cov.Missing = append(cov.Missing, SignalBluesky)
	}
	switch {
	case len(cov.Measured) == 0:
		cov.Confidence = ConfidenceImpactOnly
		return nil, cov
	case len(cov.Measured) == expected:
		cov.Confidence = ConfidenceFull
	default:
		cov.Confidence = ConfidencePartial
	}
	rep := 100 * sum / shares
	return &rep, cov
}

func round(v float64) int {
	return int(math.Round(math.Max(0, math.Min(100, v))))
}

func weightOf(rep *float64, imp float64) int {
	if rep == nil {
		return round(imp)
	}
	return round(weightRepW**rep + weightImpW*imp)
}

func (d draft) action(sig ActionSignals, personal bool) Action {
	rep, cov := repercussionOf(sig, personal)
	var shown *int
	if rep != nil {
		shown = ptr(round(*rep))
	}
	return Action{
		ID: d.id, Kind: d.kind, Title: d.title, Proposition: strPtr(d.label), Date: d.date, URL: strPtr(d.url),
		Ref: strPtr(d.ref), Ballot: strPtr(d.ballot), Scope: d.scope, Stage: d.stage, Themes: nonNil(d.themes),
		Weight: weightOf(rep, d.impact), Repercussion: shown, Impact: round(d.impact), Signals: sig, SignalCoverage: cov,
	}
}

func sortActions(items []Action) {
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Weight != items[j].Weight {
			return items[i].Weight > items[j].Weight
		}
		if items[i].Date != items[j].Date {
			return items[i].Date > items[j].Date
		}
		return items[i].ID < items[j].ID
	})
}
