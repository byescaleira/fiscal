package ingest

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/camara"
	"liveresults/internal/sources/fetch"
	"liveresults/internal/sources/senado"
)

type fixtureFetcher struct {
	t      *testing.T
	routes map[string]string
	calls  []string
}

func (f *fixtureFetcher) JSON(_ context.Context, raw string, v any) error {
	f.calls = append(f.calls, raw)
	u, err := url.Parse(raw)
	if err != nil {
		return err
	}
	for suffix, file := range f.routes {
		if strings.HasSuffix(u.Path, suffix) {
			if file == "" {
				return json.Unmarshal([]byte("[]"), v)
			}
			data, err := os.ReadFile(file)
			if err != nil {
				f.t.Fatal(err)
			}
			return json.Unmarshal(data, v)
		}
	}
	return &fetch.StatusError{URL: raw, Status: 404}
}

func (f *fixtureFetcher) Cache(context.Context, string, int64) (fetch.Cached, error) {
	return fetch.Cached{}, errors.New("not used")
}

func (f *fixtureFetcher) Open(context.Context, string) (*fetch.Remote, error) {
	return nil, errors.New("not used")
}

func senadoFixtures(t *testing.T) *fixtureFetcher {
	dir := filepath.Join("..", "sources", "senado", "testdata")
	p := func(n string) string { return filepath.Join(dir, n) }
	return &fixtureFetcher{t: t, routes: map[string]string{
		"/senador/lista/atual.json":          p("lista_atual.json"),
		"/mandatos.json":                     p("mandatos.json"),
		"/comissoes.json":                    p("comissoes.json"),
		"/discursos.json":                    p("discursos.json"),
		"/senador/5672.json":                 p("senador.json"),
		"/processo":                          p("processo.json"),
		"/votacao":                           p("votacao.json"),
		"/despesas_ceaps/2026":               p("ceaps.json"),
		"/agenda/dia/20261014.json":          p("agenda.json"),
		"/agenda/dia/20261025.json":          p("agenda.json"),
		"/plenario/agenda/mes/20261025.json": "",
		"/plenario/agenda/mes/20261101.json": "",
	}}
}

func testIngest(t *testing.T, cfg Config, get Fetcher, now time.Time) *Ingest {
	cfg.PublicDir = filepath.Join(t.TempDir(), "public")
	cfg.DataDir = filepath.Join(t.TempDir(), "data")
	return New(cfg, get, func() time.Time { return now }, log.New(io.Discard, "", 0))
}

func readJSON(t *testing.T, path string, v any) {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, v); err != nil {
		t.Fatalf("%s: %v", path, err)
	}
}

func TestFullRefusesAPartialSenate(t *testing.T) {
	now := time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)
	in := testIngest(t, Config{Years: []int{2026}, Sources: map[string]bool{"senado": true}}, senadoFixtures(t), now)
	if _, err := in.Full(context.Background()); err == nil || !strings.Contains(err.Error(), "partial") {
		t.Fatalf("err = %v", err)
	}
	if _, err := os.Stat(filepath.Join(in.cfg.PublicDir, "v1", "meta.json")); !os.IsNotExist(err) {
		t.Fatal("a failed load must not publish")
	}
}

