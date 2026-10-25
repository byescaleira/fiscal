package ingest

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/anp"
	"liveresults/internal/sources/ibge"
	"liveresults/internal/sources/sidra"
)

const (
	indicatorsStoreFile = "indicators.json"
	minSeriesPoints     = 100
	sidraIndexStart     = "1995-01"
)

type indicatorStore struct {
	ANP   []publicdata.RawIndicator `json:"anp"`
	SIDRA []publicdata.RawIndicator `json:"sidra"`
}

type fuelSpec struct {
	product string
	id      string
	name    string
	unit    string
}

var fuels = []fuelSpec{
	{anp.Gasoline, "gasolina", "Gasolina comum", "R$/l"},
	{anp.Ethanol, "etanol", "Etanol hidratado", "R$/l"},
	{anp.DieselS10, "diesel-s10", "Óleo diesel S10", "R$/l"},
	{anp.LPG, "glp", "Gás de cozinha (GLP)", "R$/13 kg"},
}

type ipcaSpec struct {
	category string
	id       string
	name     string
}

var ipcaItems = []ipcaSpec{
	{sidra.General, "ipca", "IPCA (inflação oficial)"},
	{sidra.FoodAtHome, "ipca-alimentacao-domicilio", "IPCA · Alimentação no domicílio"},
	{sidra.Electricity, "ipca-energia-eletrica", "IPCA · Energia elétrica residencial"},
	{sidra.Rent, "ipca-aluguel", "IPCA · Aluguel residencial"},
	{sidra.Gasoline, "ipca-gasolina", "IPCA · Gasolina"},
}

func (in *Ingest) loadIndicators(ctx context.Context, rep *Report, srcs *sourceSet) []publicdata.RawIndicator {
	path := filepath.Join(in.cfg.DataDir, indicatorsStoreFile)
	var prev indicatorStore
	if data, err := os.ReadFile(path); err == nil {
		json.Unmarshal(data, &prev)
	}
	next := prev
	changed := false
	if in.cfg.Enabled("anp") {
		list, err := in.loadANP(ctx)
		if err != nil {
			in.warn(rep, "anp: %v (kept the prices from the last load)", err)
		} else {
			next.ANP, changed = list, true
		}
		if len(next.ANP) > 0 {
			srcs.add("anp", anp.Name, anp.SiteURL, next.ANP)
		}
	}
	if in.cfg.Enabled("sidra") {
		list, err := in.loadSIDRA(ctx)
		if err != nil {
			in.warn(rep, "sidra: %v (kept the IPCA from the last load)", err)
		} else {
			next.SIDRA, changed = list, true
		}
		if len(next.SIDRA) > 0 {
			srcs.add("sidra", sidra.Name, sidra.SiteURL, next.SIDRA)
		}
	}
	if changed {
		if err := writeIndicatorStore(path, next); err != nil {
			in.warn(rep, "indicators store: %v", err)
		}
	}
	var out []publicdata.RawIndicator
	if in.cfg.Enabled("anp") {
		out = append(out, next.ANP...)
	}
	if in.cfg.Enabled("sidra") {
		out = append(out, next.SIDRA...)
	}
	return out
}

func writeIndicatorStore(path string, s indicatorStore) error {
	data, err := json.Marshal(s)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (in *Ingest) loadANP(ctx context.Context) ([]publicdata.RawIndicator, error) {
	ufs := map[string]string{}
	for _, s := range ibge.States {
		ufs[anp.Norm(s.Name)] = strings.ToLower(s.UF)
	}
	values := map[string]map[string]map[string]float64{}
	for _, url := range anp.Files {
		c, err := in.get.Cache(ctx, url, 64<<20)
		if err != nil {
			return nil, err
		}
		rows, err := parseANPFile(c.Path)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", url, err)
		}
		for _, r := range rows {
			scope := publicdata.ScopeBrazil
			if r.State != "" {
				uf, ok := ufs[r.State]
				if !ok {
					continue
				}
				scope = uf
			}
			if values[r.Product] == nil {
				values[r.Product] = map[string]map[string]float64{}
			}
			if values[r.Product][scope] == nil {
				values[r.Product][scope] = map[string]float64{}
			}
			values[r.Product][scope][r.Month] = r.Price
		}
	}
	var out []publicdata.RawIndicator
	for _, f := range fuels {
		ind := publicdata.RawIndicator{ID: f.id, Name: f.name, Unit: f.unit, Kind: publicdata.IndicatorPrice, Source: "anp", Areas: map[string]publicdata.RawArea{}}
		for scope, months := range values[f.product] {
			name := "Brasil"
			if scope != publicdata.ScopeBrazil {
				name = ibge.StateName(strings.ToUpper(scope))
			}
			ind.Areas[scope] = publicdata.RawArea{Name: name, Points: monthPoints(months, 3)}
		}
		if len(ind.Areas[publicdata.ScopeBrazil].Points) < minSeriesPoints {
			return nil, fmt.Errorf("%s: fewer than %d months for Brazil; refusing a partial series", f.id, minSeriesPoints)
		}
		if len(ind.Areas) < 28 {
			return nil, fmt.Errorf("%s: %d areas, expected Brazil and the 27 states", f.id, len(ind.Areas))
		}
		out = append(out, ind)
	}
	return out, nil
}

