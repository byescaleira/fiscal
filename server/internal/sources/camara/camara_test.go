package camara

import (
	"archive/zip"
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fixture(t *testing.T, name string) *os.File {
	t.Helper()
	f, err := os.Open(filepath.Join("testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { f.Close() })
	return f
}

func bytesOf(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func TestParseDeputiesAndDetail(t *testing.T) {
	deps, err := ParseDeputies(bytesOf(t, "deputados.json"))
	if err != nil {
		t.Fatal(err)
	}
	if len(deps) != 3 || deps[0].ID != 204379 || deps[0].Name != "Acácio Favacho" || deps[0].UF != "AP" || deps[0].Party != "MDB" {
		t.Fatalf("deputies = %+v", deps)
	}
	d, err := ParseDetail(bytesOf(t, "deputado.json"))
	if err != nil {
		t.Fatal(err)
	}
	if d.CPF != "74287028287" || d.CivilName != "ACÁCIO DA SILVA FAVACHO NETO" || d.BirthCity != "Macapá" || d.BirthUF != "AP" || d.BirthDate != "1983-09-28" {
		t.Fatalf("detail = %+v", d)
	}
	if d.Situation != "Exercício" || d.Room != "414" || d.Building != "4" || d.Phone != "3215-5414" || d.OfficeEmail != "dep.acaciofavacho@camara.leg.br" {
		t.Fatalf("status = %+v", d)
	}
}

func TestParseHistory(t *testing.T) {
	h, err := ParseHistory(bytesOf(t, "historico.json"))
	if err != nil {
		t.Fatal(err)
	}
	if len(h) < 2 || h[1].Situation != "Exercício" || h[1].Time != "2023-02-01T12:05" || h[1].Legislature != 57 {
		t.Fatalf("history = %+v", h)
	}
}

func TestParseSpeechesStripsMarkup(t *testing.T) {
	s, err := ParseSpeeches(bytesOf(t, "discursos.json"))
	if err != nil {
		t.Fatal(err)
	}
	if len(s) != 2 || s[0].Kind != "PELA ORDEM" || s[0].Start != "2026-09-02T11:36" {
		t.Fatalf("speeches = %+v", s)
	}
	if strings.Contains(s[0].Summary, "&nbsp;") || !strings.Contains(s[0].Summary, "Projeto de Decreto Legislativo nº 995") {
		t.Fatalf("summary = %q", s[0].Summary)
	}
	if s[0].URL != "" || !strings.HasPrefix(s[1].URL, "https://imagem.camara.gov.br/") {
		t.Fatalf("urls = %q %q", s[0].URL, s[1].URL)
	}
}

func TestReadAuthorsAndPropositions(t *testing.T) {
	var authors []Authorship
	if err := ReadAuthors(fixture(t, "proposicoesAutores.csv"), func(a Authorship) { authors = append(authors, a) }); err != nil {
		t.Fatal(err)
	}
	if len(authors) != 4 || authors[0].PropositionID != 2645127 || authors[0].DeputyID != 204379 || !authors[0].Proponent || authors[1].Proponent || authors[1].Order != 50 {
		t.Fatalf("authors = %+v", authors)
	}
	var props []Proposition
	keep := func(id int64) bool { return id != 2645127 }
	if err := ReadPropositions(fixture(t, "proposicoes.csv"), keep, func(p Proposition) { props = append(props, p) }); err != nil {
		t.Fatal(err)
	}
	if len(props) != 3 {
		t.Fatalf("props = %d", len(props))
	}
	pec := props[2]
	if pec.ID != 2644800 || pec.Kind != "PEC" || pec.Number != 16 || pec.Year != 2026 || !strings.HasPrefix(pec.Ementa, "Acrescenta os art. 68-A") || pec.URL == "" {
		t.Fatalf("pec = %+v", pec)
	}
}

func TestReadVotesBallotsGuidanceAndPropositions(t *testing.T) {
	var votes []Vote
	if err := ReadVotes(fixture(t, "votacoes.csv"), func(v Vote) { votes = append(votes, v) }); err != nil {
		t.Fatal(err)
	}
	if len(votes) != 2 {
		t.Fatalf("votes = %d", len(votes))
	}
	nominal := votes[1]
	if nominal.ID != "2236186-60" || nominal.OrganID != PlenaryID || nominal.EventID != 83057 || nominal.Approved == nil || *nominal.Approved || nominal.Yes != 252 || nominal.No != 176 || nominal.Registered != "2026-10-14T20:56:14" {
		t.Fatalf("nominal = %+v", nominal)
	}
	if votes[0].Approved == nil || !*votes[0].Approved {
		t.Fatal("approved symbolic vote")
	}
	var ballots []Ballot
	if err := ReadBallots(fixture(t, "votacoesVotos.csv"), func(b Ballot) { ballots = append(ballots, b) }); err != nil {
		t.Fatal(err)
	}
	if len(ballots) != 6 || ballots[0].DeputyID != 204379 || ballots[0].Vote != "Sim" || ballots[0].Party != "MDB" || ballots[0].UF != "AP" {
		t.Fatalf("ballots = %+v", ballots)
	}
	var guidance []Guidance
	if err := ReadGuidance(fixture(t, "votacoesOrientacoes.csv"), func(g Guidance) { guidance = append(guidance, g) }); err != nil {
		t.Fatal(err)
	}
	for _, g := range guidance {
		if g.Guidance == "" {
			t.Fatal("empty guidance must be skipped")
		}
	}
	if len(guidance) == 0 || guidance[0].Bloc != "Missão" || guidance[0].Guidance != "Não" {
		t.Fatalf("guidance = %+v", guidance)
	}
	var vps []VoteProposition
	if err := ReadVotePropositions(fixture(t, "votacoesProposicoes.csv"), func(v VoteProposition) { vps = append(vps, v) }); err != nil {
		t.Fatal(err)
	}
	if len(vps) != 2 || vps[0].Kind != "PLP" || vps[0].Number != 281 || vps[0].Year != 2019 || vps[0].Title != "PLP 281/2019" {
		t.Fatalf("vote propositions = %+v", vps)
	}
}

func TestReadPresenceEventsAndOrgans(t *testing.T) {
	var pres []Presence
	if err := ReadPresence(fixture(t, "eventosPresencaDeputados.csv"), func(p Presence) { pres = append(pres, p) }); err != nil {
		t.Fatal(err)
	}
	if len(pres) != 3 || pres[0].EventID != 80872 || pres[0].DeputyID != 204379 {
		t.Fatalf("presence = %+v", pres)
	}
	var events []Event
	if err := ReadEvents(fixture(t, "eventos.csv"), func(e Event) { events = append(events, e) }); err != nil {
		t.Fatal(err)
	}
	if len(events) != 5 || events[1].ID != 83057 || events[1].Type != "Sessão Deliberativa" || events[1].Situation != "Encerrada" {
		t.Fatalf("events = %+v", events)
	}
	plenary := map[int64]bool{}
	if err := ReadEventOrgans(fixture(t, "eventosOrgaos.csv"), func(e, o int64) {
		if o == PlenaryID {
			plenary[e] = true
		}
	}); err != nil {
		t.Fatal(err)
	}
	if len(plenary) != 4 || plenary[83079] {
		t.Fatalf("plenary = %v", plenary)
	}
}

func TestReadCommittees(t *testing.T) {
	var cs []Committee
	if err := ReadCommittees(fixture(t, "orgaosDeputados.csv"), func(c Committee) { cs = append(cs, c) }); err != nil {
		t.Fatal(err)
	}
	if len(cs) != 3 || cs[0].DeputyID != 204379 || cs[0].Acronym != "CCJC" || cs[0].Name != "Comissão de Constituição e Justiça e de Cidadania" || cs[0].Start == "" {
		t.Fatalf("committees = %+v", cs)
	}
}

func TestReadExpensesFromZip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "Ano-2026.csv.zip")
	f, _ := os.Create(path)
	zw := zip.NewWriter(f)
	w, _ := zw.Create("Ano-2026.csv")
	w.Write(bytesOf(t, "ceap.csv"))
	zw.Close()
	f.Close()
	var ex []Expense
	if err := ReadExpensesZip(path, func(e Expense) { ex = append(ex, e) }); err != nil {
		t.Fatal(err)
	}
	if len(ex) != 3 {
		t.Fatalf("leadership rows without a deputy must be skipped: %d", len(ex))
	}
	e := ex[0]
	if e.DeputyID != 204379 || e.CPF != "74287028287" || e.Year != 2026 || e.Month != 3 || e.Cents != 95430 || e.Category != "MANUTENÇÃO DE ESCRITÓRIO DE APOIO À ATIVIDADE PARLAMENTAR" || e.DocumentID == "" || !strings.HasPrefix(e.URL, "https://www.camara.leg.br/") {
		t.Fatalf("expense = %+v", e)
	}
}

func TestParseAgendaUsesTheRelatedProposition(t *testing.T) {
	items, err := ParseAgenda(bytesOf(t, "pauta.json"))
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 || items[0].Kind != "PLP" || items[0].Number != 186 || items[0].Year != 2026 || items[0].Topic != "Discussão" || !strings.HasPrefix(items[0].Ementa, "Altera a Lei Complementar nº 123") {
		t.Fatalf("agenda = %+v", items[0])
	}
}

func TestParseEventsVoteDetailBallotsAndGuidanceFromAPI(t *testing.T) {
	events, err := ParseEvents(bytesOf(t, "eventos_plenario.json"))
	if err != nil || len(events) != 2 || events[0].ID != 83047 || events[0].Type != "Sessão Deliberativa" {
		t.Fatalf("events = %+v %v", events, err)
	}
	v, props, err := ParseVoteDetail(bytesOf(t, "votacao_api.json"))
	if err != nil {
		t.Fatal(err)
	}
	if v.ID != "2236186-60" || v.EventID != 83057 || v.Approved == nil || *v.Approved || len(props) != 1 || props[0].Title != "PLP 281/2019" {
		t.Fatalf("vote = %+v props = %+v", v, props)
	}
	b, err := ParseBallots(v.ID, bytesOf(t, "votos_api.json"))
	if err != nil || len(b) != 3 || b[0].DeputyID != 220588 || b[0].Vote != "Sim" || b[0].UF != "AC" {
		t.Fatalf("ballots = %+v %v", b, err)
	}
	g, err := ParseGuidance(v.ID, bytesOf(t, "orientacoes_api.json"))
	if err != nil || len(g) == 0 || g[0].Bloc != "Governo" || g[0].Guidance != "Não" {
		t.Fatalf("guidance = %+v %v", g, err)
	}
}

type pagedGetter struct {
	calls []string
	total int
}

func (p *pagedGetter) JSON(_ context.Context, raw string, v any) error {
	p.calls = append(p.calls, raw)
	u, _ := url.Parse(raw)
	page := u.Query().Get("pagina")
	var n int
	fmt.Sscan(page, &n)
	start := (n - 1) * pageSize
	var rows []map[string]any
	for i := start; i < p.total && i < start+pageSize; i++ {
		rows = append(rows, map[string]any{"id": i + 1, "nome": fmt.Sprintf("D%d", i+1), "siglaUf": "SP"})
	}
	data, _ := json.Marshal(map[string]any{"dados": rows})
	return json.Unmarshal(data, v)
}

func TestDeputiesPaginates(t *testing.T) {
	g := &pagedGetter{total: 213}
	deps, err := API{Get: g}.Deputies(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(deps) != 213 || len(g.calls) != 3 || !strings.Contains(g.calls[0], "itens=100") {
		t.Fatalf("deps=%d calls=%v", len(deps), g.calls)
	}
}
