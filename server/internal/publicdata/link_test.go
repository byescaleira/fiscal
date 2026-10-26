package publicdata

import (
	"os"
	"path/filepath"
	"testing"
)

var states = map[string]string{"ap": "Amapá", "ac": "Acre", "br": "Brasil", "sp": "São Paulo"}

func cand(year int, office, uf, cpf, sq, name, ballot, result string) Candidacy {
	elected := result == "ELEITO" || result == "ELEITO POR QP" || result == "ELEITO POR MÉDIA"
	return Candidacy{Year: year, Office: office, UF: uf, CPF: cpf, SQ: sq, Name: name, BallotName: ballot, Result: result, Elected: elected, Party: "P" + sq, BirthUF: "AP", Education: "SUPERIOR COMPLETO", BirthDate: "1983-09-28"}
}

func TestLinkByCPFAttachesEveryCandidacy(t *testing.T) {
	dep := &Person{Keys: []string{"camara:204379"}, Name: "Acácio Favacho", CPF: "74287028287", House: HouseCamara, Roles: []Role{{Office: OfficeFederalDeputy, UF: "ap", Status: StatusInOffice}}}
	cands := []Candidacy{
		cand(2022, OfficeFederalDeputy, "ap", "74287028287", "1", "ACÁCIO DA SILVA FAVACHO NETO", "ACÁCIO FAVACHO", "ELEITO POR MÉDIA"),
		cand(2026, OfficeSenator, "ap", "74287028287", "2", "ACÁCIO DA SILVA FAVACHO NETO", "ACÁCIO FAVACHO", "ELEITO"),
		cand(2022, OfficeFederalDeputy, "ap", "99999999999", "3", "OUTRA PESSOA", "OUTRA", "NÃO ELEITO"),
	}
	people := Link(LinkInput{People: []*Person{dep}, Candidacies: cands, PreviousYear: 2022, ElectionYear: 2026, StateNames: states})
	if len(people) != 1 {
		t.Fatalf("a federal deputy found only in the TSE must not be created: %d", len(people))
	}
	if len(dep.Candidacies) != 2 || dep.Candidacies[0].Year != 2026 {
		t.Fatalf("candidacies = %+v", dep.Candidacies)
	}
	if !dep.HasRole(OfficeSenator, "ap", StatusElected) || dep.Primary().Office != OfficeFederalDeputy {
		t.Fatalf("roles = %+v", dep.Roles)
	}
	if !hasKey(dep, CPFKey("74287028287")) {
		t.Fatal("CPF key")
	}
	for _, k := range dep.Keys {
		if k == "74287028287" || k == "cpf:74287028287" {
			t.Fatal("the raw CPF must never be a key")
		}
	}
	if dep.BirthPlace != "Amapá" || dep.Education != "Superior completo" {
		t.Fatalf("enrich = %q %q", dep.BirthPlace, dep.Education)
	}
}

func TestLinkSenatorByNameUFOfficeAndYear(t *testing.T) {
	sen := &Person{Keys: []string{"senado:5672"}, Name: "Alan Rick", CivilName: "Alan Rick Miranda", House: HouseSenado, Roles: []Role{{Office: OfficeSenator, UF: "ac", Status: StatusInOffice, MandateStart: "2023-02-01"}}}
	other := &Person{Keys: []string{"senado:1"}, Name: "Fulano", CivilName: "Fulano de Tal", House: HouseSenado, Roles: []Role{{Office: OfficeSenator, UF: "ac", Status: StatusInOffice, MandateStart: "2019-02-01"}}}
	cands := []Candidacy{
		cand(2022, OfficeSenator, "ac", "111", "10", "ALAN RICK MIRANDA", "ALAN RICK", "ELEITO"),
		cand(2022, OfficeSenator, "sp", "222", "11", "ALAN RICK MIRANDA", "ALAN RICK", "ELEITO"),
		cand(2022, OfficeSenator, "ac", "333", "12", "FULANO DE TAL", "FULANO", "NÃO ELEITO"),
	}
	cpf, ok := FindSenatorCPF(sen, cands)
	if !ok || cpf != "111" {
		t.Fatalf("cpf = %q %v", cpf, ok)
	}
	if _, ok := FindSenatorCPF(other, cands); ok {
		t.Fatal("a 2019 mandate must match only the 2018 election")
	}
	twin := []Candidacy{cands[0], cand(2022, OfficeSenator, "ac", "444", "13", "ALAN RICK MIRANDA", "OUTRO", "NÃO ELEITO")}
	if _, ok := FindSenatorCPF(sen, twin); ok {
		t.Fatal("ambiguous names must stay unlinked")
	}
	Link(LinkInput{People: []*Person{sen}, Candidacies: cands, PreviousYear: 2022, ElectionYear: 2026, StateNames: states})
	if sen.CPF != "111" || len(sen.Candidacies) != 1 {
		t.Fatalf("senator link = %q %+v", sen.CPF, sen.Candidacies)
	}
}