func parseANPFile(path string) ([]anp.Row, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return nil, err
	}
	return anp.Parse(f, st.Size())
}

func (in *Ingest) loadSIDRA(ctx context.Context) ([]publicdata.RawIndicator, error) {
	monthly := map[string]map[string]map[string]*float64{}
	for _, t := range sidra.MonthlyTables {
		rows, err := in.sidraRows(ctx, sidra.MonthlyURL(t))
		if err != nil {
			return nil, fmt.Errorf("table %s: %w", t, err)
		}
		for _, r := range rows {
			scope, ok := sidra.Areas[r.Area]
			if !ok {
				continue
			}
			if monthly[r.Category] == nil {
				monthly[r.Category] = map[string]map[string]*float64{}
			}
			if monthly[r.Category][scope] == nil {
				monthly[r.Category][scope] = map[string]*float64{}
			}
			monthly[r.Category][scope][r.Month] = r.Value
		}
	}
	idxRows, err := in.sidraRows(ctx, sidra.IndexURL())
	if err != nil {
		return nil, fmt.Errorf("table %s: %w", sidra.TableIndex, err)
	}
	official := map[string]float64{}
	for _, r := range idxRows {
		if r.Value != nil && r.Month >= sidraIndexStart {
			official[r.Month] = *r.Value
		}
	}
	var out []publicdata.RawIndicator
	for _, it := range ipcaItems {
		ind := publicdata.RawIndicator{ID: it.id, Name: it.name, Unit: "índice", Kind: publicdata.IndicatorIndex, Source: "sidra", Areas: map[string]publicdata.RawArea{}}
		for scope, months := range monthly[it.category] {
			pts := chain(months)
			if len(pts) == 0 {
				continue
			}
			ind.Areas[scope] = publicdata.RawArea{Name: sidra.AreaNames[scope], Points: pts}
		}
		if it.category == sidra.General && len(official) > 0 {
			ind.Areas[publicdata.ScopeBrazil] = publicdata.RawArea{Name: sidra.AreaNames[publicdata.ScopeBrazil], Points: monthPoints(official, 2)}
		}
		if len(ind.Areas[publicdata.ScopeBrazil].Points) < minSeriesPoints {
			return nil, fmt.Errorf("%s: fewer than %d months for Brazil; refusing a partial series", it.id, minSeriesPoints)
		}
		out = append(out, ind)
	}
	return out, nil
}

func (in *Ingest) sidraRows(ctx context.Context, url string) ([]sidra.Row, error) {
	c, err := in.get.Cache(ctx, url, 32<<20)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(c.Path)
	if err != nil {
		return nil, err
	}
	return sidra.Parse(data)
}

func monthPoints(months map[string]float64, places int) []publicdata.Point {
	keys := make([]string, 0, len(months))
	for m := range months {
		keys = append(keys, m)
	}
	sort.Strings(keys)
	out := make([]publicdata.Point, 0, len(keys))
	p := math.Pow(10, float64(places))
	for _, m := range keys {
		out = append(out, publicdata.Point{Date: m + "-01", Value: math.Round(months[m]*p) / p})
	}
	return out
}

func chain(months map[string]*float64) []publicdata.Point {
	keys := make([]string, 0, len(months))
	for m := range months {
		keys = append(keys, m)
	}
	sort.Strings(keys)
	start := 0
	for i, m := range keys {
		if months[m] == nil || (i > 0 && nextMonth(keys[i-1]) != m) {
			start = i
			if months[m] == nil {
				start = i + 1
			}
		}
	}
	if start >= len(keys) {
		return nil
	}
	base, err := time.Parse("2006-01", keys[start])
	if err != nil {
		return nil
	}
	out := []publicdata.Point{{Date: base.AddDate(0, -1, 0).Format("2006-01-02"), Value: 100}}
	level := 100.0
	for _, m := range keys[start:] {
		level *= 1 + *months[m]/100
		out = append(out, publicdata.Point{Date: m + "-01", Value: math.Round(level*1000) / 1000})
	}
	return out
}

func nextMonth(m string) string {
	t, err := time.Parse("2006-01", m)
	if err != nil {
		return ""
	}
	return t.AddDate(0, 1, 0).Format("2006-01")
}
