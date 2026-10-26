package receita

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseUsesDetailColumnsInsteadOfTheirTotals(t *testing.T) {
	src := "Ano;M\xeas;UF;COFINS;COFINS - FINANCEIRAS;COFINS - DEMAIS;IRPF\r\n" +
		"2000;Janeiro;AC;100;;;5\r\n" +
		"2026;Janeiro;AC;;10,5;20;1\r\n"
	r, err := Parse(strings.NewReader(src))
	if err != nil {
		t.Fatal(err)
	}
	if got := r.Years[2000].ByUF["AC"]; got != 10500 {
		t.Fatalf("2000 = %d", got)
	}
	if got := r.Years[2026].ByUF["AC"]; got != 3150 {
		t.Fatalf("2026 = %d", got)
	}
}

func TestParseRealSample(t *testing.T) {
	f, err := os.Open(filepath.Join("testdata", "arrecadacao-estado.csv"))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	r, err := Parse(f)
	if err != nil {
		t.Fatal(err)
	}
	y := r.Years[2025]
	if y == nil || y.ByUF["AC"] <= 0 || y.ByUF["SP"] <= y.ByUF["AC"] || y.TotalCents() != y.ByUF["AC"]+y.ByUF["SP"] {
		t.Fatalf("2025 = %+v", y)
	}
	if _, ok := r.LatestComplete(); ok {
		t.Fatal("the sample has no complete year")
	}
}

func TestLatestCompleteYear(t *testing.T) {
	r := Revenue{Years: map[int]*Year{
		2025: {Year: 2025, Months: map[string]bool{}},
		2026: {Year: 2026, Months: map[string]bool{"janeiro": true}},
	}}
	for _, m := range []string{"janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"} {
		r.Years[2025].Months[m] = true
	}
	y, ok := r.LatestComplete()
	if !ok || y.Year != 2025 {
		t.Fatalf("latest = %+v %v", y, ok)
	}
}
