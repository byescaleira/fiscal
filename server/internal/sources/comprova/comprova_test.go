package comprova

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

type pageGetter struct {
	t     *testing.T
	pages []string
	calls []url.Values
	fail  error
}

func (g *pageGetter) JSONHeader(_ context.Context, raw string, v any) (http.Header, error) {
	if g.fail != nil {
		return nil, g.fail
	}
	u, err := url.Parse(raw)
	if err != nil {
		return nil, err
	}
	if u.Scheme+"://"+u.Host+u.Path != APIURL {
		g.t.Fatalf("unexpected url %s", raw)
	}
	q := u.Query()
	g.calls = append(g.calls, q)
	n := 0
	for i, p := range g.pages {
		if q.Get("page") == string(rune('1'+i)) {
			n = i + 1
			data, err := os.ReadFile(filepath.Join("testdata", p))
			if err != nil {
				g.t.Fatal(err)
			}
			if err := json.Unmarshal(data, v); err != nil {
				g.t.Fatal(err)
			}
		}
	}
	if n == 0 {
		g.t.Fatalf("page out of range: %s", raw)
	}
	h := http.Header{}
	h.Set("X-WP-TotalPages", string(rune('0'+len(g.pages))))
	return h, nil
}

func byID(s Store) map[int64]Check {
	out := map[int64]Check{}
	for _, c := range s.Checks {
		out[c.ID] = c
	}
	return out
}

func verdict(c Check) string {
	if c.Verdict == nil {
		return "<nil>"
	}
	return *c.Verdict
}

func TestFullLoadReadsEveryPageAndExtractsTheSeal(t *testing.T) {
	now := time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)
	g := &pageGetter{t: t, pages: []string{"page1.json", "page2.json"}}
	c := Client{Get: g, Now: func() time.Time { return now }}
	s, st, err := c.Update(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if !st.Full || st.Pages != 2 || st.Fetched != 9 || st.Skipped != 2 {
		t.Fatalf("stats = %+v", st)
	}
	if s.Since != DefaultSince || s.CompleteAt != "2026-10-25T18:00:00Z" || len(s.Checks) != 7 {
		t.Fatalf("store = %+v", s)
	}
	first := g.calls[0]
	if first.Get("per_page") != "100" || first.Get("after") != "2022-01-01T00:00:00" || first.Get("orderby") != "id" || first.Get("modified_after") != "" {
		t.Fatalf("query = %v", first)
	}
	got := byID(s)
	want := map[int64]string{101: Falso, 102: Enganoso, 103: Contextualizando, 104: "<nil>", 105: "<nil>", 108: Comprovado, 109: Satira}
	for id, w := range want {
		if verdict(got[id]) != w {
			t.Errorf("verdict %d = %s, want %s", id, verdict(got[id]), w)
		}
	}
	if !reflect.DeepEqual(got[104].Conflict, []string{Enganoso, Falso}) {
		t.Fatalf("conflict = %v", got[104].Conflict)
	}
	if _, ok := got[106]; ok {
		t.Fatal("institutional post kept")
	}
	if _, ok := got[107]; ok {
		t.Fatal("post outside the site kept")
	}
	ch := got[102]
	if ch.Title != "Vídeo tira de contexto fala de Lula sobre ‘picanha’" || ch.Date != "2022-10-06" {
		t.Fatalf("check = %+v", ch)
	}
	if ch.URL != "https://projetocomprova.com.br/publica%C3%A7%C3%B5es/video-tira-de-contexto/" {
		t.Fatalf("url = %s", ch.URL)
	}
	if !reflect.DeepEqual(got[101].Explanations, []string{"Áudio atribuído à equipe de Flávio Bolsonaro foi feito com IA."}) {
		t.Fatalf("explanations = %v", got[101].Explanations)
	}
	if got[108].Title != "É verídica nota fiscal com imposto de R$ 31,45 sobre produto" {
		t.Fatalf("title = %q", got[108].Title)
	}
}

func TestIncrementalLoadAsksOnlyForModifiedPosts(t *testing.T) {
	now := time.Date(2026, 10, 26, 9, 0, 0, 0, time.UTC)
	prev := &Store{Since: DefaultSince, CompleteAt: "2026-10-25T18:00:00Z", Checks: []Check{
		{ID: 50, Date: "2026-01-01", Modified: "2026-10-24T20:00:00", URL: "https://projetocomprova.com.br/a/", Title: "Antiga"},
		{ID: 101, Date: "2026-10-23", Modified: "2026-10-23T13:30:00", URL: "https://projetocomprova.com.br/b/", Title: "Versão anterior"},
		{ID: 106, Date: "2026-10-22", Modified: "2026-10-22T11:00:00", URL: "https://projetocomprova.com.br/c/", Title: "Virou comunicado"},
	}}
	g := &pageGetter{t: t, pages: []string{"page1.json"}}
	c := Client{Get: g, Now: func() time.Time { return now }}
	s, st, err := c.Update(context.Background(), prev)
	if err != nil {
		t.Fatal(err)
	}
	if st.Full || st.Pages != 1 {
		t.Fatalf("stats = %+v", st)
	}
	q := g.calls[0]
	if q.Get("modified_after") != "2026-10-24T19:00:00" || q.Get("dates_are_gmt") != "true" {
		t.Fatalf("query = %v", q)
	}
	got := byID(s)
	if got[50].Title != "Antiga" || got[101].Title == "Versão anterior" {
		t.Fatalf("merge = %+v", s.Checks)
	}
	if _, ok := got[106]; ok {
		t.Fatal("a post that became institutional must leave the store")
	}
	if s.CompleteAt != prev.CompleteAt {
		t.Fatalf("completeAt = %s", s.CompleteAt)
	}
}

