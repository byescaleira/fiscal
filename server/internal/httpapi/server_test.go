package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"liveresults/internal/live"
	"liveresults/internal/store"
	"liveresults/internal/tse"
)

type fakeRaces struct {
	races  []tse.Race
	at     time.Time
	pushed []string
}

func (f *fakeRaces) Snapshot() ([]tse.Race, time.Time) { return f.races, f.at }

func (f *fakeRaces) Race(id string) (tse.Race, bool) {
	for _, r := range f.races {
		if r.ID == id {
			return r, true
		}
	}
	return tse.Race{}, false
}

func (f *fakeRaces) PushRace(_ context.Context, id string) (live.Stats, error) {
	if _, ok := f.Race(id); !ok {
		return live.Stats{}, live.ErrNotReady
	}
	f.pushed = append(f.pushed, id)
	return live.Stats{Registrations: 1, Sent: 1, Event: "update"}, nil
}

type fakeRegs struct {
	mu      sync.Mutex
	put     []store.Registration
	deleted []string
	err     error
}

func (f *fakeRegs) Put(r store.Registration) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return f.err
	}
	f.put = append(f.put, r)
	return nil
}

func (f *fakeRegs) Delete(t string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.deleted = append(f.deleted, t)
	return true
}

type env struct {
	h     http.Handler
	races *fakeRaces
	regs  *fakeRegs
	logs  *bytes.Buffer
	now   *time.Time
}

func newEnv(t *testing.T, admin string) *env {
	t.Helper()
	now := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	e := &env{races: &fakeRaces{}, regs: &fakeRegs{}, logs: &bytes.Buffer{}, now: &now}
	clock := func() time.Time { return *e.now }
	e.h = New(Config{Races: e.races, Registrations: e.regs, AdminToken: admin, Now: clock, Logger: log.New(e.logs, "", 0)})
	return e
}

func (e *env) do(method, path, body string, hdr map[string]string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.RemoteAddr = "10.0.0.1:5555"
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body struct {
		Error struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("error body %q: %v", rec.Body.String(), err)
	}
	if body.Error.Message == "" {
		t.Fatalf("missing message in %s", rec.Body.String())
	}
	return body.Error.Code
}

func TestHealthAndHeaders(t *testing.T) {
	e := newEnv(t, "")
	rec := e.do("GET", "/api/health", "", nil)
	if rec.Code != 200 || strings.TrimSpace(rec.Body.String()) != `{"ok":true}` {
		t.Fatalf("health %d %s", rec.Code, rec.Body.String())
	}
	if rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("missing no-store")
	}
	rec = e.do("GET", "/nope", "", nil)
	if rec.Code != 404 || errorCode(t, rec) != "not_found" || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("not found %d", rec.Code)
	}
}

