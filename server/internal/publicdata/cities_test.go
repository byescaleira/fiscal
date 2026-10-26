package publicdata

import (
	"strings"
	"testing"
)

func TestMatchUnitsResolvesTheRealNameDifferences(t *testing.T) {
	units := []Unit{
		{"AC", "01392", "RIO BRANCO"},
		{"BA", "34118", "CAMACÃ"},
		{"MG", "41092", "BARÃO DE MONTE ALTO"},
		{"MG", "44571", "DONA EUSÉBIA"},
		{"MG", "53031", "SÃO THOMÉ DAS LETRAS"},
		{"MT", "91553", "SANTO ANTÔNIO DO LEVERGER"},
		{"PA", "04120", "ELDORADO DOS CARAJÁS"},
		{"PA", "05290", "SANTA ISABEL DO PARÁ"},
		{"RN", "17035", "BOA SAÚDE"},
		{"RO", "00256", "ESPIGÃO DO OESTE"},
		{"RO", "00337", "ALVORADA DO OESTE"},
		{"RR", "03158", "SÃO LUIZ"},
		{"SE", "31011", "AMPARO DE SÃO FRANCISCO"},
		{"SP", "71013", "SÃO LUÍS DO PARAITINGA"},
		{"SP", "99999", "CIDADE QUE NÃO EXISTE"},
	}
	muns := []PlaceEntry{
		{"1200401", "Rio Branco", "ac"},
		{"2905602", "Camacan", "ba"},
		{"3105509", "Barão do Monte Alto", "mg"},
		{"3122900", "Dona Euzébia", "mg"},
		{"3165206", "São Tomé das Letras", "mg"},
		{"5107800", "Santo Antônio de Leverger", "mt"},
		{"1502954", "Eldorado do Carajás", "pa"},
		{"1506500", "Santa Izabel do Pará", "pa"},
		{"2405306", "Januário Cicco", "rn"},
		{"1100098", "Espigão D'Oeste", "ro"},
		{"1100346", "Alvorada D'Oeste", "ro"},
		{"1400605", "São Luiz do Anauá", "rr"},
		{"2800100", "Amparo do São Francisco", "se"},
		{"3550001", "São Luiz do Paraitinga", "sp"},
		{"5300108", "Brasília", "df"},
		{"2605459", "Fernando de Noronha", "pe"},
	}
	m := MatchUnits(units, muns)
	want := map[string]string{
		"ac:01392": "1200401", "ba:34118": "2905602", "mg:41092": "3105509", "mg:44571": "3122900",
		"mg:53031": "3165206", "mt:91553": "5107800", "pa:04120": "1502954", "pa:05290": "1506500",
		"rn:17035": "2405306", "ro:00256": "1100098", "ro:00337": "1100346", "rr:03158": "1400605",
		"se:31011": "2800100", "sp:71013": "3550001",
	}
	for k, v := range want {
		if m.ByUnit[k] != v {
			t.Errorf("%s = %q, want %q", k, m.ByUnit[k], v)
		}
	}
	if len(m.ByUnit) != len(want) {
		t.Fatalf("matched = %v", m.ByUnit)
	}
	kinds := map[string][]string{}
	for _, r := range m.Reviews {
		kinds[r.Kind] = append(kinds[r.Kind], r.TSE+r.IBGE)
	}
	if strings.Join(kinds["unmatchedUnit"], ",") != "99999" || strings.Join(kinds["noElection"], ",") != "2605459,5300108" {
		t.Fatalf("reviews = %v", kinds)
	}
	if strings.Join(kinds["renamed"], ",") != "170352405306" {
		t.Fatalf("renamed = %v", kinds["renamed"])
	}
}

func TestMatchUnitsNeverGuessesBetweenTwoCandidates(t *testing.T) {
	m := MatchUnits([]Unit{{"SP", "1", "SÃO LUIZ"}}, []PlaceEntry{{"1", "São Luiz do Norte", "sp"}, {"2", "São Luiz do Sul", "sp"}})
	if len(m.ByUnit) != 0 {
		t.Fatalf("matched = %v", m.ByUnit)
	}
}

func cityPerson(key, name, office, party string) *Person {
	return &Person{
		Keys: []string{key}, Name: name,
		Roles:       []Role{{Office: office, UF: "ac", Status: StatusInOffice, Party: party, MandateStart: "2025-01-01", MandateEnd: "2028-12-31"}},
		Candidacies: []Candidacy{{Year: 2024, Office: office, UF: "ac", Party: party, Result: "ELEITO", Elected: true, Place: "Xapuri (AC)", AssetsLoaded: true, Assets: []AssetItem{{Kind: "Casa", Cents: 100}}}},
		Coverage:    map[string]Coverage{"assets": {Kind: "assets", Status: CoverageAvailable, Source: CitySource}},
		SourceIDs:   []string{CitySource},
	}
}