func TestFullSenateOnlyPublishesTheContractFiles(t *testing.T) {
	now := time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)
	get := senadoFixtures(t)
	in := testIngest(t, Config{Years: []int{2026}, UFs: []string{"ac"}, Sources: map[string]bool{"senado": true}}, get, now)
	rep, err := in.Full(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if rep.People != 1 || rep.Votes != 1 || rep.Files == 0 || rep.Written != rep.Files {
		t.Fatalf("report = %+v", rep)
	}
	v1 := filepath.Join(in.cfg.PublicDir, "v1")
	var prof publicdata.Profile
	readJSON(t, filepath.Join(v1, "people", "alan-rick.json"), &prof)
	if prof.Office != publicdata.OfficeSenator || prof.UF != "ac" || prof.Status != publicdata.StatusInOffice || deref(prof.Mandate.Start) != "2023-02-01" || deref(prof.Mandate.End) != "2031-01-31" {
		t.Fatalf("profile = %+v", prof)
	}
	if prof.Numbers.Attendance != nil || prof.Numbers.Proposals == nil || *prof.Numbers.Proposals != 2 || *prof.Numbers.Speeches != 2 || *prof.Numbers.Votes != 1 || *prof.Numbers.QuotaCents <= 0 {
		t.Fatalf("numbers = %+v", prof.Numbers)
	}
	if prof.Salary == nil || prof.Salary.MonthlyCents != federalPay || prof.BirthPlace == nil || *prof.BirthPlace != "Rio Branco, AC" {
		t.Fatalf("salary/birth = %+v %v", prof.Salary, prof.BirthPlace)
	}
	cov := map[string]publicdata.Coverage{}
	for _, c := range prof.Coverage {
		cov[c.Kind] = c
	}
	if cov["attendance"].Status != publicdata.CoverageNotPublished || cov["votes"].Status != publicdata.CoverageAvailable || cov["assets"].Status != publicdata.CoverageNotLoaded {
		t.Fatalf("coverage = %+v", prof.Coverage)
	}
	var votes publicdata.ListFile[publicdata.PersonVote]
	readJSON(t, filepath.Join(v1, "people", "alan-rick", "votes-2026.json"), &votes)
	if votes.Total != 1 || votes.Items[0].VoteID != "senado-7106" || votes.Items[0].Vote != "Sim" {
		t.Fatalf("votes = %+v", votes)
	}
	var detail publicdata.VoteDetail
	readJSON(t, filepath.Join(v1, "votes", "senado-7106.json"), &detail)
	if !detail.Nominal || *detail.Yes != 6 || *detail.No != 0 || len(detail.People) != 6 || deref(detail.People[0].Slug) != "alan-rick" || detail.People[1].Slug != nil {
		t.Fatalf("detail = %+v", detail.VoteSummary)
	}
	var agenda publicdata.AgendaFile
	readJSON(t, filepath.Join(v1, "agenda", "today.json"), &agenda)
	if agenda.Date != "2026-10-25" || len(agenda.Houses) != 1 || agenda.Houses[0].House != "senado" || len(agenda.Houses[0].Items) != 2 {
		t.Fatalf("agenda = %+v", agenda)
	}
	var today publicdata.TodayDigest
	readJSON(t, filepath.Join(v1, "today.json"), &today)
	if len(today.Events) != 2 || today.Events[0].Kind != "session" {
		t.Fatalf("today = %+v", today)
	}
	var place publicdata.PlaceFile
	readJSON(t, filepath.Join(v1, "places", "ac.json"), &place)
	if len(place.Groups) != 1 || place.Groups[0].Office != publicdata.OfficeSenator {
		t.Fatalf("place = %+v", place)
	}
	var meta publicdata.Meta
	readJSON(t, filepath.Join(v1, "meta.json"), &meta)
	if meta.Counts.People != 1 || meta.Counts.Federal != 1 {
		t.Fatalf("meta = %+v", meta)
	}
	slugs, err := os.ReadFile(filepath.Join(in.cfg.DataDir, "slugs.json"))
	if err != nil || !strings.Contains(string(slugs), "senado:5672") {
		t.Fatalf("slugs = %s %v", slugs, err)
	}
	again, err := in.Live(context.Background())
	if err != nil || again.Written != 0 {
		t.Fatalf("live refresh without news must not rewrite files: %+v %v", again, err)
	}
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func TestExerciseAndAttendance(t *testing.T) {
	history := []camara.Status{
		{Time: "2023-02-01T00:00", Situation: ""},
		{Time: "2023-02-01T12:05", Situation: "Exercício"},
		{Time: "2026-03-01T10:00", Situation: "Licença"},
		{Time: "2026-05-01T10:00", Situation: "Exercício"},
	}
	iv := exercise(history)
	if len(iv) != 2 || iv[0] != [2]string{"2023-02-01", "2026-03-01"} || iv[1] != [2]string{"2026-05-01", "9999-12-31"} {
		t.Fatalf("intervals = %v", iv)
	}
	cy := &camaraYear{
		sessions: map[int64]string{1: "2026-02-10", 2: "2026-04-10", 3: "2026-06-10", 4: "2026-07-10"},
		presence: map[int64]map[int64]bool{1: {7: true}, 2: {8: true}, 3: {8: true}},
	}
	present, eligible := attendance(cy, 7, iv)
	if present != 1 || eligible != 2 {
		t.Fatalf("attendance = %d/%d (sessions on leave or without a published list are not absences)", present, eligible)
	}
}

func TestCamaraHouseVoteKeepsOnlyPlenarySessions(t *testing.T) {
	yes := true
	if camaraHouseVote(camara.Vote{ID: "1-1", OrganID: 2003, EventID: 9}) != nil {
		t.Fatal("committee votes are not plenary votes")
	}
	if camaraHouseVote(camara.Vote{ID: "1-2", OrganID: camara.PlenaryID, EventID: 0}) != nil {
		t.Fatal("plenary records without a session are procedural")
	}
	hv := camaraHouseVote(camara.Vote{ID: "1-3", OrganID: camara.PlenaryID, EventID: 9, Date: "2026-10-14", Registered: "2026-10-14T20:56:14", Approved: &yes, Yes: 3, No: 1, Description: "Aprovado o projeto."})
	if hv.ID != "camara-1-3" || hv.Time != "20:56" || hv.Result != "Aprovada" {
		t.Fatalf("vote = %+v", hv)
	}
	finishCamaraVote(hv)
	if hv.Nominal || hv.Yes != nil {
		t.Fatal("a vote without ballots is symbolic")
	}
	if resultFor(nil, "Mantido o texto.") != "Mantido" || resultFor(nil, "Encaminhado") != "" {
		t.Fatal("results")
	}
}

func TestSenadoHouseVoteCountsOnlyPresentOthers(t *testing.T) {
	v := senado.Vote{Code: 1, Result: "R", Ballots: []senado.Ballot{{Code: 1, Vote: "Sim"}, {Code: 2, Vote: "Não"}, {Code: 3, Vote: "P-NRV"}, {Code: 4, Vote: "AP"}, {Code: 5, Vote: "Abstenção"}}}
	hv := senadoHouseVote(v)
	if *hv.Yes != 1 || *hv.No != 1 || *hv.Others != 2 || *hv.Approved || hv.Result != "Rejeitada" {
		t.Fatalf("vote = %+v", hv)
	}
	if hv.Ballots[3].Present || hv.Ballots[3].Vote != "Em atividade parlamentar" || !hv.Ballots[2].Present {
		t.Fatalf("ballots = %+v", hv.Ballots)
	}
	secret := senadoHouseVote(senado.Vote{Code: 2, Secret: true, Ballots: []senado.Ballot{{Code: 1, Vote: "Votou"}}})
	if secret.Yes != nil || !secret.Nominal {
		t.Fatalf("secret = %+v", secret)
	}
}

func TestRaceSummaryIsNeutral(t *testing.T) {
	var rf raceFile
	json.Unmarshal([]byte(`{"races":[{"id":"presidente-br","office":"president","uf":"br","round":2,"sections":{"percent":87.25}},{"id":"governador-to","office":"governor","uf":"to","round":2},{"id":"governador-ac","office":"governor","uf":"ac","round":2}],"fetchedAt":"2026-10-25T20:00:00Z"}`), &rf)
	ev := raceSummary(rf)
	if ev.Title != "Apuração do 2º turno" || ev.Summary != "87,2% das seções apuradas para presidente; governador em AC e TO." && ev.Summary != "87,3% das seções apuradas para presidente; governador em AC e TO." {
		t.Fatalf("race = %+v", ev)
	}
}

func TestRacesReadsOnlyTodaysFile(t *testing.T) {
	now := time.Date(2026, 10, 25, 22, 0, 0, 0, time.UTC)
	in := testIngest(t, Config{}, &fixtureFetcher{t: t}, now)
	os.MkdirAll(filepath.Join(in.cfg.PublicDir, "v1"), 0o755)
	write := func(at string) {
		os.WriteFile(filepath.Join(in.cfg.PublicDir, "v1", "races.json"), []byte(`{"races":[{"id":"presidente-br","office":"president","uf":"br","round":2,"final":true}],"fetchedAt":"`+at+`"}`), 0o644)
	}
	write("2026-10-25T21:00:00Z")
	if r := in.races(); len(r) != 1 || r[0].Title != "Apuração do 2º turno encerrada" {
		t.Fatalf("races = %+v", r)
	}
	write("2026-10-20T21:00:00Z")
	if r := in.races(); len(r) != 0 {
		t.Fatalf("old races = %+v", r)
	}
}

func TestApplyCoverage(t *testing.T) {
	gov := &publicdata.Person{Roles: []publicdata.Role{{Office: publicdata.OfficeGovernor, UF: "ac", Status: publicdata.StatusInOffice}}, Candidacies: []publicdata.Candidacy{{AssetsLoaded: true}}}
	applyCoverage(gov)
	if gov.Coverage["assets"].Status != publicdata.CoverageAvailable || gov.Coverage["campaigns"].Status != publicdata.CoverageNotLoaded || gov.Coverage["salary"].Status != publicdata.CoverageNotLoaded {
		t.Fatalf("governor = %+v", gov.Coverage)
	}
	dep := &publicdata.Person{Roles: []publicdata.Role{{Office: publicdata.OfficeStateDeputy, UF: "sp", Status: publicdata.StatusInOffice}}}
	applyCoverage(dep)
	if dep.Coverage["proposals"].Status != publicdata.CoverageNotPublished || dep.Coverage["proposals"].Source != "assembleia-sp" {
		t.Fatalf("state deputy = %+v", dep.Coverage)
	}
	sapl := &publicdata.Person{Assembly: "assembleia-ac", Roles: []publicdata.Role{{Office: publicdata.OfficeStateDeputy, UF: "ac", Status: publicdata.StatusInOffice}}}
	applyCoverage(sapl)
	if sapl.Coverage["proposals"].Status != publicdata.CoverageAvailable || sapl.Coverage["votes"].Status != publicdata.CoverageNotPublished {
		t.Fatalf("sapl deputy = %+v", sapl.Coverage)
	}
}

func TestHelpers(t *testing.T) {
	if d := cnpj("33.937.681/0001-78"); d == nil || *d != "33937681000178" {
		t.Fatal("cnpj")
	}
	if cnpj("123.456.789-01") != nil {
		t.Fatal("a person's CPF must not be published as the document")
	}
	if clock("2026-10-14T20:56:14") != "20:56" || clock("2026-10-14") != "" {
		t.Fatal("clock")
	}
	if a, b := yearRange(2026, "2026-10-25"); a != "2026-01-01" || b != "2026-10-25" {
		t.Fatal("year range")
	}
	if _, b := yearRange(2025, "2026-10-25"); b != "2025-12-31" {
		t.Fatal("past year range")
	}
	all := []*publicdata.HouseVote{{ID: "a", Description: "old"}, {ID: "b"}}
	all = upsertVotes(all, []*publicdata.HouseVote{{ID: "a", Description: "new"}, {ID: "c"}})
	if len(all) != 3 || all[0].Description != "new" || all[2].ID != "c" {
		t.Fatalf("upsert = %+v", all)
	}
	if p, n := electionYears([]int{2026, 2022}); p != 2022 || n != 2026 {
		t.Fatal("election years")
	}
	if daysIn(2026, 2) != 28 || daysIn(2024, 2) != 29 {
		t.Fatal("days")
	}
}
