package tse

import (
	"archive/zip"
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"liveresults/internal/sources/fetch"
)

func openFixture(t *testing.T, name string) *os.File {
	t.Helper()
	f, err := os.Open(filepath.Join("testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { f.Close() })
	return f
}

func TestReadCandidatesDecodesLatin1AndFiltersOffices(t *testing.T) {
	var got []Candidate
	if err := ReadCandidates(openFixture(t, "consulta_cand_2022_AP.csv"), func(c Candidate) { got = append(got, c) }); err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 {
		t.Fatalf("candidates = %d", len(got))
	}
	c := got[0]
	if c.Year != 2022 || c.Office != FederalDeputy || c.UF != "AP" || c.SQ != "30001605451" || c.CPF != "74287028287" {
		t.Fatalf("candidate = %+v", c)
	}
	if c.Name != "ACÁCIO DA SILVA FAVACHO NETO" || c.BallotName != "ACÁCIO FAVACHO" || c.Party != "MDB" || c.BirthDate != "1983-09-28" || c.Result != "ELEITO POR MÉDIA" || !Elected(c.Result) {
		t.Fatalf("candidate = %+v", c)
	}
	var ac []Candidate
	if err := ReadCandidates(openFixture(t, "consulta_cand_2026_AC.csv"), func(c Candidate) { ac = append(ac, c) }); err != nil {
		t.Fatal(err)
	}
	for _, c := range ac {
		if !InScope(c.Office) {
			t.Fatalf("out of scope office %d", c.Office)
		}
	}
}

func TestMergeRoundsKeepsTheDecidedRound(t *testing.T) {
	in := []Candidate{
		{Year: 2026, SQ: "1", Round: 1, Result: "2º TURNO"},
		{Year: 2026, SQ: "1", Round: 2, Result: ""},
		{Year: 2022, SQ: "2", Round: 1, Result: "2º TURNO"},
		{Year: 2022, SQ: "2", Round: 2, Result: "ELEITO"},
	}
	out := MergeRounds(in)
	if len(out) != 2 || out[0].Result != "2º TURNO" || out[1].Result != "ELEITO" || out[1].Round != 2 {
		t.Fatalf("merged = %+v", out)
	}
}

func TestReadAssetsVotesAndAccounts(t *testing.T) {
	sq := "30001605451"
	keep := func(s string) bool { return s == sq }
	var assets []Asset
	if err := ReadAssets(openFixture(t, "bem_candidato_2022_AP.csv"), keep, func(a Asset) { assets = append(assets, a) }); err != nil {
		t.Fatal(err)
	}
	if len(assets) != 1 || assets[0].Kind != "Casa" || assets[0].Cents != 147000000 || assets[0].Year != 2022 {
		t.Fatalf("assets = %+v", assets)
	}
	var total int64
	if err := ReadVotes(openFixture(t, "votacao_candidato_munzona_2022_AP.csv"), keep, func(s string, round int, n int64) {
		if round != 1 {
			t.Fatalf("round = %d", round)
		}
		total += n
	}); err != nil {
		t.Fatal(err)
	}
	if total != 13086 {
		t.Fatalf("votes = %d", total)
	}
	var revenue int64
	origins := map[string]int64{}
	if err := ReadRevenues(openFixture(t, "receitas_candidatos_2022_AP.csv"), keep, func(s, origin string, c int64) {
		revenue += c
		origins[origin] += c
	}); err != nil {
		t.Fatal(err)
	}
	if revenue != 2207500 || origins["Recursos próprios"] != 1400000 {
		t.Fatalf("revenue = %d origins = %v", revenue, origins)
	}
	var expense int64
	if err := ReadExpenses(openFixture(t, "despesas_contratadas_candidatos_2022_AP.csv"), keep, func(s string, c int64) { expense += c }); err != nil {
		t.Fatal(err)
	}
	if expense != 0 {
		t.Fatalf("expenses paid to the candidate by others must not count as his: %d", expense)
	}
}

func TestEntriesSkipBrasilAndFilterUFs(t *testing.T) {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for _, n := range []string{"leiame.pdf", "consulta_cand_2022_AP.csv", "consulta_cand_2022_BR.csv", "consulta_cand_2022_BRASIL.csv", "consulta_cand_2022_SP.csv"} {
		w, _ := zw.Create(n)
		if n == "consulta_cand_2022_AP.csv" || n == "consulta_cand_2022_BR.csv" {
			data, _ := os.ReadFile(filepath.Join("testdata", n))
			w.Write(data)
		} else {
			w.Write([]byte("x"))
		}
	}
	zw.Close()
	payload := buf.Bytes()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeContent(w, r, "c.zip", time.Time{}, bytes.NewReader(payload))
	}))
	defer srv.Close()
	c := fetch.New("", 5*time.Second)
	c.Gap = 0
	remote, err := c.Open(context.Background(), srv.URL+"/c.zip")
	if err != nil {
		t.Fatal(err)
	}
	zr, err := remote.Zip()
	if err != nil {
		t.Fatal(err)
	}
	all := Entries(zr, "consulta_cand", 2022, nil)
	if len(all) != 3 {
		t.Fatalf("all = %d", len(all))
	}
	some := Entries(zr, "consulta_cand", 2022, []string{"ap", "br"})
	var cands []Candidate
	if err := EachEntry(some, func(name string, r io.Reader) error {
		return ReadCandidates(r, func(c Candidate) { cands = append(cands, c) })
	}); err != nil {
		t.Fatal(err)
	}
	if len(some) != 2 || len(cands) != 3 {
		t.Fatalf("entries=%d candidates=%d", len(some), len(cands))
	}
	if cands[0].Office != FederalDeputy || cands[2].Office != President || cands[2].BallotName != "LULA" || cands[1].Office != VicePresident {
		t.Fatalf("candidates = %+v", cands)
	}
}
