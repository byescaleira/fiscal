package publicdata

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

func hv(id, house, date, tm, prop string, nominal bool, approved *bool, desc string) *HouseVote {
	return &HouseVote{ID: id, House: house, Date: date, Time: tm, Proposition: prop, Kind: kindOfLabel(prop), Description: desc, Nominal: nominal, Approved: approved}
}

func realVotes() []*HouseVote {
	yes, no := bptr(true), bptr(false)
	return []*HouseVote{
		hv("camara-2487836-52", HouseCamara, "2026-10-15", "15:45", "PL 1123/2025", false, yes, "Aprovada a Redação Final assinada pelo relator, Dep. Rodrigo Valadares (PL/SE)."),
		hv("camara-2487836-50", HouseCamara, "2026-10-15", "15:44", "PL 1123/2025", false, yes, "Aprovada a Subemenda Substitutiva ao Projeto de Lei nº 1.123, de 2025, adotada pelo relator da Comissão de Saúde."),
		hv("senado-7108", HouseSenado, "2026-10-15", "", "PLP 186/2026", true, yes, "Votação nominal do Projeto de Lei Complementar nº 186, de 2026, nos termos do parecer."),
		hv("camara-2635476-40", HouseCamara, "2026-10-14", "19:44", "PLP 186/2026", false, yes, "Aprovada a Redação Final assinada pelo relator, Dep. Rubens Pereira Júnior (PT/MA)."),
		hv("camara-2635476-36", HouseCamara, "2026-10-14", "19:42", "PLP 186/2026", true, yes, "Aprovada a Subemenda Substitutiva Global ao Projeto de Lei Complementar nº 186, de 2026, adotada pelo relator, ressalvados os destaques. Sim: 461; Não: 4; Total: 465."),
		hv("camara-2635476-23", HouseCamara, "2026-10-14", "17:20", "PLP 186/2026", true, no, "Rejeitado o Requerimento. Sim: 11; Não: 387; Total: 398."),
		hv("senado-7107", HouseSenado, "2026-10-14", "", "PEC 221/2019", true, yes, "Votação nominal da Proposta de Emenda à Constituição nº 221, de 2019, em segundo turno."),
		hv("senado-7106", HouseSenado, "2026-10-14", "", "PEC 221/2019", true, yes, "Votação nominal da Proposta de Emenda à Constituição nº 221, de 2019, em primeiro turno."),
		hv("camara-2624161-51", HouseCamara, "2026-09-03", "16:17", "MPV 1357/2026", false, yes, "Aprovada a Redação Final."),
		hv("camara-2624161-49", HouseCamara, "2026-09-03", "16:16", "MPV 1357/2026", false, no, "Rejeitada a Emenda nº 97."),
		hv("camara-2624161-46", HouseCamara, "2026-09-03", "16:12", "MPV 1357/2026", false, no, "Rejeitada a Emenda nº 96."),
		hv("camara-2624161-43", HouseCamara, "2026-09-03", "16:09", "MPV 1357/2026", false, no, "Rejeitada a Emenda n° 2."),
		hv("camara-2624161-42", HouseCamara, "2026-09-03", "16:08", "MPV 1357/2026", false, no, "Rejeitado o Requerimento."),
		hv("camara-2624161-27", HouseCamara, "2026-09-03", "16:00", "MPV 1357/2026", false, nil, "Mantido o texto."),
		hv("camara-2624161-25", HouseCamara, "2026-09-03", "16:00", "MPV 1357/2026", false, no, "Rejeitada a Emenda nº 99."),
		hv("camara-2624161-22", HouseCamara, "2026-09-03", "15:58", "MPV 1357/2026", false, yes, "Aprovada a Medida Provisória nº 1.357, de 2026, na forma do Projeto de Lei de Conversão, ressalvados os destaques."),
		hv("camara-2624161-21", HouseCamara, "2026-09-03", "15:57", "MPV 1357/2026", false, yes, "Aprovado, em apreciação preliminar, o Parecer da Comissão Mista, na parte em que manifesta opinião favorável quanto ao atendimento dos pressupostos constitucionais de relevância e urgência."),
		hv("camara-2379032-83", HouseCamara, "2026-09-02", "18:33", "PL 3904/2023", false, yes, "Aprovada a Redação Final assinada pelo relator, Dep. Padre João (PT-MG)."),
		hv("camara-2379032-81", HouseCamara, "2026-09-02", "18:32", "PL 3904/2023", false, nil, "Mantido o texto."),
		hv("camara-2379032-78", HouseCamara, "2026-09-02", "18:28", "PL 3904/2023", false, yes, "Aprovado o Substitutivo ao Projeto de Lei nº 3.904, de 2023, adotado pelo relator da Comissão de Agricultura, ressalvado o destaque."),
		hv("camara-2379032-70", HouseCamara, "2026-09-02", "17:47", "PL 3904/2023", false, no, "Rejeitado o Requerimento."),
		hv("camara-2644910-8", HouseCamara, "2026-09-02", "16:40", "PLP 74/2026", false, yes, "Aprovado o Requerimento de Urgência (Art. 155 do RICD)."),
		hv("camara-2645346-18", HouseCamara, "2026-09-02", "13:53", "PDL 995/2026", true, yes, "Aprovado o Projeto de Decreto Legislativo nº 995, de 2026."),
		hv("camara-2645346-14", HouseCamara, "2026-09-02", "12:06", "PDL 995/2026", false, yes, "Aprovada a Redação Final assinada pelo relator, Dep. Aécio Neves (PSDB-MG)."),
		hv("camara-x-1", HouseCamara, "2026-09-02", "11:00", "", false, yes, "Aprovada a ata."),
	}
}

