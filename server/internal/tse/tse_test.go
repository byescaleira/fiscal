package tse

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func definition(t *testing.T, id string) Definition {
	t.Helper()
	for _, d := range Definitions() {
		if d.ID == id {
			return d
		}
	}
	t.Fatalf("unknown definition %s", id)
	return Definition{}
}

func TestDefinitionsOrderAndPaths(t *testing.T) {
	defs := Definitions()
	want := []string{"presidente-br", "governador-ac", "governador-am", "governador-df", "governador-es", "governador-rn", "governador-to"}
	if len(defs) != len(want) {
		t.Fatalf("got %d definitions", len(defs))
	}
	for i, d := range defs {
		if d.ID != want[i] {
			t.Fatalf("definition %d = %s, want %s", i, d.ID, want[i])
		}
	}
	if defs[0].Path != "6258/dados/br/br-c0001-e006258-u.json" || defs[1].Path != "6260/dados/ac/ac-c0003-e006260-u.json" {
		t.Fatalf("unexpected paths %s %s", defs[0].Path, defs[1].Path)
	}
}

func TestParsePresidentFixture(t *testing.T) {
	data, err := os.ReadFile("testdata/br-c0001-e006258-u.json")
	if err != nil {
		t.Fatal(err)
	}
	r, err := Parse(definition(t, "presidente-br"), data)
	if err != nil {
		t.Fatal(err)
	}
	if r.ID != "presidente-br" || r.Office != "president" || r.UF != "br" || r.Round != 2 {
		t.Fatalf("identity %+v", r)
	}
	if r.Sections.Total != 499248 || r.Sections.Counted != 0 || r.Sections.Percent != 0 {
		t.Fatalf("sections %+v", r.Sections)
	}
	if r.Electorate != 158745502 || r.Final {
		t.Fatalf("electorate %d final %v", r.Electorate, r.Final)
	}
	if r.SourceGeneratedAt != "2026-10-24T19:19:13-03:00" {
		t.Fatalf("generated %s", r.SourceGeneratedAt)
	}
	if len(r.Candidates) != 2 {
		t.Fatalf("candidates %+v", r.Candidates)
	}
	if r.Candidates[0].Number != "13" || r.Candidates[0].Name != "Lula" || r.Candidates[0].Party != "PT" {
		t.Fatalf("tie must sort by number: %+v", r.Candidates)
	}
	if r.Candidates[1].Name != "Flavio Bolsonaro" || r.Candidates[1].Party != "PL" {
		t.Fatalf("second %+v", r.Candidates[1])
	}
}

func TestParseGovernorFixture(t *testing.T) {
	data, err := os.ReadFile("testdata/ac-c0003-e006260-u.json")
	if err != nil {
		t.Fatal(err)
	}
	r, err := Parse(definition(t, "governador-ac"), data)
	if err != nil {
		t.Fatal(err)
	}
	if r.Office != "governor" || r.UF != "ac" || r.Sections.Total != 2270 || r.Electorate != 613336 {
		t.Fatalf("race %+v", r)
	}
	if r.Candidates[0].Number != "10" || r.Candidates[0].Name != "Alan Rick" || r.Candidates[1].Name != "Mailza Assis" {
		t.Fatalf("candidates %+v", r.Candidates)
	}
}

func TestParseRejectsWrongFile(t *testing.T) {
	data, _ := os.ReadFile("testdata/ac-c0003-e006260-u.json")
	if _, err := Parse(definition(t, "presidente-br"), data); err == nil {
		t.Fatal("expected error for governor file parsed as president")
	}
}

const countedFixture = `{"ele":"6258","t":"2","dg":"25/10/2026","hg":"20:41:07","tf":"s","carg":[{"cd":"1","agr":[
{"par":[{"sg":"PL","cand":[{"n":"22","nmu":"FLAVIO BOLSONARO","e":"n","vap":"60000000","pvap":"49,88"}]}]},
{"par":[{"sg":"PT","cand":[{"n":"13","nmu":"JOSÉ DA SILVA DOS SANTOS E SOUZA","e":"s","vap":"60300123","pvap":"50,12"}]}]}]}],
"s":{"ts":"499248","st":"498001","pst":"99,75"},
"e":{"te":"158745502","c":"125000000","a":"33745502"},
"v":{"vv":"120300123","vb":"1500000","tvn":"3199877","tv":"125000000"}}`

func TestParseCountedValues(t *testing.T) {
	r, err := Parse(definition(t, "presidente-br"), []byte(countedFixture))
	if err != nil {
		t.Fatal(err)
	}
	if !r.Final {
		t.Fatal("expected final")
	}
	if r.Sections.Counted != 498001 || r.Sections.Percent != 99.75 {
		t.Fatalf("sections %+v", r.Sections)
	}
	if r.Turnout != 125000000 || r.Votes != (Votes{Valid: 120300123, Blank: 1500000, Null: 3199877, Total: 125000000}) {
		t.Fatalf("votes %+v turnout %d", r.Votes, r.Turnout)
	}
	first := r.Candidates[0]
	if first.Number != "13" || first.Votes != 60300123 || first.Percent != 50.12 || !first.Elected {
		t.Fatalf("first %+v", first)
	}
	if first.Name != "José da Silva dos Santos e Souza" {
		t.Fatalf("name %q", first.Name)
	}
	if r.Candidates[1].Percent != 49.88 || r.Candidates[1].Elected {
		t.Fatalf("second %+v", r.Candidates[1])
	}
	if r.SourceGeneratedAt != "2026-10-25T20:41:07-03:00" {
		t.Fatalf("generated %s", r.SourceGeneratedAt)
	}
}

