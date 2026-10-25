package publicdata

import (
	"math"
	"sort"
	"strconv"
	"time"
)

const (
	IndicatorPrice = "price"
	IndicatorIndex = "index"
	ScopeBrazil    = "br"
	ScopeState     = "uf"
)

type Point struct {
	Date  string  `json:"date"`
	Value float64 `json:"value"`
}

type RawIndicator struct {
	ID     string
	Name   string
	Unit   string
	Kind   string
	Source string
	Areas  map[string]RawArea
}

type RawArea struct {
	Name   string
	Points []Point
}

type IndicatorArea struct {
	Scope  string  `json:"scope"`
	Name   string  `json:"name"`
	Series []Point `json:"series"`
}

type IndicatorFile struct {
	ID      string          `json:"id"`
	Name    string          `json:"name"`
	Unit    string          `json:"unit"`
	Kind    string          `json:"kind"`
	Scope   string          `json:"scope"`
	Areas   []IndicatorArea `json:"areas"`
	Sources []Source        `json:"sources"`
}

type IndicatorSummary struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Unit       string   `json:"unit"`
	Kind       string   `json:"kind"`
	Scope      string   `json:"scope"`
	Scopes     []string `json:"scopes"`
	Start      *string  `json:"start"`
	Latest     *float64 `json:"latest"`
	LatestDate *string  `json:"latestDate"`
	Change12m  *float64 `json:"change12m"`
}

type IndicatorIndexFile struct {
	Items   []IndicatorSummary `json:"items"`
	Sources []Source           `json:"sources"`
}

type ContextIndicator struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Unit         string   `json:"unit"`
	Kind         string   `json:"kind"`
	Scope        string   `json:"scope"`
	Area         string   `json:"area"`
	AtStart      *float64 `json:"atStart"`
	AtStartDate  *string  `json:"atStartDate"`
	Latest       *float64 `json:"latest"`
	LatestDate   *string  `json:"latestDate"`
	Months       int      `json:"months"`
	ChangeDuring *float64 `json:"changeDuring"`
	BeforeDate   *string  `json:"beforeDate"`
	ChangeBefore *float64 `json:"changeBefore"`
	Series       []Point  `json:"series"`
}

type PersonContextFile struct {
	MandateStart string             `json:"mandateStart"`
	Scope        string             `json:"scope"`
	Indicators   []ContextIndicator `json:"indicators"`
	Sources      []Source           `json:"sources"`
}

func (r RawIndicator) scopes() []string {
	out := make([]string, 0, len(r.Areas))
	for s := range r.Areas {
		out = append(out, s)
	}
	sort.Slice(out, func(i, j int) bool {
		if (out[i] == ScopeBrazil) != (out[j] == ScopeBrazil) {
			return out[i] == ScopeBrazil
		}
		return out[i] < out[j]
	})
	return out
}

func (r RawIndicator) scope() string {
	for s := range r.Areas {
		if s != ScopeBrazil {
			return ScopeState
		}
	}
	return ScopeBrazil
}

func (b *builder) indicators() {
	if len(b.ds.Indicators) == 0 {
		return
	}
	var items []IndicatorSummary
	ids := map[string]bool{}
	for _, ind := range b.ds.Indicators {
		ids[ind.Source] = true
		file := IndicatorFile{ID: ind.ID, Name: ind.Name, Unit: ind.Unit, Kind: ind.Kind, Scope: ind.scope(), Sources: b.sources(ind.Source)}
		for _, s := range ind.scopes() {
			a := ind.Areas[s]
			file.Areas = append(file.Areas, IndicatorArea{Scope: s, Name: a.Name, Series: nonNilPoints(a.Points)})
		}
		b.add("indicators/"+ind.ID+".json", file)
		sum := IndicatorSummary{ID: ind.ID, Name: ind.Name, Unit: ind.Unit, Kind: ind.Kind, Scope: ind.scope(), Scopes: ind.scopes()}
		if br, ok := ind.Areas[ScopeBrazil]; ok && len(br.Points) > 0 {
			first, last := br.Points[0], br.Points[len(br.Points)-1]
			sum.Start, sum.Latest, sum.LatestDate = ptr(first.Date), ptr(last.Value), ptr(last.Date)
			if prev, ok := valueAt(br.Points, addMonths(last.Date, -12)); ok && prev > 0 {
				sum.Change12m = ptr(round(last.Value/prev-1, 6))
			}
		}
		items = append(items, sum)
	}
	srcIDs := make([]string, 0, len(ids))
	for id := range ids {
		srcIDs = append(srcIDs, id)
	}
	sort.Strings(srcIDs)
	b.add("indicators/index.json", IndicatorIndexFile{Items: items, Sources: b.sources(srcIDs...)})
}