func groupByMain(groups []VoteGroup) map[string]VoteGroup {
	out := map[string]VoteGroup{}
	for _, g := range groups {
		out[g.Main.ID] = g
	}
	return out
}

func TestStageOf(t *testing.T) {
	cases := map[string]VoteStage{
		"Aprovada a Redação Final.":                               StageProcedural,
		"Rejeitado o Requerimento.":                               StageProcedural,
		"Aprovado o Requerimento de Urgência (Art. 155 do RICD).": StageProcedural,
		"Mantido o texto.":                                        StageProcedural,
		"Aprovado, em apreciação preliminar, o Parecer da Comissão Mista sobre a MP.": StageProcedural,
		"Rejeitada a Emenda nº 97.":  StageAmendment,
		"Aprovada a Subemenda nº 3.": StageAmendment,
		"Aprovada a Subemenda Substitutiva ao Projeto de Lei nº 1.123, de 2025.":                StageMerit,
		"Aprovado o Substitutivo do Senado Federal ao Projeto de Lei nº 1.435, de 2023.":        StageMerit,
		"Aprovada a Medida Provisória nº 1.357, de 2026, ressalvados os destaques.":             StageMerit,
		"Votação nominal da Proposta de Emenda à Constituição nº 221, de 2019, em 1º turno.":    StageMerit,
		"Votação nominal do Projeto de Lei Complementar nº 74, de 2026, nos termos do parecer.": StageMerit,
		"Aprovadas as Emendas do Senado Federal ao Projeto de Lei nº 10, de 2025.":              StageMerit,
		"Aprovada a ata.": StageOther,
	}
	for desc, want := range cases {
		if got := StageOf(&HouseVote{Description: desc}); got != want {
			t.Errorf("StageOf(%q) = %d, want %d", desc, got, want)
		}
	}
}

