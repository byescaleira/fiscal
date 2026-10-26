package publicdata

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

func marshalFiles(t *testing.T, files []File) map[string]string {
	t.Helper()
	out := map[string]string{}
	for _, f := range files {
		data, err := json.Marshal(f.Value)
		if err != nil {
			t.Fatal(err)
		}
		out[f.Path] = string(data)
	}
	return out
}

func TestBuildHotMatchesTheFullBuildForTheHotFiles(t *testing.T) {
	ds := sampleDataset()
	for i := range RecentVotes + 5 {
		ds.Votes = append(ds.Votes, &HouseVote{ID: fmt.Sprintf("camara-old-%d", i), House: HouseCamara, Date: fmt.Sprintf("2026-09-%02d", 1+i%28), Time: fmt.Sprintf("%02d:00", i%24), Description: "Votação antiga sobre saúde.", Nominal: true, Yes: iptr(i), No: iptr(1)})
	}
	baseOut := Build(ds, &Slugs{byKey: map[string]string{}})
	today := &HouseVote{
		ID: "camara-9-1", House: HouseCamara, Date: ds.Today, Time: "21:10", Proposition: "PEC 9/2026", Kind: "PEC",
		Description: "Aprovado em primeiro turno.", Ementa: "Altera a Constituição para tratar da segurança pública.", Approved: bptr(true), Result: "Aprovada", Nominal: true, Yes: iptr(1), No: iptr(0), Others: iptr(0),
		Guidance: []PartyGuidance{{Party: "MDB", Guidance: "Sim"}},
		Ballots:  []Ballot{{PersonKey: "camara:204379", Name: "Acácio Favacho", Party: "MDB", UF: "AP", Vote: "Sim", Present: true}, {PersonKey: "camara:999", Name: "Sem Cadastro", Party: "PT", UF: "SP", Vote: "Não", Present: true}},
	}
	agenda := []RawAgendaHouse{{House: HouseCamara, InSession: true, Items: []RawAgendaItem{{Proposition: "PEC 9/2026", Ementa: "Segurança pública.", Status: "Votação"}}, Sessions: []RawSession{{Title: "Sessão no Plenário da Câmara", Summary: "Sessão deliberativa, às 14h."}}}}
	full := sampleDataset()
	full.Votes = append(append([]*HouseVote{}, ds.Votes...), today)
	full.Agenda = agenda
	fullOut := marshalFiles(t, Build(full, &Slugs{byKey: map[string]string{}}).Files)
	hot := marshalFiles(t, BuildHot(HotInput{Base: baseOut.Hot, GeneratedAt: full.GeneratedAt, Today: full.Today, Agenda: agenda, Votes: []*HouseVote{today}, Races: full.Races}))
	want := append(append([]string{}, HotPaths...), "votes/camara-9-1.json")
	if len(hot) != len(want) {
		t.Fatalf("hot files = %d, want %v", len(hot), want)
	}
	for _, p := range want {
		if hot[p] == "" || hot[p] != fullOut[p] {
			t.Fatalf("%s differs:\n hot:  %s\n full: %s", p, hot[p], fullOut[p])
		}
	}
	if !strings.Contains(hot["votes/camara-9-1.json"], `"slug":"acacio-favacho`) {
		t.Fatalf("the hot vote must link the voter's slug: %s", hot["votes/camara-9-1.json"])
	}
	if len(baseOut.Hot.Recent) != RecentVotes || baseOut.Hot.Recent[0].Ballots != nil {
		t.Fatalf("the hot base keeps the %d most recent votes without ballots", RecentVotes)
	}
}

func refClassify(texts ...string) []string {
	padded := " " + Fold(strings.Join(texts, " ")) + " "
	out := []string{}
	if strings.TrimSpace(padded) == "" {
		return out
	}
	for _, t := range Themes {
		for _, s := range t.Stems {
			n := " " + Fold(s)
			if w, ok := strings.CutSuffix(s, "!"); ok {
				n = " " + Fold(w) + " "
			}
			if strings.Contains(padded, n) {
				out = append(out, t.Key)
				break
			}
		}
	}
	return out
}

func TestIndexedClassifierMatchesTheSubstringRule(t *testing.T) {
	var texts []string
	for _, th := range Themes {
		for _, s := range th.Stems {
			w := strings.TrimSuffix(s, "!")
			texts = append(texts, w, "A "+w+".", "pre"+w, w+"s finais", "(("+w+"))", strings.ToUpper(w)+" e mais")
		}
	}
	texts = append(texts, "", " ", "Dispõe sobre a saúde pública e a educação básica.", "Concede título de cidadão honorário.", "SUS", "o sus.", "5g", "Hospital")
	for _, x := range texts {
		got, want := Classify(x, "extra"), refClassify(x, "extra")
		if strings.Join(got, ",") != strings.Join(want, ",") {
			t.Fatalf("%q: %v != %v", x, got, want)
		}
		if again := Classify(x, "extra"); strings.Join(again, ",") != strings.Join(want, ",") {
			t.Fatalf("memoized %q: %v != %v", x, again, want)
		}
	}
}
