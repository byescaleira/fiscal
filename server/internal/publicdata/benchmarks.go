package publicdata

import (
	"fmt"
	"math"
	"sort"
	"time"
)

const (
	BenchmarkMethodVersion = 1
	BenchmarkMinPeers      = 5

	MetricPresence  = "presence"
	MetricQuota     = "quota"
	MetricProposals = "proposals"
	MetricSpeeches  = "speeches"

	BandBetter  = "better"
	BandAverage = "average"
	BandWorse   = "worse"
	BandMore    = "more"
	BandLess    = "less"

	HouseAssembly = "assembleia"

	RelevanceHigh       = "high"
	RelevanceMedium     = "medium"
	RelevanceLow        = "low"
	RelevanceHighMin    = 70
	RelevanceMediumMin  = 40
	benchmarkDateLayout = "2006-01-02"
)

func RelevanceOf(weight int) string {
	switch {
	case weight >= RelevanceHighMin:
		return RelevanceHigh
	case weight >= RelevanceMediumMin:
		return RelevanceMedium
	}
	return RelevanceLow
}

type Quartiles struct {
	P25    float64 `json:"p25"`
	Median float64 `json:"median"`
	P75    float64 `json:"p75"`
	N      int     `json:"n"`
}

type BenchmarkMetrics struct {
	Presence  *Quartiles `json:"presence"`
	Quota     *Quartiles `json:"quota"`
	Proposals *Quartiles `json:"proposals"`
	Speeches  *Quartiles `json:"speeches"`
}

type Benchmark struct {
	Office  string           `json:"office"`
	House   string           `json:"house"`
	UF      *string          `json:"uf"`
	Year    int              `json:"year"`
	Metrics BenchmarkMetrics `json:"metrics"`
	Sources []Source         `json:"sources"`
}

type BenchmarkFile struct {
	GeneratedAt string      `json:"generatedAt"`
	Items       []Benchmark `json:"items"`
	Sources     []Source    `json:"sources"`
}

type MetricClass struct {
	Value  float64 `json:"value"`
	Band   string  `json:"band"`
	Median float64 `json:"median"`
	P25    float64 `json:"p25"`
	P75    float64 `json:"p75"`
	N      int     `json:"n"`
}

type Classification struct {
	Year      int          `json:"year"`
	Office    string       `json:"office"`
	House     string       `json:"house"`
	UF        *string      `json:"uf"`
	Presence  *MetricClass `json:"presence"`
	Quota     *MetricClass `json:"quota"`
	Proposals *MetricClass `json:"proposals"`
	Speeches  *MetricClass `json:"speeches"`
}

type BenchmarkBand struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	Rule  string `json:"rule"`
}

type BenchmarkMetricRule struct {
	Key       string          `json:"key"`
	Label     string          `json:"label"`
	Unit      string          `json:"unit"`
	Direction string          `json:"direction"`
	Text      string          `json:"text"`
	Bands     []BenchmarkBand `json:"bands"`
}

type BenchmarkMethod struct {
	Version   int                   `json:"version"`
	Summary   string                `json:"summary"`
	Groups    string                `json:"groups"`
	Year      string                `json:"year"`
	Quartiles string                `json:"quartiles"`
	MinPeers  int                   `json:"minPeers"`
	Metrics   []BenchmarkMetricRule `json:"metrics"`
	Limits    []string              `json:"limits"`
	Sources   []Source              `json:"sources"`
}

type peerValues struct {
	presence, quota, proposals, speeches *float64
}

type benchGroup struct {
	office, house, uf string
	members           []*Person
}