func TestBuildPublishesEveryCityWithItsHallAndCouncil(t *testing.T) {
	ds := sampleDataset()
	ds.Sources[CitySource] = Source{ID: CitySource, Name: "Tribunal Superior Eleitoral", URL: "https://dadosabertos.tse.jus.br", UpdatedAt: "2026-10-25T05:42:00-03:00"}
	twin := cityPerson("titulo:3", "Acácio Favacho", OfficeCityCouncilor, "PL")
	ds.Cities = []City{
		{Code: "1200708", Name: "Xapuri", UF: "ac", Unit: "01490", Officials: []*Person{
			cityPerson("titulo:1", "Zé do Posto", OfficeCityCouncilor, "PT"),
			cityPerson("titulo:2", "Vânio Miranda", OfficeViceMayor, "PSDB"),
			twin,
			cityPerson("titulo:4", "Maxsuel Maia", OfficeMayor, "PP"),
			cityPerson("titulo:5", "Ana Paula", OfficeCityCouncilor, "PP"),
		}},
		{Code: "1200013", Name: "Acrelândia", UF: "ac", Unit: "01120", Officials: []*Person{cityPerson("titulo:6", "Ana Paula", OfficeCityCouncilor, "MDB")}},
		{Code: "5300108", Name: "Brasília", UF: "df"},
	}
	out := Build(ds, &Slugs{byKey: map[string]string{}})
	files := map[string]any{}
	for _, f := range out.Files {
		files[f.Path] = f.Value
	}
	xapuri := files["places/city/1200708.json"].(CityFile)
	if len(xapuri.Groups) != 2 || xapuri.Groups[0].Title != "Prefeitura" || xapuri.Groups[1].Title != "Câmara Municipal" || xapuri.Note != nil {
		t.Fatalf("xapuri = %+v", xapuri)
	}
	var hall, council []string
	for _, c := range xapuri.Groups[0].People {
		hall = append(hall, c.Office+":"+c.Name)
	}
	for _, c := range xapuri.Groups[1].People {
		council = append(council, c.Name)
	}
	if strings.Join(hall, ",") != "mayor:Maxsuel Maia,viceMayor:Vânio Miranda" || strings.Join(council, ",") != "Acácio Favacho,Ana Paula,Zé do Posto" {
		t.Fatalf("hall = %v council = %v", hall, council)
	}
	if xapuri.Groups[0].Level != LevelCity || len(xapuri.Sources) == 0 {
		t.Fatalf("level/sources = %+v", xapuri)
	}
	acre := files["places/city/1200013.json"].(CityFile)
	if acre.Note == nil || !strings.Contains(*acre.Note, "prefeito") || len(acre.Groups) != 1 {
		t.Fatalf("acrelândia = %+v", acre)
	}
	df := files["places/city/5300108.json"].(CityFile)
	if df.Note == nil || !strings.Contains(*df.Note, "Distrito Federal") || len(df.Groups) != 0 {
		t.Fatalf("brasília = %+v", df)
	}
	slug := out.Slugs[twin]
	if slug != "acacio-favacho-xapuri-ac" {
		t.Fatalf("twin slug = %q", slug)
	}
	seen := map[string]bool{}
	for p, s := range out.Slugs {
		if seen[s] {
			t.Fatalf("duplicate slug %q for %s", s, p.Name)
		}
		seen[s] = true
	}
	prof := files["people/"+slug+".json"].(Profile)
	if prof.Office != OfficeCityCouncilor || deref(prof.Mandate.Start) != "2025-01-01" || len(prof.Timeline) != 1 || prof.Timeline[0].Place != "Xapuri (AC)" || prof.Numbers.AssetsCents == nil {
		t.Fatalf("profile = %+v", prof)
	}
	for _, c := range files["index/people.json"].([]PersonCard) {
		if CityOffice(c.Office) {
			t.Fatalf("city official %q leaked into the national index", c.Slug)
		}
	}
	if len(out.Cities) != 3+6 {
		t.Fatalf("city paths = %v", out.Cities)
	}
}

func TestCitySlugsStayWithTheirOwner(t *testing.T) {
	reg := &Slugs{byKey: map[string]string{"titulo:9": "ana-paula-xapuri-ac"}}
	first := cityPerson("titulo:8", "Ana Paula", OfficeCityCouncilor, "PT")
	owner := cityPerson("titulo:9", "Ana Paula", OfficeCityCouncilor, "PP")
	got := reg.AssignScoped([]*Person{first, owner}, func(*Person) string { return "ana-paula-xapuri-ac" }, map[string]bool{})
	if got[owner] != "ana-paula-xapuri-ac" || got[first] != "ana-paula-xapuri-ac-2" {
		t.Fatalf("slugs = %v", got)
	}
}
