package publicdata

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"
	"time"

	"liveresults/internal/publish"
)

func i64(v int64) *int64 { return &v }
func iptr(v int) *int    { return &v }
func bptr(v bool) *bool  { return &v }

func sampleDataset() *Dataset {
	updated := "2026-10-25T05:42:00-03:00"
	src := func(id, name, url string) Source { return Source{ID: id, Name: name, URL: url, UpdatedAt: updated} }
	deputy := &Person{
		Keys: []string{"camara:204379"}, Name: "Acácio Favacho", CivilName: "Acácio da Silva Favacho Neto", CPF: "74287028287",
		Roles:     []Role{{Office: OfficeFederalDeputy, UF: "ap", Status: StatusInOffice, Party: "MDB", MandateStart: "2023-02-01", MandateEnd: "2027-01-31"}},
		Photo:     "https://www.camara.leg.br/internet/deputado/bandep/204379.jpg",
		BirthDate: "1983-09-28", BirthPlace: "Macapá, AP", Education: "Superior",
		Contact: &Contact{Email: ptr("dep.acaciofavacho@camara.leg.br"), Phone: ptr("(61) 3215-5414"), Office: ptr("Anexo 4, gabinete 414")},
		House:   HouseCamara,
		Committees: []Committee{
			{Name: "Comissão de Constituição e Justiça e de Cidadania", Role: "Titular", Start: ptr("2025-03-01")},
			{Name: "Comissão de Minas e Energia", Role: "Suplente", Start: ptr("2023-03-01"), End: ptr("2024-02-01")},
		},
		Activity: map[int]*YearActivity{2026: {
			Year: 2026, Present: iptr(3), Eligible: iptr(4),
			Proposals: []RawProposal{
				{ID: "camara-2644800", Kind: "PEC", Number: 16, Year: 2026, Ementa: "Acrescenta o art. 68-A ao ADCT para ratificar os registros de imóveis rurais.", URL: "https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=2644800"},
				{ID: "camara-2644458", Kind: "RIC", Number: 2494, Year: 2026, Ementa: "Requer informações sobre a vacinação no SUS."},
			},
			Speeches: []RawSpeech{{Date: "2026-04-09T11:00", Kind: "PELA ORDEM", Summary: "Defendeu o seguro-defeso para pescadores artesanais."}},
			Expenses: []Expense{
				{ID: "camara-8077914", Year: 2026, Month: 3, Category: "MANUTENÇÃO DE ESCRITÓRIO", Supplier: "Fornecedor A", Document: ptr("32373812000179"), Cents: 95430},
				{ID: "camara-8122881", Year: 2026, Month: 5, Category: "MANUTENÇÃO DE ESCRITÓRIO", Supplier: "Fornecedor B", Cents: 85000, URL: ptr("https://www.camara.leg.br/doc.pdf")},
				{ID: "camara-1", Year: 2026, Month: 5, Category: "COMBUSTÍVEIS", Supplier: "Posto", Cents: 10000},
			},
		}},
		Candidacies: []Candidacy{{Year: 2022, Office: OfficeFederalDeputy, UF: "ap", Party: "MDB", Result: "ELEITO POR MÉDIA", Elected: true, SQ: "30001605451", CPF: "74287028287", Votes: i64(13086), RevenueCents: i64(2207500), ExpenseCents: i64(1900000), Assets: []AssetItem{{Kind: "Casa", Cents: 147000000}, {Kind: "Veículo", Cents: 5000000}, {Kind: "Casa", Cents: 1000000}}, AssetsLoaded: true}},
		Coverage: map[string]Coverage{
			"attendance": {Status: CoverageAvailable, Source: "camara"},
			"votes":      {Status: CoverageAvailable, Source: "camara"},
			"proposals":  {Status: CoverageAvailable, Source: "camara"},
			"speeches":   {Status: CoverageAvailable, Source: "camara"},
			"expenses":   {Status: CoverageAvailable, Source: "camara"},
			"assets":     {Status: CoverageAvailable, Source: "tse"},
			"campaigns":  {Status: CoverageAvailable, Source: "tse"},
			"salary":     {Status: CoverageAvailable, Source: "legislacao"},
		},
		SourceIDs: []string{"camara", "tse"},
	}
	governor := &Person{
		Keys: []string{CPFKey("1")}, Name: "Mailza Assis", CivilName: "Mailza Assis Cameli",
		Roles:       []Role{{Office: OfficeGovernor, UF: "ac", Status: StatusInOffice, Party: "PP", MandateEnd: "2027-01-06"}},
		Candidacies: []Candidacy{{Year: 2026, Office: OfficeGovernor, UF: "ac", Party: "PP", Result: "2º TURNO"}},
		SourceIDs:   []string{"tse"},
	}
	homonym := &Person{
		Keys: []string{CPFKey("2")}, Name: "Acácio Favacho",
		Roles:     []Role{{Office: OfficeStateDeputy, UF: "ac", Status: StatusElected, Party: "PL"}},
		SourceIDs: []string{"tse"},
	}
	v1 := &HouseVote{
		ID: "camara-2236186-60", House: HouseCamara, Date: "2026-10-14", Time: "20:56", Proposition: "PLP 281/2019", Kind: "PLP",
		Description: "Rejeitada a Subemenda Substitutiva.", Ementa: "Dispõe sobre os regimes de resolução das instituições financeiras.",
		Approved: bptr(false), Result: "Rejeitada", Nominal: true, Yes: iptr(1), No: iptr(1), Others: iptr(0),
		Guidance: []PartyGuidance{{Party: "MDB", Guidance: "Sim"}, {Party: "Fdr PT-PCdoB-PV", Guidance: "Não"}},
		Ballots: []Ballot{
			{PersonKey: "camara:204379", Name: "Acácio Favacho", Party: "MDB", UF: "AP", Vote: "Sim"},
			{PersonKey: "camara:160535", Name: "Marcon", Party: "PT", UF: "RS", Vote: "Não"},
		},
	}
	v2 := &HouseVote{ID: "senado-7108", House: HouseSenado, Date: "2026-10-25", Proposition: "PLP 186/2026", Kind: "PLP", Description: "Votação nominal do PLP 186/2026.", Ementa: "Altera a Lei Complementar nº 123, de 14 de dezembro de 2006, para dispor sobre o limite de receita bruta anual do Microempreendedor Individual.", Approved: bptr(true), Result: "Aprovada", Nominal: true, Yes: iptr(78), No: iptr(0), Others: iptr(1)}
	return &Dataset{
		GeneratedAt: time.Date(2026, 10, 25, 20, 42, 0, 0, time.UTC),
		Today:       "2026-10-25",
		Years:       []int{2026},
		Sources: map[string]Source{
			"camara":     src("camara", "Câmara dos Deputados", "https://dadosabertos.camara.leg.br"),
			"senado":     src("senado", "Senado Federal", "https://legis.senado.leg.br/dadosabertos"),
			"tse":        src("tse", "Tribunal Superior Eleitoral", "https://dadosabertos.tse.jus.br"),
			"ibge":       src("ibge", "IBGE", "https://servicodados.ibge.gov.br"),
			"legislacao": src("legislacao", "Decreto Legislativo nº 172/2022", "https://www2.camara.leg.br/legin/fed/decleg/2022/decretolegislativo-172-21-dezembro-2022-793529-publicacaooriginal-166604-pl.html"),
		},
		People:         []*Person{deputy, governor, homonym},
		Votes:          []*HouseVote{v1, v2},
		Municipalities: []PlaceEntry{{Code: "1600303", Name: "Macapá", UF: "ap"}, {Code: "1200401", Name: "Rio Branco", UF: "ac"}},
		States:         []PlaceEntry{{Code: "ap", Name: "Amapá", UF: "ap"}, {Code: "ac", Name: "Acre", UF: "ac"}},
		Agenda: []RawAgendaHouse{
			{House: HouseCamara, InSession: false, NextSession: "2026-10-27T14:00:00-03:00", Items: []RawAgendaItem{{Proposition: "PLP 186/2026", Ementa: "Altera o limite do Microempreendedor Individual.", Status: "Discussão", URL: "https://www.camara.leg.br/x"}}},
			{House: HouseSenado, InSession: true, Sessions: []RawSession{{Title: "Sessão deliberativa no Plenário do Senado", Summary: "Sessão Deliberativa Ordinária às 14:00"}}},
		},
		Laws:         []LawEvent{{ID: "camara-1", Title: "PL 1/2026", Ementa: "Institui o Dia Nacional do Fusca.", Date: "2026-10-25"}, {ID: "camara-2", Title: "PL 2/2026", Ementa: "x", Date: "2026-10-24"}},
		Races:        []RaceEvent{{Title: "Apuração do 2º turno", Summary: "Presidente e governadores de AC, AM, DF, ES, RN e TO."}},
		Quota:        QuotaTotals{Year: 2026, FederalDeputies: i64(190430), Senators: nil, ByCategory: map[string]int64{"MANUTENÇÃO DE ESCRITÓRIO": 180430, "COMBUSTÍVEIS": 10000}},
		Campaigns:    &CampaignTotals{Year: 2026, Revenue: 2207500, Expense: 1900000, ByOrigin: map[string]int64{"Recursos próprios": 1400000, "Recursos de pessoas físicas": 807500}},
		Revenue:      nil,
		Salaries:     []OfficeSalary{{Office: OfficeFederalDeputy, MonthlyCents: 4636619, Law: "Decreto Legislativo nº 172/2022"}},
		SalarySource: map[string]string{OfficeFederalDeputy: "legislacao"},
	}
}

