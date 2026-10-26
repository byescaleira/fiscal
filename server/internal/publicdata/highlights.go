package publicdata

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"
)

const (
	HighlightAction    = "action"
	HighlightVote      = "vote"
	HighlightMoney     = "money"
	HighlightIndicator = "indicator"
	HighlightLimit     = 4
	AlertMinWeight     = 85
	AlertMaxAgeHours   = 24
)

type Highlight struct {
	ID           string        `json:"id"`
	Kind         string        `json:"kind"`
	Title        string        `json:"title"`
	Subtitle     string        `json:"subtitle"`
	Weight       int           `json:"weight"`
	Repercussion *int          `json:"repercussion"`
	Impact       int           `json:"impact"`
	Route        string        `json:"route"`
	Person       *PersonCard   `json:"person"`
	Proposition  *string       `json:"proposition"`
	Date         string        `json:"date"`
	URL          *string       `json:"url"`
	Signals      ActionSignals `json:"signals"`
	SignalCoverage
}

type HighlightFile struct {
	GeneratedAt string       `json:"generatedAt"`
	Items       []Highlight  `json:"items"`
	Method      WeightMethod `json:"method"`
	Sources     []Source     `json:"sources"`
}

type MethodValue struct {
	Key   string  `json:"key"`
	Label string  `json:"label"`
	Value float64 `json:"value"`
	Note  *string `json:"note"`
}

type MethodSignal struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	URL      string  `json:"url"`
	Measures string  `json:"measures"`
	Window   string  `json:"window"`
	Cap      int64   `json:"cap"`
	Share    float64 `json:"share"`
	Status   string  `json:"status"`
	Note     *string `json:"note"`
}

type MethodPart struct {
	Key   string  `json:"key"`
	Label string  `json:"label"`
	Share float64 `json:"share"`
}

type MethodDecay struct {
	HalfLifeDays int    `json:"halfLifeDays"`
	WindowDays   int    `json:"windowDays"`
	Text         string `json:"text"`
}

type MethodAlert struct {
	MinWeight   int    `json:"minWeight"`
	MaxAgeHours int    `json:"maxAgeHours"`
	Text        string `json:"text"`
}

type MethodConfidence struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	Text  string `json:"text"`
}

type WeightMethod struct {
	Version         int                `json:"version"`
	Summary         string             `json:"summary"`
	Formula         string             `json:"formula"`
	Repercussion    string             `json:"repercussion"`
	Renormalization string             `json:"renormalization"`
	Confidence      []MethodConfidence `json:"confidence"`
	Impact          string             `json:"impact"`
	Parts           []MethodPart       `json:"parts"`
	Signals         []MethodSignal     `json:"signals"`
	ImpactParts     []MethodPart       `json:"impactParts"`
	Kinds           []MethodValue      `json:"kinds"`
	Scopes          []MethodValue      `json:"scopes"`
	Stages          []MethodValue      `json:"stages"`
	Themes          []ThemeReach       `json:"themes"`
	Decay           MethodDecay        `json:"decay"`
	Rules           []string           `json:"rules"`
	Limits          []string           `json:"limits"`
	Sources         []Source           `json:"sources"`
	Alert           MethodAlert        `json:"alert"`
}

