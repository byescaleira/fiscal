package publicdata

import (
	"path/filepath"
	"reflect"
	"sort"
	"testing"
	"time"

	"liveresults/internal/publish"
)

type scopePerson struct {
	slug, name, civil string
}

func checkScope(extra ...scopePerson) ([]*Person, map[*Person]string) {
	base := []scopePerson{
		{"lula", "Lula", "Luiz Inácio Lula da Silva"},
		{"flavio-bolsonaro", "Flávio Bolsonaro", "Flávio Nantes Bolsonaro"},
		{"eduardo-bolsonaro", "Eduardo Bolsonaro", "Eduardo Nantes Bolsonaro"},
		{"lula-da-fonte", "Lula da Fonte", ""},
		{"nikolas-ferreira", "Nikolas Ferreira", "Nikolas Ferreira de Oliveira"},
		{"carlos-silva-sp", "Carlos Silva", "Carlos Alberto da Silva"},
		{"carlos-silva-ba", "Carlos Silva", "Carlos Eduardo Silva"},
		{"neto", "Neto", "José Ribamar Neto"},
	}
	var people []*Person
	slugs := map[*Person]string{}
	for _, s := range append(base, extra...) {
		p := &Person{Name: s.name, CivilName: s.civil}
		people = append(people, p)
		slugs[p] = s.slug
	}
	return people, slugs
}

func raw(id, date, title string, texts ...string) RawCheck {
	v := "Falso"
	return RawCheck{ID: id, Source: "comprova", Title: title, Texts: texts, Verdict: &v, Date: date, URL: "https://projetocomprova.com.br/publica%C3%A7%C3%B5es/" + id + "/", Publisher: "Projeto Comprova", License: "CC BY-ND 4.0", LicenseURL: "https://creativecommons.org/licenses/by-nd/4.0/deed.pt-br"}
}

func linkedSlugs(m CheckMatch, slugs map[*Person]string, id string) []string {
	out := []string{}
	for p, items := range m.ByPerson {
		for _, it := range items {
			if it.ID == id {
				out = append(out, slugs[p])
			}
		}
	}
	sort.Strings(out)
	return out
}

func reviewsOf(m CheckMatch, id string) []CheckReview {
	var out []CheckReview
	for _, r := range m.Reviews {
		if r.CheckID == id {
			out = append(out, r)
		}
	}
	return out
}

func TestChecksLinkOnlyTheExactFullName(t *testing.T) {
	people, slugs := checkScope()
	cases := []struct {
		check RawCheck
		want  []string
	}{
		{raw("c1", "2026-10-23", "É falso áudio de suposto membro da equipe de Flávio Bolsonaro sobre compra de votos"), []string{"flavio-bolsonaro"}},
		{raw("c2", "2026-09-30", "Vídeo de Lula no Paraguai é usado fora de contexto para sugerir construção de ponte"), []string{"lula"}},
		{raw("c3", "2026-10-01", "Lula da Fonte não votou contra a proposta, ao contrário do que diz post"), []string{"lula-da-fonte"}},
		{raw("c4", "2026-10-02", "Xuxa não gravou vídeo contra o presidente", "Gravação mescla imagens com falas de Luiz Inácio Lula da Silva (PT)."), []string{"lula"}},
		{raw("c5", "2026-10-03", "Presidente Lula não assinou decreto sobre igrejas"), []string{"lula"}},
		{raw("c6", "2026-10-04", "Receita de lula grelhada não cura gripe"), []string{}},
		{raw("c7", "2026-10-24", "Bets: Flávio Bolsonaro (PL) acusou Lula (PT) de ser o pai do tigrinho"), []string{"flavio-bolsonaro", "lula"}},
		{raw("c8", "2026-10-05", "Vídeo antigo do governo Bolsonaro circula como se fosse atual"), []string{}},
		{raw("c9", "2026-10-06", "Post de Nikolas distorce fala sobre igrejas"), []string{}},
		{raw("c10", "2026-10-07", "Post cita Flávio. Bolsonaro aparece em outra foto"), []string{}},
		{raw("c11", "2026-10-08", "Deputada eleita nega post sobre fechar igrejas divulgado por Nikolas Ferreira"), []string{"nikolas-ferreira"}},
	}
	var checks []RawCheck
	for _, c := range cases {
		checks = append(checks, c.check)
	}
	m := MatchChecks(people, slugs, checks)
	for _, c := range cases {
		if got := linkedSlugs(m, slugs, c.check.ID); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s %q: linked %v, want %v", c.check.ID, c.check.Title, got, c.want)
		}
	}
	r := reviewsOf(m, "c8")
	if len(r) != 1 || r[0].Reason != ReviewSurnameOnly || r[0].Name != "bolsonaro" || !reflect.DeepEqual(r[0].Candidates, []string{"eduardo-bolsonaro", "flavio-bolsonaro"}) {
		t.Fatalf("bolsonaro alone review = %+v", r)
	}
	if r := reviewsOf(m, "c1"); len(r) != 0 {
		t.Fatalf("a linked check must not send the same person to review: %+v", r)
	}
	if r := reviewsOf(m, "c9"); len(r) != 0 {
		t.Fatalf("a first name alone is ignored: %+v", r)
	}
}