func TestParseFinalByElectedFlag(t *testing.T) {
	raw := strings.Replace(countedFixture, `"tf":"s"`, `"tf":"n"`, 1)
	r, err := Parse(definition(t, "presidente-br"), []byte(raw))
	if err != nil {
		t.Fatal(err)
	}
	if !r.Final {
		t.Fatal("candidate e=s must make the race final")
	}
	raw = strings.Replace(raw, `"e":"s"`, `"e":"n"`, 1)
	r, _ = Parse(definition(t, "presidente-br"), []byte(raw))
	if r.Final {
		t.Fatal("expected not final")
	}
}

func TestParseRejectsBadNumber(t *testing.T) {
	raw := strings.Replace(countedFixture, `"vap":"60000000"`, `"vap":"6x"`, 1)
	if _, err := Parse(definition(t, "presidente-br"), []byte(raw)); err == nil {
		t.Fatal("expected error")
	}
}

func TestTitleName(t *testing.T) {
	cases := map[string]string{
		"LULA":                        "Lula",
		"DA SILVA":                    "Da Silva",
		"PROFESSORA MARIA DO CARMO":   "Professora Maria do Carmo",
		"CELINA LEÃO":                 "Celina Leão",
		"VICENTINHO JÚNIOR":           "Vicentinho Júnior",
		"CADU DE LULA":                "Cadu de Lula",
		"  ÉRICA  DAS  NEVES E LIMA ": "Érica das Neves e Lima",
	}
	for in, want := range cases {
		if got := TitleName(in); got != want {
			t.Errorf("TitleName(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestHTTPSourceUsesETag(t *testing.T) {
	data, _ := os.ReadFile("testdata/br-c0001-e006258-u.json")
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.URL.Path != "/oficial/ele2026/6258/dados/br/br-c0001-e006258-u.json" {
			http.NotFound(w, r)
			return
		}
		if r.Header.Get("User-Agent") != UserAgent {
			t.Errorf("user agent %q", r.Header.Get("User-Agent"))
		}
		if r.Header.Get("If-None-Match") == `"abc"` {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", `"abc"`)
		w.Write(data)
	}))
	defer srv.Close()
	src := NewHTTPSource(srv.URL+"/oficial/ele2026/", nil)
	d := definition(t, "presidente-br")
	r, modified, err := src.Fetch(context.Background(), d)
	if err != nil || !modified || r.Sections.Total != 499248 {
		t.Fatalf("first fetch %v %v %+v", err, modified, r.Sections)
	}
	_, modified, err = src.Fetch(context.Background(), d)
	if err != nil || modified {
		t.Fatalf("second fetch must be not modified: %v %v", err, modified)
	}
	if _, _, err := src.Fetch(context.Background(), definition(t, "governador-ac")); err == nil {
		t.Fatal("expected error on 404")
	}
}

func TestSimSourceProgresses(t *testing.T) {
	now := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	clock := func() time.Time { return now }
	sim, err := NewSimSource(clock, 10*time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	for _, d := range Definitions() {
		r, _, err := sim.Fetch(context.Background(), d)
		if err != nil {
			t.Fatal(err)
		}
		if r.Sections.Counted != 0 || r.Final || len(r.Candidates) != 2 {
			t.Fatalf("%s at start %+v", d.ID, r)
		}
	}
	d := definition(t, "presidente-br")
	now = now.Add(3 * time.Minute)
	mid, _, _ := sim.Fetch(context.Background(), d)
	if mid.Sections.Counted == 0 || mid.Final || mid.Candidates[0].Votes < mid.Candidates[1].Votes {
		t.Fatalf("mid %+v", mid)
	}
	if mid.Candidates[0].Votes+mid.Candidates[1].Votes != mid.Votes.Valid {
		t.Fatalf("votes do not add up %+v", mid)
	}
	now = now.Add(5 * time.Minute)
	later, _, _ := sim.Fetch(context.Background(), d)
	if later.Sections.Counted <= mid.Sections.Counted {
		t.Fatal("sections must grow")
	}
	now = now.Add(10 * time.Minute)
	for _, d := range Definitions() {
		end, _, _ := sim.Fetch(context.Background(), d)
		if !end.Final || end.Sections.Percent != 100 || !end.Candidates[0].Elected || end.Candidates[1].Elected {
			t.Fatalf("%s at end %+v", d.ID, end)
		}
	}
}