func TestLinkCreatesExecutivesAndStateDeputiesFromTheTSE(t *testing.T) {
	cands := []Candidacy{
		cand(2022, OfficePresident, "br", "1", "1", "LUIZ", "LULA", "ELEITO"),
		cand(2022, OfficeVicePresident, "br", "2", "2", "GERALDO", "GERALDO ALCKMIN", "ELEITO"),
		cand(2026, OfficePresident, "br", "1", "3", "LUIZ", "LULA", "2º TURNO"),
		cand(2022, OfficeGovernor, "ac", "4", "4", "GLADSON", "GLADSON CAMELI", "ELEITO"),
		cand(2022, OfficeViceGovernor, "ac", "5", "5", "MAILZA ASSIS CAMELI", "MAILZA ASSIS", "ELEITO"),
		cand(2026, OfficeSenator, "ac", "4", "6", "GLADSON", "GLADSON CAMELI", "ELEITO"),
		cand(2026, OfficeGovernor, "ac", "5", "7", "MAILZA ASSIS CAMELI", "MAILZA ASSIS", "2º TURNO"),
		cand(2022, OfficeGovernor, "sp", "8", "8", "TARCISIO", "TARCÍSIO", "ELEITO"),
		cand(2022, OfficeViceGovernor, "sp", "9", "9", "FELICIO", "FELICIO RAMUTH", "ELEITO"),
		cand(2022, OfficeStateDeputy, "ac", "10", "10", "PABLO", "TIO PABLO BREGENSE", "ELEITO POR QP"),
		cand(2026, OfficeStateDeputy, "ac", "11", "11", "NOVO", "NOVO NOME", "ELEITO POR QP"),
		cand(2022, OfficeStateDeputy, "ac", "12", "12", "SUPLENTE", "SUPLENTE", "SUPLENTE"),
	}
	people := Link(LinkInput{Candidacies: cands, PreviousYear: 2022, ElectionYear: 2026, StateNames: states})
	byName := map[string]*Person{}
	for _, p := range people {
		byName[p.Name] = p
	}
	lula := byName["Lula"]
	if lula == nil || !lula.HasRole(OfficePresident, "br", StatusInOffice) || lula.Primary().MandateEnd != "2027-01-05" || len(lula.Candidacies) != 2 {
		t.Fatalf("president = %+v", lula)
	}
	if p := byName["Geraldo Alckmin"]; p == nil || !p.HasRole(OfficeVicePresident, "br", StatusInOffice) {
		t.Fatalf("vice = %+v", p)
	}
	g := byName["Gladson Cameli"]
	if g == nil || g.HasRole(OfficeGovernor, "ac", StatusInOffice) || !g.HasRole(OfficeSenator, "ac", StatusElected) {
		t.Fatalf("a governor who ran for another office resigned: %+v", g)
	}
	m := byName["Mailza Assis"]
	if m == nil || !m.HasRole(OfficeGovernor, "ac", StatusInOffice) || m.HasRole(OfficeViceGovernor, "ac", StatusInOffice) || m.Primary().MandateStart != "" {
		t.Fatalf("the vice takes over: %+v", m)
	}
	if p := byName["Tarcísio"]; p == nil || !p.HasRole(OfficeGovernor, "sp", StatusInOffice) {
		t.Fatalf("sp governor = %+v", p)
	}
	if p := byName["Felicio Ramuth"]; p == nil || !p.HasRole(OfficeViceGovernor, "sp", StatusInOffice) {
		t.Fatalf("sp vice = %+v", p)
	}
	if p := byName["Tio Pablo Bregense"]; p == nil || !p.HasRole(OfficeStateDeputy, "ac", StatusInOffice) {
		t.Fatalf("state deputy = %+v", p)
	}
	if p := byName["Novo Nome"]; p == nil || p.Primary().Status != StatusElected {
		t.Fatalf("elected awaiting = %+v", p)
	}
	if _, ok := byName["Suplente"]; ok {
		t.Fatal("suplentes are not representatives")
	}
	if len(people) != 8 {
		t.Fatalf("people = %d", len(people))
	}
}