func Method(sources []Source) WeightMethod {
	kinds := []MethodValue{}
	for _, k := range kindFactors {
		kinds = append(kinds, MethodValue{Key: strings.Join(k.Kinds, ", "), Label: k.Label, Value: k.Value})
	}
	kinds = append(kinds,
		MethodValue{Key: "outros", Label: "Outros tipos", Value: otherKind},
		MethodValue{Key: "discurso", Label: "Discurso", Value: speechKind},
	)
	committee := "Ainda não medido: os arquivos abertos usados não trazem o parecer de comissão."
	bluesky := "A busca pública do Bluesky (app.bsky.feed.searchPosts em public.api.bsky.app) responde 403 sem autenticação; o sinal fica fora da conta para todos e aparece na lista do que faltou."
	gdelt := "Limite de uma consulta a cada 5 segundos; cada carga mede uma parte, por ordem de impacto, e guarda o resultado por 3 dias. O que não foi medido fica fora da conta, não vira zero."
	alert := fmt.Sprintf("Na tela de bloqueio (Live Activity) só entra destaque com peso %d ou mais, de um fato de até %d horas depois do fim do dia dele (horário de Brasília), uma vez por aparelho e por até 8 horas. Dá para desligar em Ajustes.", AlertMinWeight, AlertMaxAgeHours)
	return WeightMethod{
		Version:         WeightMethodVersion,
		Summary:         "O peso ordena o que cada político faz, de 0 a 100. Ele soma quanto se fala do assunto (repercussão) e o alcance da medida (impacto). A mesma regra vale para todos os políticos e temas, e o peso nunca diz se a medida é boa ou ruim.",
		Formula:         "Peso = 50% repercussão + 50% impacto; sem nenhum sinal de repercussão medido, peso = impacto",
		Repercussion:    "Contagens dos últimos 30 dias em fontes abertas, em escala logarítmica até um teto, para que um número muito alto não apague os outros.",
		Renormalization: "Sinal ausente não conta como zero. A repercussão é a média ponderada só dos sinais medidos nesta carga: os pesos dos que faltaram saem da conta e os dos medidos são divididos pela soma deles. Exemplo: com só as duas visitas à Wikipédia (25% e 15%), cada uma passa a valer 25/40 e 15/40. Votação de plenário não tem um autor, então os sinais do político não entram nela. Sem nenhum sinal medido, o peso é só o impacto, e o app avisa.",
		Confidence: []MethodConfidence{
			{Key: ConfidenceFull, Label: "Medido", Text: "Todos os sinais de repercussão que valem para o fato foram medidos nesta carga."},
			{Key: ConfidencePartial, Label: "Estimado", Text: "Parte dos sinais faltou; a repercussão usa só os medidos, e o app diz quais faltaram."},
			{Key: ConfidenceImpactOnly, Label: "Só impacto", Text: "Nenhum sinal de repercussão foi medido; o peso é o impacto, pela regra fixa."},
		},
		Impact: "Regra fixa: tipo da proposição, abrangência, estágio e o alcance do tema em pessoas atingidas.",
		Parts: []MethodPart{
			{Key: "news", Label: "Notícias sobre a proposição", Share: signalNewsW},
			{Key: "newsPerson", Label: "Notícias que citam o político", Share: signalPersonW},
			{Key: "wiki", Label: "Visitas ao artigo do político na Wikipédia", Share: signalWikiW},
			{Key: "wikiTheme", Label: "Visitas ao artigo do tema na Wikipédia", Share: signalThemeW},
			{Key: "bluesky", Label: "Posts no Bluesky", Share: 0},
		},
		Signals: []MethodSignal{
			{ID: "gdelt", Name: "GDELT DOC 2.0", URL: "https://api.gdeltproject.org/api/v2/doc/doc", Measures: "Número de notícias em português que citam a proposição (\"PL 1234/2025\") ou o nome do político", Window: "30 dias", Cap: capNews, Share: signalNewsW + signalPersonW, Status: "measured", Note: ptr(gdelt)},
			{ID: "wikipedia", Name: "Wikimedia Pageviews", URL: "https://wikimedia.org/api/rest_v1/metrics/pageviews/", Measures: "Visitas de pessoas (sem robôs) ao artigo do político e ao artigo do tema na Wikipédia em português", Window: "30 dias", Cap: capWiki, Share: signalWikiW + signalThemeW, Status: "measured", Note: ptr("O artigo do político só conta quando o título é exatamente o nome dele, não é desambiguação e a descrição do artigo fala de política.")},
			{ID: "bluesky", Name: "Bluesky", URL: "https://public.api.bsky.app", Measures: "Posts que citam a proposição", Window: "30 dias", Cap: 0, Share: 0, Status: "notMeasured", Note: ptr(bluesky)},
		},
		ImpactParts: []MethodPart{
			{Key: "kind", Label: "Tipo da proposição", Share: impactKindW},
			{Key: "scope", Label: "Abrangência", Share: impactScopeW},
			{Key: "stage", Label: "Estágio", Share: impactStageW},
			{Key: "theme", Label: "Alcance do tema", Share: impactThemeW},
		},
		Kinds: kinds,
		Scopes: []MethodValue{
			{Key: ScopeNational, Label: "Nacional (Câmara, Senado, Presidência)", Value: scopeFactors[ScopeNational]},
			{Key: ScopeState, Label: "Estadual (assembleias e governos)", Value: scopeFactors[ScopeState]},
			{Key: ScopeMunicipal, Label: "Municipal (prefeituras e câmaras)", Value: scopeFactors[ScopeMunicipal]},
		},
		Stages: []MethodValue{
			{Key: StagePresented, Label: "Apresentado", Value: stageFactors[StagePresented]},
			{Key: StageCommittee, Label: "Aprovado em comissão", Value: stageFactors[StageCommittee], Note: ptr(committee)},
			{Key: StagePlenaryRejected, Label: "Votado e rejeitado em plenário", Value: stageFactors[StagePlenaryRejected]},
			{Key: StagePlenaryApproved, Label: "Aprovado em plenário", Value: stageFactors[StagePlenaryApproved]},
			{Key: StageEnacted, Label: "Virou lei (sancionado ou promulgado)", Value: stageFactors[StageEnacted]},
		},
		Themes: append([]ThemeReach{}, themeReach...),
		Decay: MethodDecay{
			HalfLifeDays: halfLifeDays, WindowDays: windowDays,
			Text: fmt.Sprintf("No Destaque do momento, o peso cai pela metade a cada %d dias desde a data do fato. Entram os fatos dos últimos %d dias; sem nenhum, fica o de maior peso.", halfLifeDays, windowDays),
		},
		Rules: []string{
			"A mesma regra vale para todos os políticos, partidos e temas.",
			"O tema só conta pelo alcance de pessoas atingidas, pela tabela pública; nenhum tema pesa por lado político.",
			"O título é sempre o texto oficial (a ementa), sem resumo opinativo.",
			"O peso ordena e destaca; ele não qualifica a medida nem o político.",
			"Guardamos só contagens; nenhum texto de notícia ou post é copiado.",
			alert,
		},
		Limits: []string{
			"A repercussão mede quanto se fala, não se o que se fala é verdade nem o tom.",
			"A imprensa coberta pelo GDELT não é toda a imprensa, e a Wikipédia mede curiosidade, não apoio.",
			"X, Instagram, TikTok e YouTube ficam de fora: não têm busca aberta e gratuita usada aqui.",
			"Homônimos podem somar notícias de outra pessoa com o mesmo nome.",
			"Com sinais faltando, a repercussão vem de menos fontes e pode mudar quando a próxima carga medir o resto.",
		},
		Sources: sources,
		Alert:   MethodAlert{MinWeight: AlertMinWeight, MaxAgeHours: AlertMaxAgeHours, Text: alert},
	}
}