func TestGroupVotesPicksTheMeritVote(t *testing.T) {
	groups := GroupVotes(realVotes())
	byMain := groupByMain(groups)
	want := map[string]int{
		"camara-2487836-50": 2,
		"senado-7108":       1,
		"camara-2635476-36": 3,
		"senado-7107":       1,
		"senado-7106":       1,
		"camara-2624161-22": 9,
		"camara-2379032-78": 4,
		"camara-2644910-8":  1,
		"camara-2645346-18": 2,
		"camara-x-1":        1,
	}
	if len(groups) != len(want) {
		t.Fatalf("groups = %d, want %d", len(groups), len(want))
	}
	for id, n := range want {
		g, ok := byMain[id]
		if !ok {
			t.Fatalf("missing group led by %s", id)
		}
		if len(g.Votes) != n {
			t.Errorf("%s has %d votes, want %d", id, len(g.Votes), n)
		}
	}
	if g := byMain["camara-2487836-50"]; g.ID != "camara-2026-10-15-pl-1123-2025" {
		t.Errorf("group id = %s", g.ID)
	}
	if g := byMain["camara-x-1"]; g.ID != "camara-x-1" {
		t.Errorf("group without proposition = %s", g.ID)
	}
	order := make([]string, 0, len(groups))
	for _, g := range groups {
		order = append(order, g.Main.ID)
	}
	if order[0] != "camara-2487836-50" || order[len(order)-1] != "camara-x-1" {
		t.Errorf("order = %v", order)
	}
}

func TestGroupVotesKeepsPECTurnsApart(t *testing.T) {
	yes := bptr(true)
	votes := []*HouseVote{
		hv("camara-1-10", HouseCamara, "2026-07-10", "18:00", "PEC 9/2025", false, yes, "Aprovado o Requerimento de quebra de interstício."),
		hv("camara-1-12", HouseCamara, "2026-07-10", "19:00", "PEC 9/2025", true, yes, "Aprovada a Proposta de Emenda à Constituição nº 9, de 2025, em primeiro turno."),
		hv("camara-1-14", HouseCamara, "2026-07-10", "20:30", "PEC 9/2025", true, bptr(false), "Rejeitada a Emenda Aglutinativa nº 1."),
		hv("camara-1-20", HouseCamara, "2026-07-10", "22:00", "PEC 9/2025", true, yes, "Aprovada a Proposta de Emenda à Constituição nº 9, de 2025, em segundo turno."),
		hv("camara-1-22", HouseCamara, "2026-07-10", "22:05", "PEC 9/2025", false, yes, "Aprovada a Redação Final para o segundo turno."),
	}
	byMain := groupByMain(GroupVotes(votes))
	first, second := byMain["camara-1-12"], byMain["camara-1-20"]
	if len(byMain) != 2 || len(first.Votes) != 3 || len(second.Votes) != 2 {
		t.Fatalf("groups = %+v", byMain)
	}
	if first.ID != "camara-2026-07-10-pec-9-2025-turno-1" || second.ID != "camara-2026-07-10-pec-9-2025-turno-2" {
		t.Errorf("ids = %s %s", first.ID, second.ID)
	}
	senate := groupByMain(GroupVotes(realVotes()))
	if senate["senado-7106"].ID == senate["senado-7107"].ID {
		t.Errorf("PEC 221/2019 turns must stay apart")
	}
}

func TestMainVoteTieBreak(t *testing.T) {
	yes := bptr(true)
	votes := []*HouseVote{
		hv("camara-5-3", HouseCamara, "2026-05-05", "15:00", "PL 1/2026", false, yes, "Rejeitada a Emenda nº 1."),
		hv("camara-5-4", HouseCamara, "2026-05-05", "15:10", "PL 1/2026", true, yes, "Rejeitada a Emenda nº 2."),
		hv("camara-5-9", HouseCamara, "2026-05-05", "15:20", "PL 1/2026", false, yes, "Rejeitada a Emenda nº 3."),
	}
	if g := GroupVotes(votes); g[0].Main.ID != "camara-5-4" {
		t.Errorf("nominal must win the tie, got %s", g[0].Main.ID)
	}
	votes[1].Nominal = false
	if g := GroupVotes(votes); g[0].Main.ID != "camara-5-9" {
		t.Errorf("latest must win the tie, got %s", g[0].Main.ID)
	}
	votes[2].Time = ""
	votes[1].Time = ""
	votes[0].Time = ""
	if g := GroupVotes(votes); g[0].Main.ID != "camara-5-9" {
		t.Errorf("highest sequence must win without time, got %s", g[0].Main.ID)
	}
}