func TestLinkAssemblyUsesActiveMembers(t *testing.T) {
	var cands []Candidacy
	for _, n := range []string{"ANA", "BRUNO", "CARLA", "DANI", "EDU"} {
		cands = append(cands, cand(2022, OfficeStateDeputy, "ac", n, n, "NOME "+n, n, "ELEITO POR QP"))
	}
	cands = append(cands, cand(2022, OfficeStateDeputy, "ac", "SUP", "SUP", "SUPLENTE ATIVO", "SUPLENTE ATIVO", "SUPLENTE"))
	people := Link(LinkInput{Candidacies: cands, PreviousYear: 2022, ElectionYear: 2026, StateNames: states})
	members := []AssemblyMember{{ID: 1, Name: "Ana"}, {ID: 2, Name: "Bruno"}, {ID: 3, Name: "Carla"}, {ID: 4, FullName: "Nome Dani"}, {ID: 5, Name: "Suplente Ativo", Email: "s@al.ac.leg.br"}, {ID: 6, Name: "Desconhecido"}}
	people, matched := LinkAssembly(people, cands, "ac", 2022, members, true, "assembleia-ac", states)
	if len(matched) != 5 || matched[6] != nil {
		t.Fatalf("matched = %v", matched)
	}
	sup := matched[5]
	if sup == nil || !sup.HasRole(OfficeStateDeputy, "ac", StatusInOffice) || sup.Assembly != "assembleia-ac" || sup.Contact == nil || deref(sup.Contact.Email) != "s@al.ac.leg.br" {
		t.Fatalf("suplente in office = %+v", sup)
	}
	var edu *Person
	for _, p := range people {
		if p.Name == "Edu" {
			edu = p
		}
	}
	if edu == nil || !edu.HasRole(OfficeStateDeputy, "ac", StatusOnLeave) {
		t.Fatalf("an elected deputy missing from the active list is on leave: %+v", edu)
	}
	if !hasKey(matched[1], "assembleia-ac:1") {
		t.Fatal("assembly key")
	}
}

func TestLinkAssemblyKeepsStatusWhenTheListLooksIncomplete(t *testing.T) {
	var cands []Candidacy
	for _, n := range []string{"ANA", "BRUNO", "CARLA"} {
		cands = append(cands, cand(2022, OfficeStateDeputy, "ac", n, n, "NOME "+n, n, "ELEITO POR QP"))
	}
	people := Link(LinkInput{Candidacies: cands, PreviousYear: 2022, ElectionYear: 2026, StateNames: states})
	people, _ = LinkAssembly(people, cands, "ac", 2022, []AssemblyMember{{ID: 1, Name: "Ana"}}, true, "assembleia-ac", states)
	for _, p := range people {
		if p.Primary().Status != StatusInOffice {
			t.Fatalf("%s changed to %s", p.Name, p.Primary().Status)
		}
	}
}

func TestMandateFor(t *testing.T) {
	cases := []struct {
		office     string
		year       int
		start, end string
	}{
		{OfficePresident, 2022, "2023-01-01", "2027-01-05"},
		{OfficePresident, 2026, "2027-01-05", "2031-01-05"},
		{OfficeGovernor, 2026, "2027-01-06", "2031-01-06"},
		{OfficeSenator, 2018, "2019-02-01", "2027-01-31"},
		{OfficeSenator, 2026, "2027-02-01", "2035-01-31"},
		{OfficeFederalDeputy, 2026, "2027-02-01", "2031-01-31"},
		{OfficeStateDeputy, 2026, "", ""},
	}
	for _, c := range cases {
		s, e := MandateFor(c.office, c.year)
		if s != c.start || e != c.end {
			t.Errorf("%s %d = %s %s", c.office, c.year, s, e)
		}
	}
}

