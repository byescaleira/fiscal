package senado

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func data(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestParseCurrent(t *testing.T) {
	s, err := ParseCurrent(data(t, "lista_atual.json"))
	if err != nil {
		t.Fatal(err)
	}
	if len(s) != 2 {
		t.Fatalf("senators = %d", len(s))
	}
	a := s[0]
	if a.Code != 5672 || a.Name != "Alan Rick" || a.FullName != "Alan Rick Miranda" || a.UF != "AC" || a.Party != "REPUBLICANOS" {
		t.Fatalf("senator = %+v", a)
	}
	if a.MandateStart != "2023-02-01" || a.MandateEnd != "2031-01-31" || a.Participation != "Titular" || a.Phone != "(61) 3303-6333" {
		t.Fatalf("mandate = %+v", a)
	}
	if !strings.HasPrefix(a.Photo, "https://") {
		t.Fatalf("photo must be https: %s", a.Photo)
	}
}

func TestParseDetailMandatesCommittees(t *testing.T) {
	d, err := ParseDetail(data(t, "senador.json"))
	if err != nil || d.BirthDate != "1976-10-23" || d.BirthPlace != "Rio Branco" || d.BirthUF != "AC" || !strings.Contains(d.Address, "Anexo 2 Ala") {
		t.Fatalf("detail = %+v %v", d, err)
	}
	m, err := ParseMandates(data(t, "mandatos.json"))
	if err != nil || len(m) == 0 || m[0].Start != "2023-02-01" || m[0].End != "2031-01-31" || m[0].UF != "AC" {
		t.Fatalf("mandates = %+v %v", m, err)
	}
	c, err := ParseCommittees(data(t, "comissoes.json"))
	if err != nil || len(c) != 3 || c[0].Acronym != "CMO" || c[0].Role != "Titular" || c[0].Start != "2026-06-15" || c[0].End != "" {
		t.Fatalf("committees = %+v %v", c, err)
	}
}

func TestParseSpeeches(t *testing.T) {
	s, err := ParseSpeeches(data(t, "discursos.json"))
	if err != nil || len(s) != 2 {
		t.Fatalf("speeches = %+v %v", s, err)
	}
	if s[0].Date != "2026-09-02" || s[0].Kind != "Pela Liderança" || !strings.HasPrefix(s[0].URL, "https://www25.senado.leg.br/") || s[0].Summary == "" {
		t.Fatalf("speech = %+v", s[0])
	}
}

func TestParseProcesses(t *testing.T) {
	p, err := ParseProcesses(data(t, "processo.json"))
	if err != nil || len(p) != 3 {
		t.Fatalf("processes = %+v %v", p, err)
	}
	for _, x := range p {
		if x.Kind == "" || x.Number == 0 || x.Year == 0 || x.URL == "" {
			t.Fatalf("process = %+v", x)
		}
	}
	if p[2].Kind != "PEC" {
		t.Fatalf("last = %+v", p[2])
	}
}

func TestSplitIdentification(t *testing.T) {
	cases := map[string][3]any{
		"PEC 221/2019": {"PEC", 221, 2019},
		"RQS 41/2023":  {"RQS", 41, 2023},
		"R.S 3/2024":   {"R.S", 3, 2024},
		"MSF":          {"MSF", 0, 0},
	}
	for in, want := range cases {
		k, n, y := SplitIdentification(in)
		if k != want[0] || n != want[1] || y != want[2] {
			t.Errorf("%q = %s %d %d", in, k, n, y)
		}
	}
}

func TestParseVotes(t *testing.T) {
	v, err := ParseVotes(data(t, "votacao.json"))
	if err != nil || len(v) != 1 {
		t.Fatalf("votes = %+v %v", v, err)
	}
	x := v[0]
	if x.Code != 7106 || x.Date != "2026-10-14" || x.Kind != "PEC" || x.Number != 221 || x.Result != "A" || x.Secret || x.Yes != nil || len(x.Ballots) != 6 {
		t.Fatalf("vote = %+v", x)
	}
	if x.Ballots[0].Code != 5672 || x.Ballots[0].Vote != "Sim" || x.Ballots[0].UF != "AC" {
		t.Fatalf("ballot = %+v", x.Ballots[0])
	}
}

func TestVoteLabels(t *testing.T) {
	if VoteLabel("P-NRV") != "Presente sem voto" || VoteLabel("XYZ") != "XYZ" || !Present("P-NRV") || Present("AP") {
		t.Fatal("labels")
	}
}

func TestParseExpenses(t *testing.T) {
	e, err := ParseExpenses(data(t, "ceaps.json"))
	if err != nil || len(e) != 4 {
		t.Fatalf("expenses = %+v %v", e, err)
	}
	last := e[3]
	if last.SenatorCode != 4639 || last.Cents != 457632 || last.Month != 3 || last.Year != 2026 || last.SupplierID != "33.937.681/0001-78" {
		t.Fatalf("expense = %+v", last)
	}
	for _, x := range e[:3] {
		if x.SenatorCode != 5672 {
			t.Fatalf("expense = %+v", x)
		}
	}
	if c, ok := numberCents("1095.705"); !ok || c != 109571 {
		t.Fatalf("rounding = %d", c)
	}
}

func TestParseAgenda(t *testing.T) {
	s, err := ParseAgenda(data(t, "agenda.json"))
	if err != nil || len(s) != 2 {
		t.Fatalf("sessions = %+v %v", s, err)
	}
	if s[1].Code != 591267 || s[1].Hour != "14:00" || s[1].Situation != "Encerrada" || len(s[1].Matters) != 2 {
		t.Fatalf("session = %+v", s[1])
	}
	m := s[1].Matters[0]
	if m.Identification != "PEC 221/2019" || m.Code != 174386 || !strings.HasPrefix(m.Ementa, "Altera o art. 7º") || m.Label != "Fim da escala 6x1" {
		t.Fatalf("matter = %+v", m)
	}
}