func (b *builder) benchmarks(people []*Person) map[*Person]*Classification {
	groups := map[string]*benchGroup{}
	var keys []string
	for _, p := range people {
		r := p.Primary()
		if r.Status != StatusInOffice {
			continue
		}
		house := ""
		uf := ""
		switch r.Office {
		case OfficeFederalDeputy:
			house = HouseCamara
		case OfficeSenator:
			house = HouseSenado
		case OfficeStateDeputy:
			house, uf = HouseAssembly, r.UF
		default:
			continue
		}
		k := r.Office + "/" + uf
		g := groups[k]
		if g == nil {
			g = &benchGroup{office: r.Office, house: house, uf: uf}
			groups[k] = g
			keys = append(keys, k)
		}
		g.members = append(g.members, p)
	}
	sort.Strings(keys)
	today := b.benchToday()
	years := append([]int(nil), b.ds.Years...)
	sort.Sort(sort.Reverse(sort.IntSlice(years)))
	classes := map[*Person]*Classification{}
	items := []Benchmark{}
	allIDs := []string{}
	for _, k := range keys {
		g := groups[k]
		for _, y := range years {
			if y > today.Year() {
				continue
			}
			values := map[*Person]peerValues{}
			for _, p := range g.members {
				values[p] = b.peerValues(p, y, today)
			}
			metrics := BenchmarkMetrics{
				Presence:  quartilesOf(values, func(v peerValues) *float64 { return v.presence }, 1),
				Quota:     quartilesOf(values, func(v peerValues) *float64 { return v.quota }, 0),
				Proposals: quartilesOf(values, func(v peerValues) *float64 { return v.proposals }, 1),
				Speeches:  quartilesOf(values, func(v peerValues) *float64 { return v.speeches }, 1),
			}
			if metrics.Presence == nil && metrics.Quota == nil && metrics.Proposals == nil && metrics.Speeches == nil {
				continue
			}
			ids := benchSourceIDs(g)
			allIDs = append(allIDs, ids...)
			var uf *string
			if g.uf != "" {
				uf = ptr(g.uf)
			}
			items = append(items, Benchmark{Office: g.office, House: g.house, UF: uf, Year: y, Metrics: metrics, Sources: b.sources(ids...)})
			for _, p := range g.members {
				v := values[p]
				c := &Classification{
					Year: y, Office: g.office, House: g.house, UF: uf,
					Presence:  classOf(MetricPresence, v.presence, metrics.Presence, 1),
					Quota:     classOf(MetricQuota, v.quota, metrics.Quota, 0),
					Proposals: classOf(MetricProposals, v.proposals, metrics.Proposals, 1),
					Speeches:  classOf(MetricSpeeches, v.speeches, metrics.Speeches, 1),
				}
				if c.Presence != nil || c.Quota != nil || c.Proposals != nil || c.Speeches != nil {
					classes[p] = c
				}
			}
			break
		}
	}
	sort.Strings(allIDs)
	src := b.sources(allIDs...)
	b.add("index/benchmarks.json", BenchmarkFile{GeneratedAt: stamp(b.ds.GeneratedAt), Items: items, Sources: src})
	b.add("method/benchmarks.json", BenchmarkRules(src))
	return classes
}

func benchSourceIDs(g *benchGroup) []string {
	switch g.house {
	case HouseCamara, HouseSenado:
		return []string{g.house}
	}
	seen := map[string]bool{}
	var ids []string
	for _, p := range g.members {
		if p.Assembly != "" && !seen[p.Assembly] {
			seen[p.Assembly] = true
			ids = append(ids, p.Assembly)
		}
	}
	sort.Strings(ids)
	return ids
}

func (b *builder) benchToday() time.Time {
	if t, err := time.Parse(benchmarkDateLayout, b.ds.Today); err == nil {
		return t
	}
	g := b.ds.GeneratedAt
	return time.Date(g.Year(), g.Month(), g.Day(), 0, 0, 0, 0, time.UTC)
}

func (b *builder) peerValues(p *Person, y int, today time.Time) peerValues {
	out := peerValues{}
	months := MandateMonths(p.Primary(), y, today)
	act := p.Activity[y]
	if months == 0 || act == nil {
		return out
	}
	on := func(kind string) bool {
		c, ok := p.Coverage[kind]
		return ok && c.Status == CoverageAvailable
	}
	if on("attendance") && act.Present != nil && act.Eligible != nil && *act.Eligible > 0 {
		out.presence = ptr(100 * float64(*act.Present) / float64(*act.Eligible))
	}
	if on("expenses") {
		var total int64
		for _, e := range act.Expenses {
			total += e.Cents
		}
		out.quota = ptr(float64(total) / float64(months))
	}
	if on("proposals") {
		out.proposals = ptr(float64(len(act.Proposals)))
	}
	if on("speeches") {
		out.speeches = ptr(float64(len(act.Speeches)))
	}
	return out
}

