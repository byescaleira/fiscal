package ingest

import (
	"archive/zip"
	"bytes"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/fetch"
	"liveresults/internal/sources/tse"
)

type zipFetcher struct {
	fixtureFetcher
	client *fetch.Client
	base   string
	down   bool
}

func (z *zipFetcher) Open(ctx context.Context, raw string) (*fetch.Remote, error) {
	if z.down {
		return nil, errors.New("tse is down")
	}
	return z.client.Open(ctx, z.base+"/"+filepath.Base(raw))
}

func tseZips(t *testing.T) *zipFetcher {
	t.Helper()
	dir := filepath.Join("..", "sources", "tse", "testdata")
	build := func(prefix string) []byte {
		var buf bytes.Buffer
		zw := zip.NewWriter(&buf)
		for _, uf := range []string{"AC", "AP"} {
			name := prefix + "_2024_" + uf + ".csv"
			data, err := os.ReadFile(filepath.Join(dir, name))
			if err != nil {
				t.Fatal(err)
			}
			w, _ := zw.Create(name)
			w.Write(data)
		}
		zw.Close()
		return buf.Bytes()
	}
	files := map[string][]byte{
		"consulta_cand_2024.zip":             build("consulta_cand"),
		"bem_candidato_2024.zip":             build("bem_candidato"),
		"votacao_candidato_munzona_2024.zip": build("votacao_candidato_munzona"),
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		data, ok := files[filepath.Base(r.URL.Path)]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("ETag", `"v1"`)
		http.ServeContent(w, r, "f.zip", time.Time{}, bytes.NewReader(data))
	}))
	t.Cleanup(srv.Close)
	c := fetch.New("", 5*time.Second)
	c.Gap = 0
	return &zipFetcher{fixtureFetcher: fixtureFetcher{t: t}, client: c, base: srv.URL}
}

var testMunicipalities = []publicdata.PlaceEntry{
	{Code: "1200013", Name: "Acrelândia", UF: "ac"},
	{Code: "1200708", Name: "Xapuri", UF: "ac"},
	{Code: "1200401", Name: "Rio Branco", UF: "ac"},
	{Code: "1600501", Name: "Oiapoque", UF: "ap"},
	{Code: "5300108", Name: "Brasília", UF: "df"},
}

func TestLoadCitiesReadsTheElectedAndReportsTheGaps(t *testing.T) {
	now := time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)
	get := tseZips(t)
	in := testIngest(t, Config{}, get, now)
	var rep Report
	cities := in.loadCities(context.Background(), &rep, testMunicipalities, newSourceSet(in.stamp()))
	if len(cities) != 5 || rep.Cities != 5 || rep.CityPeople != 22+13 {
		t.Fatalf("cities = %d report = %+v", len(cities), rep)
	}
	by := map[string]publicdata.City{}
	for _, c := range cities {
		by[c.Code] = c
	}
	oiapoque := by["1600501"]
	var hall []string
	for _, p := range oiapoque.Officials {
		if r := p.Primary(); r.Office != publicdata.OfficeCityCouncilor {
			hall = append(hall, r.Office+":"+p.Name+":"+r.MandateStart)
		}
	}
	if strings.Join(hall, ",") != "mayor:Inacio:,viceMayor:Oscar Gislael:" {
		t.Fatalf("oiapoque hall = %v", hall)
	}
	var mayor *publicdata.Person
	for _, p := range by["1200708"].Officials {
		if p.Primary().Office == publicdata.OfficeMayor {
			mayor = p
		}
	}
	if mayor == nil || mayor.Name != "Maxsuel Maia" || mayor.Primary().Party != "PP" || mayor.Primary().MandateStart != "2025-01-01" || mayor.Primary().MandateEnd != "2028-12-31" {
		t.Fatalf("xapuri mayor = %+v", mayor)
	}
	c := mayor.Candidacies[0]
	if c.Votes == nil || *c.Votes <= 0 || !c.AssetsLoaded || c.Place != "Xapuri (AC)" || !strings.HasPrefix(mayor.Keys[0], "titulo:") {
		t.Fatalf("candidacy = %+v keys = %v", c, mayor.Keys)
	}
	if by["1200401"].Unit != "" || by["5300108"].Unit != "" || len(by["1200401"].Officials) != 0 {
		t.Fatalf("cities without TSE data = %+v %+v", by["1200401"], by["5300108"])
	}
	var review struct {
		Matched int                     `json:"matched"`
		Reviews []publicdata.UnitReview `json:"reviews"`
	}
	readJSON(t, filepath.Join(in.cfg.DataDir, "cities-review.json"), &review)
	if review.Matched != 3 || len(review.Reviews) != 2 {
		t.Fatalf("review = %+v", review)
	}
	data, err := os.ReadFile(filepath.Join(in.cfg.DataDir, "cache", "tse", "consulta_cand-2024-all.json"))
	if err != nil || bytes.Contains(data, []byte(`"000000000001"`)) {
		t.Fatalf("the cache must not keep the voter title in clear: %v", err)
	}
	get.down = true
	var again Report
	stale := in.loadCities(context.Background(), &again, testMunicipalities, newSourceSet(in.stamp()))
	if len(stale) != 5 || again.CityPeople != rep.CityPeople || len(again.Warnings) == 0 {
		t.Fatalf("stale = %d report = %+v", len(stale), again)
	}
}

func TestLoadCitiesFailsSoftWithoutAnyData(t *testing.T) {
	now := time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)
	get := tseZips(t)
	get.down = true
	in := testIngest(t, Config{}, get, now)
	var rep Report
	if cities := in.loadCities(context.Background(), &rep, testMunicipalities, newSourceSet(in.stamp())); cities != nil || len(rep.Warnings) != 1 {
		t.Fatalf("cities = %v warnings = %v", cities, rep.Warnings)
	}
}

func TestCityYearDefaultsToTheLastMunicipalElection(t *testing.T) {
	if (Config{}).cityYear() != 2024 || (Config{CityYear: 2020}).cityYear() != 2020 || !tse.MunicipalYear(2024) {
		t.Fatal("city year")
	}
	if got := (Config{UFs: []string{"br", "ac"}}).cityUFs(); len(got) != 1 || got[0] != "ac" {
		t.Fatalf("city ufs = %v", got)
	}
}