func TestSlugsAreStableAcrossRuns(t *testing.T) {
	path := filepath.Join(t.TempDir(), "slugs.json")
	reg, err := LoadSlugs(path)
	if err != nil {
		t.Fatal(err)
	}
	a := &Person{Keys: []string{"camara:1"}, Name: "João Silva", Roles: []Role{{UF: "sp"}}}
	first := reg.Assign([]*Person{a})
	if first[a] != "joao-silva" {
		t.Fatalf("first = %q", first[a])
	}
	if err := reg.Save(); err != nil {
		t.Fatal(err)
	}
	info, _ := os.Stat(path)
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("slugs mode = %v", info.Mode().Perm())
	}
	reg2, _ := LoadSlugs(path)
	a2 := &Person{Keys: []string{"camara:1"}, Name: "João Silva", Roles: []Role{{UF: "sp"}}}
	b := &Person{Keys: []string{"camara:2"}, Name: "João Silva", Roles: []Role{{UF: "rj"}}}
	c := &Person{Keys: []string{"camara:3"}, Name: "João Silva", Roles: []Role{{UF: "rj"}}}
	second := reg2.Assign([]*Person{b, a2, c})
	if second[a2] != "joao-silva" {
		t.Fatalf("existing slug changed to %q", second[a2])
	}
	if second[b] == second[c] || second[b] == "joao-silva" || second[b][:13] != "joao-silva-rj" || second[c][:13] != "joao-silva-rj" {
		t.Fatalf("new homonyms = %q %q", second[b], second[c])
	}
	fresh, _ := LoadSlugs("")
	x := &Person{Keys: []string{"k:1"}, Name: "Maria Souza", Roles: []Role{{UF: "ba"}}}
	y := &Person{Keys: []string{"k:2"}, Name: "Maria Souza", Roles: []Role{{UF: "pe"}}}
	got := fresh.Assign([]*Person{x, y})
	if got[x] != "maria-souza-ba" || got[y] != "maria-souza-pe" {
		t.Fatalf("same name in two UFs = %q %q", got[x], got[y])
	}
	gone := &Person{Keys: []string{"k:3"}, Name: "Pedro Lima", Roles: []Role{{UF: "ce"}}}
	fresh.Assign([]*Person{gone})
	newcomer := &Person{Keys: []string{"k:4"}, Name: "Pedro Lima", Roles: []Role{{UF: "ce"}}}
	if s := fresh.Assign([]*Person{newcomer})[newcomer]; s == "pedro-lima" {
		t.Fatal("a slug that belonged to someone else must not be reused")
	}
}

func TestAssemblyNamesIgnoreHonorifics(t *testing.T) {
	c := cand(2022, OfficeStateDeputy, "ac", "1", "1", "MICHELLE DE MELO", "DRA. MICHELLE MELO", "ELEITO POR QP")
	if !sameMember(AssemblyMember{Name: "MICHELLE MELO"}, c) || sameMember(AssemblyMember{Name: "MICHELLE"}, c) {
		t.Fatal("honorific match")
	}
}

func TestLinkAssemblyWithoutCurrentListOnlyLinksElected(t *testing.T) {
	cands := []Candidacy{
		cand(2022, OfficeStateDeputy, "ac", "A", "A", "NOME A", "ANA", "ELEITO POR QP"),
		cand(2022, OfficeStateDeputy, "ac", "B", "B", "NOME B", "BRUNO", "ELEITO POR QP"),
		cand(2022, OfficeStateDeputy, "ac", "S", "S", "NOME S", "SUPLENTE", "SUPLENTE"),
	}
	people := Link(LinkInput{Candidacies: cands, PreviousYear: 2022, ElectionYear: 2026, StateNames: states})
	people, matched := LinkAssembly(people, cands, "ac", 2022, []AssemblyMember{{ID: 1, Name: "Ana"}, {ID: 9, Name: "Suplente"}}, false, "assembleia-ac", states)
	if len(people) != 2 || len(matched) != 1 || matched[1] == nil {
		t.Fatalf("people=%d matched=%v", len(people), matched)
	}
	for _, p := range people {
		if p.Primary().Status != StatusInOffice {
			t.Fatalf("%s = %s", p.Name, p.Primary().Status)
		}
	}
}
