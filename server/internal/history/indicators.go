package history

import (
	"math"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	IpeaName    = "Ipeadata (Ipea), séries do IBGE e da FGV"
	IpeaSiteURL = "http://www.ipeadata.gov.br"
	IpeaAPI     = "https://www.ipeadata.gov.br/api/odata4/ValoresSerie(SERCODIGO='%s')"
)

const (
	IndicatorGDP          = "pib"
	IndicatorIPCA         = "ipca"
	IndicatorIGPDI        = "igp-di"
	IndicatorUnemployment = "desocupacao"
)

type SeriesSpec struct {
	ID      string
	Code    string
	Name    string
	Unit    string
	Origin  string
	Note    string
	Monthly bool
}

var Series = []SeriesSpec{
	{ID: IndicatorGDP, Code: "SCN10_PIBG10", Name: "PIB, variação real anual", Unit: "% ao ano", Origin: "IBGE, Sistema de Contas Nacionais (via Ipeadata, série SCN10_PIBG10)", Note: "Média simples das taxas anuais do período."},
	{ID: IndicatorIPCA, Code: "PRECOS_IPCAG", Name: "Inflação pelo IPCA", Unit: "% ao ano", Origin: "IBGE, Sistema Nacional de Índices de Preços ao Consumidor (via Ipeadata, série PRECOS_IPCAG)", Note: "O IPCA começa em 1980."},
	{ID: IndicatorIGPDI, Code: "IGP_IGPDIG", Name: "Inflação pelo IGP-DI", Unit: "% ao ano", Origin: "Fundação Getulio Vargas, IGP-DI (via Ipeadata, série IGP_IGPDIG)", Note: "O IGP-DI começa em 1945 e mede preços no atacado, ao consumidor e na construção."},
	{ID: IndicatorUnemployment, Code: "PNADC12_TDESOC12", Name: "Taxa de desocupação", Unit: "%", Origin: "IBGE, PNAD Contínua (via Ipeadata, série PNADC12_TDESOC12)", Note: "Média dos quatro trimestres do ano. A PNAD Contínua começa em 2012; as pesquisas anteriores usam outro método e não entram na comparação.", Monthly: true},
}

type Point struct {
	Year  int     `json:"year"`
	Value float64 `json:"value"`
}

type IpeaValue struct {
	Date  string   `json:"VALDATA"`
	Value *float64 `json:"VALVALOR"`
}

type IpeaResponse struct {
	Value []IpeaValue `json:"value"`
}

func AnnualPoints(spec SeriesSpec, values []IpeaValue) []Point {
	if !spec.Monthly {
		var out []Point
		for _, v := range values {
			y, _, ok := yearMonth(v.Date)
			if !ok || v.Value == nil {
				continue
			}
			out = append(out, Point{Year: y, Value: round2(*v.Value)})
		}
		sort.Slice(out, func(i, j int) bool { return out[i].Year < out[j].Year })
		return out
	}
	quarters := map[int]map[int]float64{}
	for _, v := range values {
		y, m, ok := yearMonth(v.Date)
		if !ok || v.Value == nil || m%3 != 0 {
			continue
		}
		if quarters[y] == nil {
			quarters[y] = map[int]float64{}
		}
		quarters[y][m] = *v.Value
	}
	var out []Point
	for y, q := range quarters {
		if len(q) != 4 {
			continue
		}
		sum := 0.0
		for _, v := range q {
			sum += v
		}
		out = append(out, Point{Year: y, Value: round2(sum / 4)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Year < out[j].Year })
	return out
}

func yearMonth(s string) (int, int, bool) {
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t.Year(), int(t.Month()), true
	}
	if len(s) >= 7 {
		y, err1 := strconv.Atoi(s[:4])
		m, err2 := strconv.Atoi(strings.TrimPrefix(s[5:7], "0"))
		if err1 == nil && err2 == nil {
			return y, m, true
		}
	}
	return 0, 0, false
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

type PeriodIndicator struct {
	ID      string   `json:"id"`
	Name    string   `json:"name"`
	Unit    string   `json:"unit"`
	Source  string   `json:"source"`
	Note    string   `json:"note"`
	From    int      `json:"from"`
	To      int      `json:"to"`
	Points  []Point  `json:"points"`
	Average *float64 `json:"average"`
	Min     *Point   `json:"min"`
	Max     *Point   `json:"max"`
}

func Slice(spec SeriesSpec, points []Point, from, to int) *PeriodIndicator {
	var in []Point
	for _, p := range points {
		if p.Year >= from && p.Year <= to {
			in = append(in, p)
		}
	}
	if len(in) == 0 {
		return nil
	}
	ind := &PeriodIndicator{ID: spec.ID, Name: spec.Name, Unit: spec.Unit, Source: spec.Origin, Note: spec.Note, From: in[0].Year, To: in[len(in)-1].Year, Points: in}
	lo, hi := in[0], in[0]
	sum := 0.0
	for _, p := range in {
		sum += p.Value
		if p.Value < lo.Value {
			lo = p
		}
		if p.Value > hi.Value {
			hi = p
		}
	}
	ind.Min, ind.Max = &lo, &hi
	if spec.ID == IndicatorGDP || spec.ID == IndicatorUnemployment {
		avg := round2(sum / float64(len(in)))
		ind.Average = &avg
	}
	return ind
}