func TestChecksSendHomonymsAndPartialNamesToReview(t *testing.T) {
	people, slugs := checkScope(scopePerson{"lula-ba", "Lula", "Luiz Carlos Lula Santos"})
	checks := []RawCheck{
		raw("h1", "2026-10-10", "Carlos Silva não disse que vai fechar escolas"),
		raw("h2", "2026-10-11", "Vídeo de Lula é montagem"),
		raw("h3", "2026-10-12", "ACM Neto não declarou apoio a candidato"),
	}
	m := MatchChecks(people, slugs, checks)
	for _, id := range []string{"h1", "h2", "h3"} {
		if got := linkedSlugs(m, slugs, id); len(got) != 0 {
			t.Errorf("%s linked %v", id, got)
		}
	}
	want := map[string]CheckReview{
		"h1": {Reason: ReviewAmbiguousName, Name: "carlos silva", Candidates: []string{"carlos-silva-ba", "carlos-silva-sp"}},
		"h2": {Reason: ReviewAmbiguousName, Name: "lula", Candidates: []string{"lula", "lula-ba"}},
		"h3": {Reason: ReviewPartOfLongerName, Name: "neto", Candidates: []string{"neto"}},
	}
	for id, w := range want {
		r := reviewsOf(m, id)
		if len(r) != 1 || r[0].Reason != w.Reason || r[0].Name != w.Name || !reflect.DeepEqual(r[0].Candidates, w.Candidates) {
			t.Errorf("%s review = %+v, want %+v", id, r, w)
		}
	}
	if m.Reviews[0].CheckID != "h3" {
		t.Fatalf("reviews must come newest first: %+v", m.Reviews)
	}
}

func TestChecksOrderAndVerdictConflict(t *testing.T) {
	people, slugs := checkScope()
	older := raw("comprova-99", "2026-10-01", "Post sobre Nikolas Ferreira engana")
	same := raw("comprova-100", "2026-10-01", "Nikolas Ferreira não disse isso")
	newer := raw("comprova-150", "2026-10-20", "Vídeo de Nikolas Ferreira foi editado")
	newer.Verdict = nil
	newer.Conflict = []string{"Enganoso", "Falso"}
	m := MatchChecks(people, slugs, []RawCheck{older, newer, same})
	var nikolas *Person
	for p, s := range slugs {
		if s == "nikolas-ferreira" {
			nikolas = p
		}
	}
	var ids []string
	for _, it := range m.ByPerson[nikolas] {
		ids = append(ids, it.ID)
	}
	if !reflect.DeepEqual(ids, []string{"comprova-150", "comprova-100", "comprova-99"}) {
		t.Fatalf("order = %v", ids)
	}
	if m.ByPerson[nikolas][0].Verdict != nil {
		t.Fatal("a conflicting seal must stay null")
	}
	r := reviewsOf(m, "comprova-150")
	if len(r) != 1 || r[0].Reason != ReviewVerdictConflict || !reflect.DeepEqual(r[0].Labels, []string{"Enganoso", "Falso"}) || !reflect.DeepEqual(r[0].Candidates, []string{"nikolas-ferreira"}) {
		t.Fatalf("conflict review = %+v", r)
	}
}

func TestTokenizeKeepsCaseAndBreaksOnPunctuation(t *testing.T) {
	got := tokenize("Flávio Bolsonaro, D’Ávila e São-Paulo.")
	want := []token{{"flavio", true, false}, {"bolsonaro", true, true}, {"d", true, false}, {"avila", true, true}, {"e", false, true}, {"sao", true, true}, {"paulo", true, true}}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("tokens = %+v", got)
	}
}

func TestBuildPublishesChecksOnlyForLinkedPeople(t *testing.T) {
	ds := sampleDataset()
	ds.Sources["comprova"] = Source{ID: "comprova", Name: "Projeto Comprova", URL: "https://projetocomprova.com.br", UpdatedAt: "2026-10-25T06:00:00-03:00"}
	ds.Checks = []RawCheck{
		raw("comprova-1", "2026-10-20", "Vídeo de Mailza Assis foi editado"),
		raw("comprova-2", "2026-10-21", "Post sobre Acácio Favacho engana"),
	}
	reg, err := LoadSlugs(filepath.Join(t.TempDir(), "slugs.json"))
	if err != nil {
		t.Fatal(err)
	}
	out := Build(ds, reg)
	var list *CheckList
	count := 0
	for _, f := range out.Files {
		if filepath.Base(f.Path) == "checks.json" {
			count++
			l := f.Value.(CheckList)
			list = &l
			if f.Path != "people/mailza-assis/checks.json" {
				t.Fatalf("path = %s", f.Path)
			}
		}
	}
	if count != 1 || list == nil || len(list.Items) != 1 || list.Items[0].ID != "comprova-1" {
		t.Fatalf("checks = %+v", list)
	}
	it := list.Items[0]
	if it.Publisher != "Projeto Comprova" || it.License != "CC BY-ND 4.0" || it.LicenseURL != "https://creativecommons.org/licenses/by-nd/4.0/deed.pt-br" || it.Verdict == nil || *it.Verdict != "Falso" {
		t.Fatalf("item = %+v", it)
	}
	if len(list.Sources) != 1 || list.Sources[0].ID != "comprova" {
		t.Fatalf("sources = %+v", list.Sources)
	}
	if len(out.Reviews) != 1 || out.Reviews[0].Reason != ReviewAmbiguousName || len(out.Reviews[0].Candidates) != 2 {
		t.Fatalf("reviews = %+v", out.Reviews)
	}
	tree := publish.NewTree(filepath.Join(t.TempDir(), "v1"))
	if err := Publish(out, tree, true); err != nil {
		t.Fatal(err)
	}
	ds.Checks = nil
	ds.GeneratedAt = ds.GeneratedAt.Add(time.Hour)
	if out := Build(ds, reg); len(out.Reviews) != 0 {
		t.Fatalf("reviews without checks = %+v", out.Reviews)
	}
}