func TestRelatedAndShortSummary(t *testing.T) {
	byMain := groupByMain(GroupVotes(realVotes()))
	mpv := byMain["camara-2624161-22"]
	rel := mpv.RelatedTo(mpv.Main)
	got := make([]string, 0, len(rel))
	for _, r := range rel {
		got = append(got, r.Summary)
	}
	want := []string{"Pressupostos de relevância e urgência", "Emenda nº 99", "Destaque: texto mantido", "Requerimento", "Emenda nº 2", "Emenda nº 96", "Emenda nº 97", "Redação final"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("related = %v\nwant %v", got, want)
	}
	if rel[0].ID != "camara-2624161-21" || deref(rel[0].Time) != "15:57" || rel[0].Nominal || !*rel[0].Approved || rel[2].Approved != nil {
		t.Errorf("related[0] = %+v", rel[0])
	}
	pl := byMain["camara-2487836-50"]
	if s := ShortVoteSummary(pl.Main); s != "Subemenda substitutiva" {
		t.Errorf("short = %s", s)
	}
	final := pl.Votes[len(pl.Votes)-1]
	if r := pl.RelatedTo(final); len(r) != 1 || r[0].ID != "camara-2487836-50" {
		t.Errorf("related of the final wording = %+v", r)
	}
	if s := ShortVoteSummary(&HouseVote{Description: "Aprovada a ata da sessão anterior, lida pelo secretário, com as correções feitas em plenário pelos líderes."}); !strings.HasSuffix(s, "…") || len([]rune(s)) > 80 {
		t.Errorf("fallback = %s", s)
	}
}

func TestRelatedIsCapped(t *testing.T) {
	var votes []*HouseVote
	for i := range 14 {
		votes = append(votes, hv("camara-9-"+string(rune('a'+i)), HouseCamara, "2026-05-05", "15:"+string(rune('0'+i/10))+string(rune('0'+i%10)), "PL 2/2026", false, nil, "Rejeitada a Emenda nº 1."))
	}
	g := GroupVotes(votes)[0]
	if len(g.RelatedTo(g.Main)) != RelatedVotesShown {
		t.Errorf("related must be capped at %d", RelatedVotesShown)
	}
}

func TestBuildPublishesOneSummaryPerGroup(t *testing.T) {
	ds := sampleDataset()
	ds.Votes = realVotes()
	ds.Today = "2026-10-15"
	files := filesByPath(Build(ds, &Slugs{byKey: map[string]string{}}))
	recent := files["votes/recent.json"].([]VoteSummary)
	if len(recent) != 10 {
		t.Fatalf("recent = %d items", len(recent))
	}
	top := recent[0]
	if top.ID != "camara-2487836-50" || top.Group != "camara-2026-10-15-pl-1123-2025" || top.RelatedCount == nil || *top.RelatedCount != 1 || len(top.Related) != 1 || top.Related[0].Summary != "Redação final" {
		t.Fatalf("top = %+v", top)
	}
	for _, v := range realVotes() {
		if _, ok := files["votes/"+v.ID+".json"]; !ok {
			t.Errorf("detail missing for %s", v.ID)
		}
	}
	det := files["votes/camara-2487836-52.json"].(VoteDetail)
	if det.Group != top.Group || len(det.Related) != 1 || det.Related[0].ID != "camara-2487836-50" {
		t.Errorf("detail = %+v", det.VoteSummary)
	}
	raw, err := json.Marshal(files["votes/camara-x-1.json"])
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(raw), "relatedCount") || strings.Contains(string(raw), `"related"`) || !strings.Contains(string(raw), `"group":"camara-x-1"`) {
		t.Errorf("singleton = %s", raw)
	}
	digest := files["today.json"].(TodayDigest)
	var refs []string
	for _, e := range digest.Events {
		if e.Kind == "vote" {
			refs = append(refs, deref(e.Ref))
		}
	}
	if !reflect.DeepEqual(refs, []string{"camara-2487836-50", "senado-7108"}) {
		t.Errorf("today votes = %v", refs)
	}
}