func TestStaleOrPartialStoreTriggersAFullLoad(t *testing.T) {
	now := time.Date(2026, 11, 5, 9, 0, 0, 0, time.UTC)
	c := Client{Now: func() time.Time { return now }}
	cases := []*Store{
		nil,
		{Since: DefaultSince},
		{Since: "2024-01-01", CompleteAt: "2026-11-04T09:00:00Z"},
		{Since: DefaultSince, CompleteAt: "2026-10-25T09:00:00Z"},
	}
	for i, s := range cases {
		if !c.needsFull(s) {
			t.Errorf("case %d should be full", i)
		}
	}
	if c.needsFull(&Store{Since: DefaultSince, CompleteAt: "2026-11-04T09:00:00Z"}) {
		t.Fatal("a fresh complete store should be incremental")
	}
}

func TestMaxPagesLeavesTheStoreIncomplete(t *testing.T) {
	g := &pageGetter{t: t, pages: []string{"page1.json", "page2.json"}}
	s, st, err := Client{Get: g, MaxPages: 1}.Update(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if st.Pages != 1 || s.CompleteAt != "" {
		t.Fatalf("stats = %+v store = %+v", st, s)
	}
}

func TestUpdateFailsOnFetchError(t *testing.T) {
	g := &pageGetter{t: t, fail: errors.New("boom")}
	if _, _, err := (Client{Get: g}).Update(context.Background(), nil); err == nil {
		t.Fatal("expected error")
	}
	if _, _, err := (Client{Get: g, Since: "ontem"}).Update(context.Background(), nil); err == nil {
		t.Fatal("expected invalid date error")
	}
}

func TestVerdictsNeverGuess(t *testing.T) {
	cases := []struct {
		tags    []rawTag
		content string
		images  []string
		want    []string
	}{
		{nil, "<p>Texto sobre falso e enganoso sem marcador.</p>", nil, []string{}},
		{[]rawTag{{Tag: "Política"}}, "", []string{"https://projetocomprova.com.br/x/02-Site-com-mascara-A-Video.jpg"}, []string{}},
		{[]rawTag{{Tag: "Golpes virtuais"}}, "", []string{"https://projetocomprova.com.br/x/02-Site-GOLPE-Pix.png"}, []string{Golpe}},
		{[]rawTag{{Tag: "Comprova Explica"}}, "<p><strong>Comprova Explica</strong>: texto</p>", []string{"https://projetocomprova.com.br/x/02-Site-EXPLICA-Urna.png"}, []string{ComprovaExplica}},
		{nil, "<p>Falso, para o Comprova, é conteúdo inventado. Enganoso, para o Comprova, é conteúdo fora de contexto.</p>", nil, []string{Enganoso, Falso}},
		{nil, "", []string{"https://projetocomprova.com.br/x/02-Site-CONTEXTUALIZANDOCury.png"}, []string{Contextualizando}},
		{nil, "", []string{"https://projetocomprova.com.br/x/02-Site-VERDADEIRO-Dicas.png"}, []string{Verdadeiro}},
		{nil, "<p>O post é falso, para o Comprova</p>", nil, []string{}},
	}
	for i, c := range cases {
		got := Verdicts(c.tags, c.content, c.images)
		if !reflect.DeepEqual(got, c.want) {
			t.Errorf("case %d: got %v want %v", i, got, c.want)
		}
	}
}

func TestCanonicalURL(t *testing.T) {
	cases := map[string]string{
		"https://projetocomprova.com.br/publicações/x/?utm=1#a": "https://projetocomprova.com.br/publica%C3%A7%C3%B5es/x/",
		"http://projetocomprova.com.br/publicações/x/":          "",
		"https://projetocomprova.com.br.evil.example/x/":        "",
		"https://user@projetocomprova.com.br/x/":                "",
		"https://projetocomprova.com.br/":                       "",
		"javascript:alert(1)":                                   "",
	}
	for in, want := range cases {
		got, ok := CanonicalURL(in)
		if got != want || ok != (want != "") {
			t.Errorf("%q: got %q %v", in, got, ok)
		}
	}
}

func TestStoreRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sub", "comprova.json")
	if s, err := LoadStore(path); err != nil || s != nil {
		t.Fatalf("missing store: %v %v", s, err)
	}
	v := Falso
	in := Store{Since: DefaultSince, CompleteAt: "2026-10-25T18:00:00Z", Checks: []Check{{ID: 1, Title: "a", Verdict: &v}}}
	if err := SaveStore(path, in); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(path)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %v %v", info, err)
	}
	out, err := LoadStore(path)
	if err != nil || !reflect.DeepEqual(*out, in) {
		t.Fatalf("round trip = %+v %v", out, err)
	}
}