func MandateMonths(r Role, y int, today time.Time) int {
	start := time.Date(y, time.January, 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(y, time.December, 31, 0, 0, 0, 0, time.UTC)
	if y == today.Year() {
		end = time.Date(y, today.Month(), today.Day(), 0, 0, 0, 0, time.UTC)
	}
	if y > today.Year() {
		return 0
	}
	if t, err := time.Parse(benchmarkDateLayout, dateOnlyText(r.MandateStart)); err == nil && t.After(start) {
		start = t
	}
	if t, err := time.Parse(benchmarkDateLayout, dateOnlyText(r.MandateEnd)); err == nil && t.Before(end) {
		end = t
	}
	if end.Before(start) {
		return 0
	}
	return (end.Year()-start.Year())*12 + int(end.Month()) - int(start.Month()) + 1
}

func quartilesOf(values map[*Person]peerValues, pick func(peerValues) *float64, digits int) *Quartiles {
	var xs []float64
	for _, v := range values {
		if x := pick(v); x != nil {
			xs = append(xs, roundTo(*x, digits))
		}
	}
	if len(xs) < BenchmarkMinPeers {
		return nil
	}
	sort.Float64s(xs)
	return &Quartiles{
		P25:    roundTo(percentile(xs, 0.25), digits),
		Median: roundTo(percentile(xs, 0.5), digits),
		P75:    roundTo(percentile(xs, 0.75), digits),
		N:      len(xs),
	}
}

func percentile(sorted []float64, q float64) float64 {
	pos := q * float64(len(sorted)-1)
	lo := int(math.Floor(pos))
	hi := int(math.Ceil(pos))
	return sorted[lo] + (sorted[hi]-sorted[lo])*(pos-float64(lo))
}

func classOf(metric string, v *float64, q *Quartiles, digits int) *MetricClass {
	if v == nil || q == nil {
		return nil
	}
	x := roundTo(*v, digits)
	return &MetricClass{Value: x, Band: BandOf(metric, x, *q), Median: q.Median, P25: q.P25, P75: q.P75, N: q.N}
}

func BandOf(metric string, v float64, q Quartiles) string {
	above, below := v > q.P75, v < q.P25
	switch metric {
	case MetricPresence:
		if above {
			return BandBetter
		}
		if below {
			return BandWorse
		}
	case MetricQuota:
		if above {
			return BandWorse
		}
		if below {
			return BandBetter
		}
	default:
		if above {
			return BandMore
		}
		if below {
			return BandLess
		}
	}
	return BandAverage
}

func BenchmarkRules(sources []Source) BenchmarkMethod {
	directional := func(higher, lower string) []BenchmarkBand {
		return []BenchmarkBand{
			{Key: BandBetter, Label: "Melhor que a média", Rule: higher},
			{Key: BandAverage, Label: "Na média", Rule: "Entre o primeiro e o terceiro quartil (p25 a p75), com os dois limites incluídos."},
			{Key: BandWorse, Label: "Pior que a média", Rule: lower},
		}
	}
	activity := []BenchmarkBand{
		{Key: BandMore, Label: "Mais ativo que a média", Rule: "Acima do terceiro quartil (p75) da casa."},
		{Key: BandAverage, Label: "Na média", Rule: "Entre o primeiro e o terceiro quartil (p25 a p75), com os dois limites incluídos."},
		{Key: BandLess, Label: "Menos ativo que a média", Rule: "Abaixo do primeiro quartil (p25) da casa."},
	}
	return BenchmarkMethod{
		Version:   BenchmarkMethodVersion,
		Summary:   "Cada número do mandato é comparado com o dos colegas do mesmo cargo e da mesma casa no mesmo ano. A classificação diz onde o número fica entre os colegas; o número e a mediana da casa aparecem sempre ao lado.",
		Groups:    "Deputados federais entre si (Câmara), senadores entre si (Senado) e deputados estaduais ou distritais entre os colegas da mesma assembleia (por UF). Entram só os que estão no exercício do mandato.",
		Year:      "O ano mais recente com dado publicado para ao menos 5 colegas. No ano corrente, conta até o dia da carga.",
		Quartiles: "p25, mediana e p75 calculados por interpolação linear sobre os valores dos colegas com dado publicado. Quem não tem dado fica fora da conta; dado ausente nunca vira zero.",
		MinPeers:  BenchmarkMinPeers,
		Metrics: []BenchmarkMetricRule{
			{Key: MetricPresence, Label: "Presença", Unit: "percent", Direction: "higherIsBetter", Text: "Sessões com presença registrada sobre as sessões em que a pessoa podia votar, no ano.",
				Bands: directional("Acima do terceiro quartil (p75) da casa.", "Abaixo do primeiro quartil (p25) da casa.")},
			{Key: MetricQuota, Label: "Gasto da cota", Unit: "centsPerMonth", Direction: "lowerIsBetter", Text: "Gasto da cota parlamentar no ano dividido pelos meses de mandato no ano, para não punir quem entrou depois.",
				Bands: directional("Abaixo do primeiro quartil (p25) da casa.", "Acima do terceiro quartil (p75) da casa.")},
			{Key: MetricProposals, Label: "Propostas de autoria", Unit: "count", Direction: "none", Text: "Proposições apresentadas no ano. Mais propostas não quer dizer propostas melhores, por isso não há cor de bom ou ruim.", Bands: activity},
			{Key: MetricSpeeches, Label: "Discursos", Unit: "count", Direction: "none", Text: "Discursos registrados no ano. Mais discursos não quer dizer atuação melhor, por isso não há cor de bom ou ruim.", Bands: activity},
		},
		Limits: []string{
			"Presença registrada não mede o trabalho em comissões nem fora do plenário.",
			"Gasto da cota abaixo da média não quer dizer gasto bem feito; a cota tem teto diferente por UF.",
			"Projetos e votos nunca são chamados de bons ou ruins: isso é opinião.",
			fmt.Sprintf("Com menos de %d colegas com dado, a métrica fica sem classificação.", BenchmarkMinPeers),
		},
		Sources: sources,
	}
}