func parseDay(s string) (time.Time, bool) {
	t, err := time.Parse("2006-01-02", dateOnlyText(s))
	return t, err == nil
}

func decayed(weight int, date string, today time.Time) (float64, bool) {
	t, ok := parseDay(date)
	if !ok {
		return 0, false
	}
	age := today.Sub(t).Hours() / 24
	if age < 0 {
		age = 0
	}
	return float64(weight) * math.Pow(0.5, age/halfLifeDays), age <= windowDays
}

type candidate struct {
	h       Highlight
	key     string
	score   float64
	inRange bool
}

func partyUF(r Role) string {
	switch {
	case r.Party != "" && r.UF != "" && r.UF != "br":
		return fmt.Sprintf("%s-%s", r.Party, strings.ToUpper(r.UF))
	case r.Party != "":
		return r.Party
	}
	return strings.ToUpper(r.UF)
}

func houseName(h string) string {
	switch h {
	case HouseCamara:
		return "Câmara"
	case HouseSenado:
		return "Senado"
	}
	return ""
}

func joinParts(parts ...string) string {
	out := []string{}
	for _, p := range parts {
		if strings.TrimSpace(p) != "" {
			out = append(out, p)
		}
	}
	return strings.Join(out, " · ")
}

func (b *builder) weights(people []*Person) {
	drafts := collectActions(b.ds)
	sig := b.ds.Signals
	signalIDs := []string{}
	if sig != nil {
		signalIDs = sig.Sources
	}
	today, ok := parseDay(b.ds.Today)
	if !ok {
		today = b.ds.GeneratedAt
	}
	type group struct {
		best    Action
		person  *Person
		authors []*Person
	}
	groups := map[string]*group{}
	for _, p := range people {
		items := drafts[p]
		if len(items) == 0 {
			continue
		}
		actions := make([]Action, 0, len(items))
		for _, d := range items {
			a := d.action(signalsFor(sig, p, d), true)
			actions = append(actions, a)
			if d.kind != ActionProposal {
				continue
			}
			k := d.key
			if k == "" {
				k = d.id
			}
			g := groups[k]
			if g == nil {
				g = &group{best: a, person: p}
				groups[k] = g
			} else if a.Weight > g.best.Weight {
				g.best, g.person = a, p
			}
			g.authors = append(g.authors, p)
		}
		sortActions(actions)
		if len(actions) > ActionsPerPerson {
			actions = actions[:ActionsPerPerson]
		}
		ids := append(append([]string{}, p.SourceIDs...), signalIDs...)
		sort.Strings(ids)
		b.add("people/"+b.slugs[p]+"/actions.json", ActionFile{Items: actions, Sources: b.sources(ids...)})
	}
	var cands []candidate
	for k, g := range groups {
		card := b.card(g.person, g.person.Primary())
		who := fmt.Sprintf("%s (%s)", g.person.Name, partyUF(g.person.Primary()))
		if n := len(g.authors) - 1; n == 1 {
			who += " e mais 1"
		} else if n > 1 {
			who += fmt.Sprintf(" e mais %d", n)
		}
		a := g.best
		score, in := decayed(a.Weight, a.Date, today)
		cands = append(cands, candidate{key: k, score: score, inRange: in, h: Highlight{
			ID: "action-" + a.ID, Kind: HighlightAction, Title: a.Title, Subtitle: joinParts(deref(a.Proposition), who),
			Weight: a.Weight, Repercussion: a.Repercussion, Impact: a.Impact, Route: card.Slug, Person: &card,
			Proposition: a.Proposition, Date: a.Date, URL: a.URL, Signals: a.Signals, SignalCoverage: a.SignalCoverage,
		}})
	}
	idx := newStageIndex(b.ds)
	for _, v := range b.ds.Votes {
		if !v.Nominal {
			continue
		}
		kind := v.Kind
		if kind == "" {
			kind = kindOfLabel(v.Proposition)
		}
		if kindValue(kind) < minVoteKind {
			continue
		}
		key := PropositionKey(v.Proposition)
		stage := StagePlenaryRejected
		if v.Approved != nil && *v.Approved {
			stage = StagePlenaryApproved
		}
		if key != "" && idx.laws[key] {
			stage = StageEnacted
		}
		themes := voteThemes(v)
		d := draft{id: "vote-" + v.ID, kind: ActionVote, title: voteTitle(v), date: v.Date, ref: v.ID, label: v.Proposition, key: key, scope: ScopeNational, stage: stage, themes: themes, impact: impactOf(kind, ScopeNational, stage, themes)}
		a := d.action(signalsFor(sig, nil, d), false)
		score, in := decayed(a.Weight, a.Date, today)
		k := key
		if k == "" {
			k = d.id
		}
		cands = append(cands, candidate{key: k, score: score, inRange: in, h: Highlight{
			ID: d.id, Kind: HighlightVote, Title: a.Title, Subtitle: joinParts(houseName(v.House), v.Proposition, v.Result),
			Weight: a.Weight, Repercussion: a.Repercussion, Impact: a.Impact, Route: v.ID,
			Proposition: a.Proposition, Date: a.Date, Signals: a.Signals, SignalCoverage: a.SignalCoverage,
		}})
	}
	sort.SliceStable(cands, func(i, j int) bool {
		if cands[i].score != cands[j].score {
			return cands[i].score > cands[j].score
		}
		if cands[i].h.Weight != cands[j].h.Weight {
			return cands[i].h.Weight > cands[j].h.Weight
		}
		if cands[i].h.Date != cands[j].h.Date {
			return cands[i].h.Date > cands[j].h.Date
		}
		return cands[i].h.ID < cands[j].h.ID
	})
	items := []Highlight{}
	used := map[string]bool{}
	for _, c := range cands {
		if len(items) >= HighlightLimit {
			break
		}
		if !c.inRange || used[c.key] {
			continue
		}
		used[c.key] = true
		items = append(items, c.h)
	}
	if len(items) == 0 && len(cands) > 0 {
		best := cands[0]
		for _, c := range cands[1:] {
			if c.h.Weight > best.h.Weight || (c.h.Weight == best.h.Weight && c.h.Date > best.h.Date) {
				best = c
			}
		}
		items = append(items, best.h)
	}
	methodIDs := append([]string{"camara", "senado"}, signalIDs...)
	method := Method(b.sources(methodIDs...))
	b.add("method/weight.json", method)
	b.add("highlights.json", HighlightFile{GeneratedAt: stamp(b.ds.GeneratedAt), Items: items, Method: method, Sources: b.sources(methodIDs...)})
}