func nonNilPoints(p []Point) []Point {
	if p == nil {
		return []Point{}
	}
	return p
}

func (b *builder) context(p *Person, slug string) {
	if len(b.ds.Indicators) == 0 {
		return
	}
	role := p.Primary()
	start := ContextStart(p)
	if start == "" {
		return
	}
	ctx, ok := BuildContext(b.ds.Indicators, start, role.UF)
	if !ok {
		return
	}
	ids := map[string]bool{}
	for _, ind := range b.ds.Indicators {
		ids[ind.Source] = true
	}
	srcIDs := make([]string, 0, len(ids))
	for id := range ids {
		srcIDs = append(srcIDs, id)
	}
	sort.Strings(srcIDs)
	ctx.Sources = b.sources(srcIDs...)
	b.add("people/"+slug+"/context.json", ctx)
}

func ContextStart(p *Person) string {
	role := p.Primary()
	if role.Status == StatusElected {
		return ""
	}
	if role.MandateStart != "" {
		return role.MandateStart
	}
	year := 0
	for _, c := range p.Candidacies {
		if c.Elected && c.Office == role.Office && c.Year > year {
			year = c.Year
		}
	}
	if year == 0 {
		return ""
	}
	switch role.Office {
	case OfficeStateDeputy:
		return strconv.Itoa(year+1) + "-02-01"
	}
	start, _ := MandateFor(role.Office, year)
	return start
}

func BuildContext(indicators []RawIndicator, mandateStart, uf string) (PersonContextFile, bool) {
	if len(mandateStart) < 7 {
		return PersonContextFile{}, false
	}
	scope := uf
	if scope == "" {
		scope = ScopeBrazil
	}
	out := PersonContextFile{MandateStart: mandateStart[:10], Scope: scope, Indicators: []ContextIndicator{}}
	ref := addMonths(mandateStart[:7]+"-01", -1)
	for _, ind := range indicators {
		area, s := ind.Areas[scope], scope
		if len(area.Points) == 0 {
			area, s = ind.Areas[ScopeBrazil], ScopeBrazil
		}
		if len(area.Points) == 0 {
			continue
		}
		last := area.Points[len(area.Points)-1]
		if last.Date <= ref {
			continue
		}
		ci := ContextIndicator{ID: ind.ID, Name: ind.Name, Unit: ind.Unit, Kind: ind.Kind, Scope: s, Area: area.Name, Latest: ptr(last.Value), LatestDate: ptr(last.Date)}
		n := monthsBetween(ref, last.Date)
		ci.Months = n
		from := addMonths(ref, -n)
		if v, ok := valueAt(area.Points, ref); ok {
			ci.AtStart, ci.AtStartDate = ptr(v), ptr(ref)
			if v > 0 {
				ci.ChangeDuring = ptr(round(last.Value/v-1, 6))
			}
			if before, ok := valueAt(area.Points, from); ok && before > 0 {
				ci.BeforeDate = ptr(from)
				ci.ChangeBefore = ptr(round(v/before-1, 6))
			}
		}
		ci.Series = []Point{}
		for _, pt := range area.Points {
			if pt.Date >= from {
				ci.Series = append(ci.Series, pt)
			}
		}
		out.Indicators = append(out.Indicators, ci)
	}
	return out, len(out.Indicators) > 0
}

func valueAt(points []Point, date string) (float64, bool) {
	i := sort.Search(len(points), func(i int) bool { return points[i].Date >= date })
	if i < len(points) && points[i].Date == date {
		return points[i].Value, true
	}
	return 0, false
}

func parseMonth(date string) (time.Time, bool) {
	if len(date) < 7 {
		return time.Time{}, false
	}
	t, err := time.Parse("2006-01", date[:7])
	return t, err == nil
}

func addMonths(date string, n int) string {
	t, ok := parseMonth(date)
	if !ok {
		return ""
	}
	return t.AddDate(0, n, 0).Format("2006-01-02")
}

func monthsBetween(a, b string) int {
	ta, ok1 := parseMonth(a)
	tb, ok2 := parseMonth(b)
	if !ok1 || !ok2 {
		return 0
	}
	return (tb.Year()-ta.Year())*12 + int(tb.Month()) - int(ta.Month())
}

func round(v float64, places int) float64 {
	p := math.Pow(10, float64(places))
	return math.Round(v*p) / p
}