func TestRaces(t *testing.T) {
	e := newEnv(t, "")
	rec := e.do("GET", "/api/v1/races", "", nil)
	if rec.Code != 503 || errorCode(t, rec) != "not_ready" {
		t.Fatalf("empty races %d", rec.Code)
	}
	if rec := e.do("GET", "/api/v1/races/presidente-br", "", nil); rec.Code != 503 || errorCode(t, rec) != "not_ready" {
		t.Fatalf("race before data %d", rec.Code)
	}
	if rec := e.do("GET", "/api/v1/races/senador-sp", "", nil); rec.Code != 404 || errorCode(t, rec) != "race_not_found" {
		t.Fatalf("unknown race %d", rec.Code)
	}
	e.races.races = []tse.Race{{ID: "presidente-br", Office: "president", UF: "br", Round: 2, Candidates: []tse.Candidate{}}}
	e.races.at = time.Date(2026, 10, 25, 20, 0, 20, 0, time.UTC)
	rec = e.do("GET", "/api/v1/races", "", nil)
	if rec.Code != 200 {
		t.Fatalf("races %d", rec.Code)
	}
	var list struct {
		Races     []map[string]any `json:"races"`
		FetchedAt string           `json:"fetchedAt"`
	}
	json.Unmarshal(rec.Body.Bytes(), &list)
	if len(list.Races) != 1 || list.FetchedAt != "2026-10-25T20:00:20Z" || list.Races[0]["sourceGeneratedAt"] != "" {
		t.Fatalf("list %s", rec.Body.String())
	}
	for _, k := range []string{"id", "office", "uf", "round", "sections", "electorate", "turnout", "votes", "candidates", "final", "sourceGeneratedAt"} {
		if _, ok := list.Races[0][k]; !ok {
			t.Errorf("missing key %s", k)
		}
	}
	if rec := e.do("GET", "/api/v1/races/presidente-br", "", nil); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"id":"presidente-br"`) {
		t.Fatalf("race %d %s", rec.Code, rec.Body.String())
	}
}

func TestRegisterValidation(t *testing.T) {
	tok := strings.Repeat("aB", 32)
	cases := []struct {
		name   string
		body   string
		status int
		code   string
	}{
		{"ok", `{"raceId":"presidente-br","pushToken":"` + tok + `","environment":"development"}`, 204, ""},
		{"production", `{"raceId":"governador-to","pushToken":"` + strings.Repeat("0", 400) + `","environment":"production"}`, 204, ""},
		{"unknown race", `{"raceId":"senador-sp","pushToken":"` + tok + `","environment":"development"}`, 422, "invalid_request"},
		{"non hex", `{"raceId":"presidente-br","pushToken":"` + strings.Repeat("zz", 32) + `","environment":"development"}`, 422, "invalid_request"},
		{"short", `{"raceId":"presidente-br","pushToken":"` + strings.Repeat("a", 31) + `","environment":"development"}`, 422, "invalid_request"},
		{"long", `{"raceId":"presidente-br","pushToken":"` + strings.Repeat("a", 401) + `","environment":"development"}`, 422, "invalid_request"},
		{"bad env", `{"raceId":"presidente-br","pushToken":"` + tok + `","environment":"staging"}`, 422, "invalid_request"},
		{"missing env", `{"raceId":"presidente-br","pushToken":"` + tok + `"}`, 422, "invalid_request"},
		{"not json", `hello`, 422, "invalid_request"},
		{"too large", `{"raceId":"presidente-br","pad":"` + strings.Repeat("x", 5000) + `"}`, 413, "body_too_large"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			e := newEnv(t, "")
			rec := e.do("POST", "/api/v1/live-activities", tc.body, nil)
			if rec.Code != tc.status {
				t.Fatalf("status %d, want %d: %s", rec.Code, tc.status, rec.Body.String())
			}
			if tc.code != "" && errorCode(t, rec) != tc.code {
				t.Fatalf("code mismatch: %s", rec.Body.String())
			}
			if tc.status == 204 && (len(e.regs.put) != 1 || e.regs.put[0].PushToken != strings.ToLower(e.regs.put[0].PushToken)) {
				t.Fatalf("stored %+v", e.regs.put)
			}
			if tc.status != 204 && len(e.regs.put) != 0 {
				t.Fatal("invalid request stored")
			}
		})
	}
}

func TestRegisterCapacity(t *testing.T) {
	e := newEnv(t, "")
	e.regs.err = store.ErrCapacity
	rec := e.do("POST", "/api/v1/live-activities", `{"raceId":"presidente-br","pushToken":"`+strings.Repeat("a", 64)+`","environment":"development"}`, nil)
	if rec.Code != 507 || errorCode(t, rec) != "capacity_reached" {
		t.Fatalf("capacity %d %s", rec.Code, rec.Body.String())
	}
}

func TestUnregisterTakesTheTokenInTheBody(t *testing.T) {
	tok := strings.Repeat("ABCDEF0123", 7)
	cases := []struct {
		name   string
		body   string
		status int
		code   string
	}{
		{"ok", `{"pushToken":"` + tok + `"}`, 204, ""},
		{"unknown token still 204", `{"pushToken":"` + strings.Repeat("0", 64) + `"}`, 204, ""},
		{"missing", `{}`, 422, "invalid_request"},
		{"non hex", `{"pushToken":"` + strings.Repeat("zz", 32) + `"}`, 422, "invalid_request"},
		{"short", `{"pushToken":"` + strings.Repeat("a", 31) + `"}`, 422, "invalid_request"},
		{"not json", `hello`, 422, "invalid_request"},
		{"empty body", ``, 422, "invalid_request"},
		{"too large", `{"pushToken":"` + strings.Repeat("a", 5000) + `"}`, 413, "body_too_large"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			e := newEnv(t, "")
			rec := e.do("DELETE", "/api/v1/live-activities", tc.body, nil)
			if rec.Code != tc.status {
				t.Fatalf("status %d, want %d: %s", rec.Code, tc.status, rec.Body.String())
			}
			if tc.code != "" && errorCode(t, rec) != tc.code {
				t.Fatalf("code mismatch: %s", rec.Body.String())
			}
			if tc.status == 204 && (len(e.regs.deleted) != 1 || e.regs.deleted[0] != strings.ToLower(e.regs.deleted[0])) {
				t.Fatalf("deleted %v", e.regs.deleted)
			}
			if tc.status != 204 && len(e.regs.deleted) != 0 {
				t.Fatal("invalid request deleted")
			}
		})
	}
	e := newEnv(t, "")
	e.do("DELETE", "/api/v1/live-activities", `{"pushToken":"`+tok+`"}`, nil)
	if e.regs.deleted[0] != strings.ToLower(tok) {
		t.Fatalf("deleted %v", e.regs.deleted)
	}
}

func TestOldDeleteRouteIsGoneAndStaysRedacted(t *testing.T) {
	e := newEnv(t, "")
	tok := strings.Repeat("abcdef0123", 7)
	rec := e.do("DELETE", "/api/v1/live-activities/"+tok, "", nil)
	if rec.Code != 404 || errorCode(t, rec) != "not_found" || len(e.regs.deleted) != 0 {
		t.Fatalf("old route %d %v", rec.Code, e.regs.deleted)
	}
	e.do("DELETE", "/api/v1/live-activities", `{"pushToken":"`+tok+`"}`, nil)
	e.do("POST", "/api/v1/live-activities", `{"raceId":"presidente-br","pushToken":"`+tok+`","environment":"development"}`, nil)
	logs := e.logs.String()
	if strings.Contains(logs, tok) || strings.Contains(logs, tok[:7]) {
		t.Fatalf("token leaked in logs: %s", logs)
	}
	if !strings.Contains(logs, "DELETE /api/v1/live-activities/abcdef… 404") || !strings.Contains(logs, "DELETE /api/v1/live-activities 204") {
		t.Fatalf("log lines %s", logs)
	}
}

func TestRateLimit(t *testing.T) {
	e := newEnv(t, "")
	for i := 0; i < 120; i++ {
		if rec := e.do("GET", "/api/v1/races/senador-sp", "", map[string]string{"X-Forwarded-For": "6.6.6.6, 1.2.3.4"}); rec.Code == 429 {
			t.Fatalf("limited at %d", i)
		}
	}
	rec := e.do("GET", "/api/v1/races/senador-sp", "", map[string]string{"X-Forwarded-For": "9.9.9.9, 1.2.3.4"})
	if rec.Code != 429 || errorCode(t, rec) != "rate_limited" || rec.Header().Get("Retry-After") != "60" {
		t.Fatalf("expected 429 keyed on the last forwarded address, got %d", rec.Code)
	}
	if rec := e.do("GET", "/api/v1/races/senador-sp", "", map[string]string{"X-Forwarded-For": "1.2.3.5"}); rec.Code == 429 {
		t.Fatal("other ip limited")
	}
	if rec := e.do("GET", "/api/health", "", map[string]string{"X-Forwarded-For": "1.2.3.4"}); rec.Code != 200 {
		t.Fatal("health must not be limited")
	}
	del := `{"pushToken":"` + strings.Repeat("a", 64) + `"}`
	for i := 0; i < 120; i++ {
		if rec := e.do("DELETE", "/api/v1/live-activities", del, map[string]string{"X-Forwarded-For": "1.2.3.4"}); rec.Code != 204 {
			t.Fatalf("write %d limited early: %d", i, rec.Code)
		}
	}
	if rec := e.do("POST", "/api/v1/live-activities", `{}`, map[string]string{"X-Forwarded-For": "1.2.3.4"}); rec.Code != 429 {
		t.Fatalf("121st write must be limited, got %d", rec.Code)
	}
	*e.now = e.now.Add(time.Minute)
	if rec := e.do("GET", "/api/v1/races/senador-sp", "", map[string]string{"X-Forwarded-For": "1.2.3.4"}); rec.Code == 429 {
		t.Fatal("window must reset")
	}
}

func TestRateLimiterEvictsOldestWhenFull(t *testing.T) {
	now := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	l := NewRateLimiter(func() time.Time { return now }, 1, 1)
	l.max = 2
	if !l.Allow("a", ClassRead) {
		t.Fatal("a")
	}
	now = now.Add(time.Second)
	if !l.Allow("b", ClassRead) {
		t.Fatal("b")
	}
	now = now.Add(time.Second)
	if !l.Allow("c", ClassRead) {
		t.Fatal("a new address must be accepted when the map is full")
	}
	if len(l.buckets) != 2 || l.order.Len() != 2 {
		t.Fatalf("buckets %d", len(l.buckets))
	}
	if l.Allow("b", ClassRead) || l.Allow("c", ClassRead) {
		t.Fatal("newer buckets must be kept")
	}
	if !l.Allow("a", ClassRead) {
		t.Fatal("oldest bucket must have been evicted")
	}
	now = now.Add(time.Minute)
	l.Allow("d", ClassRead)
	if len(l.buckets) != 1 {
		t.Fatalf("expired buckets must be swept, have %d", len(l.buckets))
	}
}

func TestClientIP(t *testing.T) {
	cases := []struct {
		remote string
		xff    []string
		want   string
	}{
		{"127.0.0.1:1234", nil, "127.0.0.1"},
		{"127.0.0.1:1234", []string{"1.1.1.1, 2.2.2.2", "3.3.3.3 "}, "3.3.3.3"},
		{"172.17.0.1:1234", []string{"4.4.4.4"}, "4.4.4.4"},
		{"10.1.2.3:1234", []string{"4.4.4.4"}, "4.4.4.4"},
		{"192.168.1.1:1234", []string{"4.4.4.4"}, "4.4.4.4"},
		{"[fd00::1]:1234", []string{"4.4.4.4"}, "4.4.4.4"},
		{"[::1]:1234", []string{"4.4.4.4"}, "4.4.4.4"},
		{"[::ffff:10.0.0.1]:1234", []string{"4.4.4.4"}, "4.4.4.4"},
		{"8.8.8.8:1234", []string{"4.4.4.4"}, "8.8.8.8"},
		{"172.32.0.1:1234", []string{"4.4.4.4"}, "172.32.0.1"},
		{"[2001:db8::1]:1234", []string{"4.4.4.4"}, "2001:db8::/64"},
		{"127.0.0.1:1234", []string{"2001:db8:1:2:aaaa::1"}, "2001:db8:1:2::/64"},
		{"127.0.0.1:1234", []string{"2001:db8:1:2:bbbb::9"}, "2001:db8:1:2::/64"},
		{"127.0.0.1:1234", []string{"::ffff:5.5.5.5"}, "5.5.5.5"},
		{"127.0.0.1:1234", []string{"garbage"}, "127.0.0.1"},
	}
	for _, tc := range cases {
		r := httptest.NewRequest("GET", "/", nil)
		r.RemoteAddr = tc.remote
		for _, v := range tc.xff {
			r.Header.Add("X-Forwarded-For", v)
		}
		if got := ClientIP(r); got != tc.want {
			t.Errorf("remote %s xff %v: got %s, want %s", tc.remote, tc.xff, got, tc.want)
		}
	}
}

type storeEnv struct {
	h   http.Handler
	st  *store.Store
	now *time.Time
}

func newStoreEnv(t *testing.T, perSource int) *storeEnv {
	t.Helper()
	now := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	e := &storeEnv{now: &now}
	clock := func() time.Time { return *e.now }
	st, err := store.Open(t.TempDir(), store.Options{Max: 1000, PerSource: perSource, Now: clock})
	if err != nil {
		t.Fatal(err)
	}
	e.st = st
	e.h = New(Config{Races: &fakeRaces{}, Registrations: st, Now: clock, Limiter: NewRateLimiter(clock, 1000, 1000), Logger: log.New(io.Discard, "", 0)})
	return e
}

func (e *storeEnv) register(race, tok, env, forwarded string) *httptest.ResponseRecorder {
	req := httptest.NewRequest("POST", "/api/v1/live-activities", strings.NewReader(`{"raceId":"`+race+`","pushToken":"`+tok+`","environment":"`+env+`"}`))
	req.RemoteAddr = "127.0.0.1:5555"
	req.Header.Set("X-Forwarded-For", forwarded)
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

func hexToken(i int) string {
	return fmt.Sprintf("%064x", i+1)
}

func TestRegistrationCapPerAddress(t *testing.T) {
	e := newStoreEnv(t, 20)
	for i := 0; i < 20; i++ {
		if rec := e.register("presidente-br", hexToken(i), "development", "200.1.1.1"); rec.Code != 204 {
			t.Fatalf("registration %d: %d %s", i, rec.Code, rec.Body.String())
		}
	}
	rec := e.register("presidente-br", hexToken(20), "development", "200.1.1.1")
	if rec.Code != 429 || errorCode(t, rec) != "too_many_registrations" {
		t.Fatalf("21st registration %d %s", rec.Code, rec.Body.String())
	}
	if rec := e.register("presidente-br", hexToken(0), "development", "200.1.1.1"); rec.Code != 204 {
		t.Fatalf("renewal at the cap %d", rec.Code)
	}
	if rec := e.register("presidente-br", hexToken(20), "development", "200.1.1.2"); rec.Code != 204 {
		t.Fatalf("other address %d", rec.Code)
	}
	for i := 0; i < 20; i++ {
		if rec := e.register("presidente-br", hexToken(100+i), "development", fmt.Sprintf("2001:db8:7:7::%x", i+1)); rec.Code != 204 {
			t.Fatalf("ipv6 %d: %d", i, rec.Code)
		}
	}
	if rec := e.register("presidente-br", hexToken(200), "development", "2001:db8:7:7:ffff::1"); rec.Code != 429 {
		t.Fatalf("same /64 must share the cap, got %d", rec.Code)
	}
	*e.now = e.now.Add(store.DefaultTTL)
	e.st.Flush()
	if rec := e.register("presidente-br", hexToken(300), "development", "200.1.1.1"); rec.Code != 204 {
		t.Fatalf("expired registrations must free the cap, got %d", rec.Code)
	}
	for _, r := range e.st.ForRace("presidente-br") {
		if r.Source == "" || strings.Contains(r.Source, "200.1.1.1") || len(r.Source) != 32 {
			t.Fatalf("source must be a truncated hash, got %q", r.Source)
		}
	}
}

func TestSourceHashUsesBootSalt(t *testing.T) {
	a := &server{salt: []byte("one")}
	b := &server{salt: []byte("two")}
	if a.sourceKey("200.1.1.1") == b.sourceKey("200.1.1.1") || a.sourceKey("200.1.1.1") != a.sourceKey("200.1.1.1") {
		t.Fatal("hash must depend on the salt and be stable within a boot")
	}
	body := `{"raceId":"presidente-br","pushToken":"` + hexToken(1) + `","environment":"development"}`
	fwd := map[string]string{"X-Forwarded-For": "200.1.1.1"}
	first, second := newEnv(t, ""), newEnv(t, "")
	first.do("POST", "/api/v1/live-activities", body, fwd)
	first.do("POST", "/api/v1/live-activities", body, fwd)
	second.do("POST", "/api/v1/live-activities", body, fwd)
	if len(first.regs.put) != 2 || len(second.regs.put) != 1 {
		t.Fatal("registrations not recorded")
	}
	if first.regs.put[0].Source != first.regs.put[1].Source || first.regs.put[0].Source == second.regs.put[0].Source {
		t.Fatal("each boot must draw its own random salt")
	}
}

func TestTokenStaysBoundToItsRace(t *testing.T) {
	e := newStoreEnv(t, 20)
	tok := hexToken(1)
	if rec := e.register("presidente-br", tok, "development", "200.1.1.1"); rec.Code != 204 {
		t.Fatalf("first %d", rec.Code)
	}
	for _, tc := range []struct{ race, env string }{{"governador-df", "development"}, {"presidente-br", "production"}} {
		rec := e.register(tc.race, tok, tc.env, "200.9.9.9")
		if rec.Code != 409 || errorCode(t, rec) != "token_bound_to_other_race" {
			t.Fatalf("%v: %d %s", tc, rec.Code, rec.Body.String())
		}
	}
	got := e.st.ForRace("presidente-br")
	if len(got) != 1 || got[0].Environment != "development" || len(e.st.ForRace("governador-df")) != 0 {
		t.Fatalf("original changed %+v", got)
	}
}

func TestRecoverPanicsReturns500(t *testing.T) {
	var logs bytes.Buffer
	s := &server{logger: log.New(&logs, "", 0)}
	h := s.recoverPanics(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("boom") }))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != 500 || errorCode(t, rec) != "internal_error" {
		t.Fatalf("panic %d %s", rec.Code, rec.Body.String())
	}
}

func TestAdminPushTest(t *testing.T) {
	body := `{"raceId":"presidente-br"}`
	disabled := newEnv(t, "")
	for _, auth := range []string{"", "Bearer ", "Bearer x"} {
		if rec := disabled.do("POST", "/api/v1/admin/push-test", body, map[string]string{"Authorization": auth}); rec.Code != 404 {
			t.Fatalf("admin without token configured must be 404, got %d", rec.Code)
		}
	}
	secret := strings.Repeat("s", 40)
	e := newEnv(t, secret)
	for _, auth := range []string{"", "Bearer ", "Bearer x", secret, "bearer " + secret, "Bearer " + secret + "x"} {
		if rec := e.do("POST", "/api/v1/admin/push-test", body, map[string]string{"Authorization": auth}); rec.Code != 401 || errorCode(t, rec) != "unauthorized" {
			t.Fatalf("auth %q: %d", auth, rec.Code)
		}
	}
	ok := map[string]string{"Authorization": "Bearer " + secret}
	if rec := e.do("POST", "/api/v1/admin/push-test", body, ok); rec.Code != 503 {
		t.Fatalf("no data must be 503, got %d", rec.Code)
	}
	if rec := e.do("POST", "/api/v1/admin/push-test", `{"raceId":"x"}`, ok); rec.Code != 422 {
		t.Fatalf("unknown race %d", rec.Code)
	}
	e.races.races = []tse.Race{{ID: "presidente-br"}}
	rec := e.do("POST", "/api/v1/admin/push-test", body, ok)
	if rec.Code != 200 || len(e.races.pushed) != 1 {
		t.Fatalf("push test %d %s", rec.Code, rec.Body.String())
	}
	data, _ := io.ReadAll(rec.Body)
	if !strings.Contains(string(data), `"sent":1`) {
		t.Fatalf("stats %s", data)
	}
}

func TestAuthorizedAdminNeverMatchesEmpty(t *testing.T) {
	s := &server{}
	r := httptest.NewRequest("POST", "/", nil)
	if s.authorizedAdmin(r) {
		t.Fatal("empty token authorized")
	}
	r.Header.Set("Authorization", "Bearer ")
	if s.authorizedAdmin(r) {
		t.Fatal("empty bearer authorized")
	}
}
