package httpapi

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type env struct {
	h    http.Handler
	logs *bytes.Buffer
}

func newEnv(t *testing.T) *env {
	t.Helper()
	now := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	e := &env{logs: &bytes.Buffer{}}
	e.h = New(Config{Now: func() time.Time { return now }, Logger: log.New(e.logs, "", 0)})
	return e
}

func (e *env) do(method, path, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.RemoteAddr = "127.0.0.1:5555"
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

func TestHealthReportsVersion(t *testing.T) {
	h := New(Config{Version: "1.2.3", Logger: log.New(io.Discard, "", 0)})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/api/health", nil))
	var body struct {
		OK      bool   `json:"ok"`
		Version string `json:"version"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil || rec.Code != 200 || !body.OK || body.Version != "1.2.3" {
		t.Fatalf("health %d %s", rec.Code, rec.Body.String())
	}
}

func TestHealthAndHeaders(t *testing.T) {
	e := newEnv(t)
	rec := e.do("GET", "/api/health", "")
	if rec.Code != 200 || strings.TrimSpace(rec.Body.String()) != `{"ok":true,"version":"dev"}` {
		t.Fatalf("health %d %s", rec.Code, rec.Body.String())
	}
	if rec.Header().Get("Cache-Control") != "no-store" || rec.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatal("missing headers")
	}
	rec = e.do("GET", "/nope", "")
	if rec.Code != 404 || errorCode(t, rec) != "not_found" || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("not found %d", rec.Code)
	}
}

func TestPublicRoutesAreGone(t *testing.T) {
	e := newEnv(t)
	tok := strings.Repeat("abcdef0123", 7)
	for _, tc := range []struct{ method, path, body string }{
		{"POST", "/api/v1/highlight-activities", `{"pushToken":"` + tok + `","environment":"production"}`},
		{"DELETE", "/api/v1/highlight-activities", `{"pushToken":"` + tok + `"}`},
		{"POST", "/api/v1/live-activities", `{"raceId":"presidente-br","pushToken":"` + tok + `","environment":"production"}`},
		{"DELETE", "/api/v1/live-activities", `{"pushToken":"` + tok + `"}`},
		{"POST", "/api/v1/attest/challenge", ""},
		{"POST", "/api/v1/attest/keys", `{"keyId":"k","attestation":"a","challenge":"c"}`},
		{"GET", "/api/v1/races", ""},
		{"GET", "/api/v1/races/presidente-br", ""},
		{"POST", "/api/v1/admin/push-test", `{"raceId":"presidente-br"}`},
	} {
		rec := e.do(tc.method, tc.path, tc.body)
		if rec.Code != http.StatusNotFound || errorCode(t, rec) != "not_found" {
			t.Errorf("%s %s = %d %s, want 404", tc.method, tc.path, rec.Code, rec.Body.String())
		}
	}
	if rec := e.do("GET", "/api/health", ""); rec.Code != http.StatusOK {
		t.Fatalf("health %d", rec.Code)
	}
	if strings.Contains(e.logs.String(), tok) {
		t.Fatalf("token leaked in logs: %s", e.logs.String())
	}
}

func TestOldDeleteRouteStaysRedacted(t *testing.T) {
	e := newEnv(t)
	tok := strings.Repeat("abcdef0123", 7)
	rec := e.do("DELETE", "/api/v1/live-activities/"+tok, "")
	if rec.Code != 404 || errorCode(t, rec) != "not_found" {
		t.Fatalf("old route %d", rec.Code)
	}
	logs := e.logs.String()
	if strings.Contains(logs, tok) || strings.Contains(logs, tok[:7]) {
		t.Fatalf("token leaked in logs: %s", logs)
	}
	if !strings.Contains(logs, "DELETE /api/v1/live-activities/abcdef… 404") {
		t.Fatalf("log lines %s", logs)
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