func filesByPath(out Output) map[string]any {
	m := map[string]any{}
	for _, f := range out.Files {
		m[f.Path] = f.Value
	}
	return m
}

func jsonKeys(t *testing.T, v any) []string {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatalf("not an object: %s", data)
	}
	var keys []string
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func roundTrip(t *testing.T, v any) map[string]any {
	t.Helper()
	data, _ := json.Marshal(v)
	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func keysOf(s string) []string {
	k := strings.Split(s, ",")
	sort.Strings(k)
	return k
}

func TestBuildPublishesEveryContractFile(t *testing.T) {
	out := Build(sampleDataset(), &Slugs{byKey: map[string]string{}})
	files := filesByPath(out)
	for _, p := range []string{
		"meta.json", "index/people.json", "index/places.json", "places/ap.json", "places/ac.json",
		"people/acacio-favacho-ap.json", "people/acacio-favacho-ap/votes-2026.json", "people/acacio-favacho-ap/proposals-2026.json",
		"people/acacio-favacho-ap/speeches-2026.json", "people/acacio-favacho-ap/expenses-2026.json",
		"people/mailza-assis.json", "people/acacio-favacho-ac.json",
		"votes/recent.json", "votes/camara-2236186-60.json", "votes/senado-7108.json",
		"agenda/today.json", "money/overview.json", "today.json",
	} {
		if _, ok := files[p]; !ok {
			t.Errorf("missing %s", p)
		}
	}
	if _, ok := files["people/mailza-assis/votes-2026.json"]; ok {
		t.Error("people without a house must not get activity files")
	}
	if out.Files[len(out.Files)-1].Path != "meta.json" {
		t.Error("meta.json must be written last")
	}
}

func TestBuildFieldsMatchTheContract(t *testing.T) {
	files := filesByPath(Build(sampleDataset(), &Slugs{byKey: map[string]string{}}))
	check := func(name string, v any, want string) {
		t.Helper()
		if got := jsonKeys(t, v); !reflect.DeepEqual(got, keysOf(want)) {
			t.Errorf("%s keys = %v\nwant %v", name, got, keysOf(want))
		}
	}
	meta := files["meta.json"].(Meta)
	check("meta", meta, "generatedAt,sources,counts")
	check("meta.counts", meta.Counts, "people,federal,state,places")
	check("source", meta.Sources[0], "id,name,url,updatedAt")
	if meta.GeneratedAt != "2026-10-25T17:42:00-03:00" || meta.Counts != (Counts{People: 3, Federal: 1, State: 2, Places: 4}) {
		t.Fatalf("meta = %+v", meta)
	}
	cards := files["index/people.json"].([]PersonCard)
	check("card", cards[0], "slug,name,office,uf,party,photo,status")
	if len(cards) != 3 || cards[0].Name != "Acácio Favacho" || cards[2].Name != "Mailza Assis" || cards[2].Photo != nil {
		t.Fatalf("cards = %+v", cards)
	}
	places := files["index/places.json"].([]PlaceEntry)
	check("place", places[0], "code,name,uf")
	if places[0].Code != "ac" || places[2].Code != "1600303" {
		t.Fatalf("places = %+v", places)
	}
	pf := files["places/ap.json"].(PlaceFile)
	check("placeFile", pf, "uf,name,groups,sources")
	check("group", pf.Groups[0], "level,office,title,people")
	if pf.Name != "Amapá" || len(pf.Groups) != 1 || pf.Groups[0].Office != OfficeFederalDeputy || pf.Groups[0].Level != "state" {
		t.Fatalf("place file = %+v", pf)
	}
	ac := files["places/ac.json"].(PlaceFile)
	if len(ac.Groups) != 2 || ac.Groups[0].Office != OfficeGovernor || ac.Groups[1].Office != OfficeStateDeputy || !strings.Contains(ac.Groups[1].Title, "eleitos em 2026") || ac.Groups[1].People[0].Status != StatusElected {
		t.Fatalf("ac groups = %+v", ac.Groups)
	}
	prof := files["people/acacio-favacho-ap.json"].(Profile)
	check("profile", prof, "slug,name,civilName,office,uf,party,photo,status,mandate,birthDate,birthPlace,education,contact,salary,numbers,years,themes,committees,assets,campaigns,timeline,coverage,sources")
	check("mandate", prof.Mandate, "start,end")
	check("contact", *prof.Contact, "email,phone,office")
	check("salary", *prof.Salary, "monthlyCents,law")
	check("numbers", prof.Numbers, "attendance,proposals,laws,speeches,votes,quotaCents,assetsCents,campaignRevenueCents,lastElectionVotes")
	check("attendance", *prof.Numbers.Attendance, "present,eligible")
	check("year", prof.Years[0], "year,present,eligible,proposals,laws,speeches,votes,quotaCents")
	check("theme", prof.Themes[0], "key,proposals,speeches")
	check("committee", prof.Committees[0], "name,role,start,end")
	check("asset", prof.Assets[0], "year,totalCents,items")
	check("assetItem", prof.Assets[0].Items[0], "kind,cents")
	check("campaign", prof.Campaigns[0], "year,office,result,revenueCents,expenseCents")
	check("timeline", prof.Timeline[0], "year,office,place,party,result,votes")
	check("coverage", prof.Coverage[0], "kind,status,source")
	n := prof.Numbers
	if *n.Proposals != 2 || *n.Laws != 1 || *n.Speeches != 1 || *n.Votes != 1 || *n.QuotaCents != 190430 || *n.AssetsCents != 153000000 || *n.CampaignRevenueCents != 2207500 || *n.LastElectionVotes != 13086 || n.Attendance.Present != 3 || n.Attendance.Eligible != 4 {
		t.Fatalf("numbers = %+v", n)
	}
	if prof.Assets[0].Items[0] != (AssetItem{Kind: "Casa", Cents: 148000000}) {
		t.Fatalf("assets merged by kind = %+v", prof.Assets[0].Items)
	}
	if prof.Timeline[0].Place != "Amapá" || deref(prof.Timeline[0].Result) != "Eleito por média" || prof.Campaigns[0].Office != OfficeFederalDeputy {
		t.Fatalf("timeline = %+v", prof.Timeline)
	}
	if prof.Committees[0].End != nil || prof.Committees[1].Name != "Comissão de Minas e Energia" {
		t.Fatalf("current committees must come first: %+v", prof.Committees)
	}
	if prof.Salary.MonthlyCents != 4636619 || len(prof.Coverage) != 8 {
		t.Fatalf("salary/coverage = %+v %+v", prof.Salary, prof.Coverage)
	}
	gotThemes := map[string]ThemeCount{}
	for _, th := range prof.Themes {
		gotThemes[th.Key] = th
	}
	if gotThemes["saude"].Proposals != 1 || gotThemes["campo"].Proposals != 1 || gotThemes["campo"].Speeches != 1 || gotThemes["social"].Speeches != 1 {
		t.Fatalf("themes = %+v", prof.Themes)
	}
	gov := files["people/mailza-assis.json"].(Profile)
	if gov.Numbers.Proposals != nil || gov.Numbers.Votes != nil || gov.Numbers.Attendance != nil || gov.Salary != nil || len(gov.Years) != 0 || gov.Mandate.Start != nil || deref(gov.Mandate.End) != "2027-01-06" {
		t.Fatalf("governor must have nulls, not zeros: %+v", gov)
	}
	if len(gov.Coverage) != 3 || gov.Coverage[0].Status != CoverageNotLoaded {
		t.Fatalf("governor coverage = %+v", gov.Coverage)
	}
	if raw := roundTrip(t, gov)["numbers"].(map[string]any); raw["proposals"] != nil || raw["attendance"] != nil {
		t.Fatalf("nulls = %v", raw)
	}
	votes := files["people/acacio-favacho-ap/votes-2026.json"].(ListFile[PersonVote])
	check("votesFile", votes, "items,total")
	check("personVote", votes.Items[0], "voteId,date,proposition,summary,vote,partyGuidance,approved,themes")
	if votes.Total != 1 || deref(votes.Items[0].PartyGuidance) != "Sim" || *votes.Items[0].Approved || votes.Items[0].Vote != "Sim" {
		t.Fatalf("votes = %+v", votes)
	}
	props := files["people/acacio-favacho-ap/proposals-2026.json"].(ListFile[Proposal])
	check("proposal", props.Items[0], "id,kind,number,year,summary,plainSummary,canBecomeLaw,themes,url")
	if props.Total != 2 || props.Items[0].ID != "camara-2644800" || !props.Items[0].CanBecomeLaw || props.Items[1].URL != nil || props.Items[1].PlainSummary != "Pede informações sobre a vacinação no SUS." {
		t.Fatalf("proposals = %+v", props.Items)
	}
	sp := files["people/acacio-favacho-ap/speeches-2026.json"].(ListFile[Speech])
	check("speech", sp.Items[0], "date,kind,summary,url")
	ex := files["people/acacio-favacho-ap/expenses-2026.json"].(ExpenseFile)
	check("expensesFile", ex, "items,totalCents,byMonth,byCategory")
	check("expense", ex.Items[0], "id,year,month,category,supplier,document,cents,url")
	check("byMonth", ex.ByMonth[0], "month,cents")
	check("byCategory", ex.ByCategory[0], "category,cents,count")
	if ex.TotalCents != 190430 || len(ex.ByMonth) != 2 || ex.ByMonth[0] != (MonthCents{3, 95430}) || ex.ByMonth[1] != (MonthCents{5, 95000}) || ex.ByCategory[0].Count != 2 || ex.ByCategory[0].Cents != 180430 {
		t.Fatalf("expenses = %+v", ex)
	}
	recent := files["votes/recent.json"].([]VoteSummary)
	check("voteSummary", recent[0], "id,house,date,time,proposition,kind,summary,plainSummary,themes,result,approved,nominal,yes,no,others")
	if len(recent) != 2 || recent[0].ID != "senado-7108" || recent[0].Time != nil || deref(recent[0].PlainSummary) != "Muda uma lei complementar para dispor sobre o limite de receita bruta anual do Microempreendedor Individual." {
		t.Fatalf("recent = %+v", recent)
	}
	det := files["votes/camara-2236186-60.json"].(VoteDetail)
	check("voteDetail", det, "id,house,date,time,proposition,kind,summary,plainSummary,themes,result,approved,nominal,yes,no,others,quorum,guidance,parties,people,sources")
	check("guidance", det.Guidance[0], "party,guidance")
	check("partyTally", det.Parties[0], "party,yes,no,others")
	check("votePerson", det.People[0], "slug,name,party,uf,vote")
	if deref(det.People[0].Slug) != "acacio-favacho-ap" || det.People[1].Slug != nil || det.People[0].UF != "ap" || det.Parties[0] != (PartyTally{"MDB", 1, 0, 0}) || !strings.Contains(deref(det.Quorum), "257 de 513") {
		t.Fatalf("detail = %+v", det)
	}
	ag := files["agenda/today.json"].(AgendaFile)
	check("agenda", ag, "date,houses")
	check("agendaHouse", ag.Houses[0], "house,inSession,nextSession,items")
	check("agendaItem", ag.Houses[0].Items[0], "proposition,summary,status,themes,url")
	if ag.Date != "2026-10-25" || !ag.Houses[1].InSession || ag.Houses[1].NextSession != nil || len(ag.Houses[1].Items) != 0 {
		t.Fatalf("agenda = %+v", ag)
	}
	money := files["money/overview.json"].(MoneyOverview)
	check("money", money, "year,quota,salaries,campaigns,revenue,sources")
	check("quota", money.Quota, "federalDeputiesCents,senatorsCents,byCategory")
	check("quotaCategory", money.Quota.ByCategory[0], "category,cents")
	check("salaryRow", money.Salaries[0], "office,monthlyCents,law")
	check("campaigns", *money.Campaigns, "year,revenueCents,expenseCents,byOrigin")
	check("origin", money.Campaigns.ByOrigin[0], "origin,cents")
	if money.Revenue != nil || money.Quota.SenatorsCents != nil || money.Campaigns.ByOrigin[0].Origin != "Recursos próprios" {
		t.Fatalf("money = %+v", money)
	}
	if raw := roundTrip(t, money); raw["revenue"] != nil {
		t.Fatal("revenue must be null")
	}
	today := files["today.json"].(TodayDigest)
	check("today", today, "date,events,sources")
	check("event", today.Events[0], "kind,title,summary,themes,ref")
	kinds := []string{}
	for _, e := range today.Events {
		kinds = append(kinds, e.Kind)
	}
	if !reflect.DeepEqual(kinds, []string{"race", "session", "vote", "law"}) || deref(today.Events[2].Ref) != "senado-7108" || today.Events[3].Title != "PL 1/2026" {
		t.Fatalf("today = %+v", today.Events)
	}
}

func TestBuildIsDeterministic(t *testing.T) {
	a, _ := json.Marshal(Build(sampleDataset(), &Slugs{byKey: map[string]string{}}).Files)
	b, _ := json.Marshal(Build(sampleDataset(), &Slugs{byKey: map[string]string{}}).Files)
	if string(a) != string(b) {
		t.Fatal("same input must give the same files")
	}
}

func TestPublishWritesTreeAndPrunesStaleProfiles(t *testing.T) {
	root := t.TempDir()
	stale := filepath.Join(root, "people", "old-slug.json")
	os.MkdirAll(filepath.Dir(stale), 0o755)
	os.WriteFile(stale, []byte("{}"), 0o644)
	races := filepath.Join(root, "races.json")
	os.WriteFile(races, []byte("{}"), 0o644)
	tree := publish.NewTree(root)
	if err := Publish(Build(sampleDataset(), &Slugs{byKey: map[string]string{}}), tree, true); err != nil {
		t.Fatal(err)
	}
	if publish.Exists(stale) {
		t.Fatal("stale profile must be pruned")
	}
	if !publish.Exists(races) {
		t.Fatal("races.json belongs to the live results and must stay")
	}
	data, err := os.ReadFile(filepath.Join(root, "people", "acacio-favacho-ap.json"))
	if err != nil || !json.Valid(data) || !publish.Exists(filepath.Join(root, "people", "acacio-favacho-ap.json.gz")) {
		t.Fatalf("profile not published: %v", err)
	}
	if st := tree.Stats(); st.Files == 0 || st.Written != st.Files || st.Removed != 1 {
		t.Fatalf("stats = %+v", st)
	}
	again := publish.NewTree(root)
	if err := Publish(Build(sampleDataset(), &Slugs{byKey: map[string]string{}}), again, true); err != nil {
		t.Fatal(err)
	}
	if st := again.Stats(); st.Written != 0 {
		t.Fatalf("unchanged data rewrote %d files", st.Written)
	}
}
