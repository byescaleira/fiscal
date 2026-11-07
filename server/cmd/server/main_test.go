package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func envFrom(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestConfigDefaults(t *testing.T) {
	c, err := loadConfig(envFrom(map[string]string{}))
	if err != nil {
		t.Fatal(err)
	}
	if c.host != "127.0.0.1" || c.port != "3130" || c.dataDir != "./data" || c.publicDir != "./public" || c.poll != 20*time.Second || c.tseBase != "https://resultados.tse.jus.br/oficial/ele2026" || c.simulate {
		t.Fatalf("defaults %+v", c)
	}
	c, err = loadConfig(envFrom(map[string]string{"POLL_INTERVAL": "30"}))
	if err != nil || c.poll != 30*time.Second {
		t.Fatalf("config %+v %v", c, err)
	}
}

func TestConfigRejectsInvalidValues(t *testing.T) {
	bad := []map[string]string{
		{"POLL_INTERVAL": "1s"},
		{"POLL_INTERVAL": "abc"},
		{"PORT": "99999"},
		{"TSE_BASE_URL": "file:///etc"},
		{"TSE_BASE_URL": "http://resultados.tse.jus.br/oficial/ele2026"},
		{"TSE_BASE_URL": "https://"},
		{"TSE_BASE_URL": "ftp://x", "SIMULATE": "1"},
	}
	for _, m := range bad {
		if _, err := loadConfig(envFrom(m)); err == nil {
			t.Errorf("expected error for %v", m)
		}
	}
	c, err := loadConfig(envFrom(map[string]string{"TSE_BASE_URL": "http://127.0.0.1:9000", "SIMULATE": "1"}))
	if err != nil || c.tseBase != "http://127.0.0.1:9000" {
		t.Fatalf("http must be allowed with SIMULATE=1: %v", err)
	}
}

func TestSimulateNeverPublishes(t *testing.T) {
	sim, _ := loadConfig(envFrom(map[string]string{"SIMULATE": "1", "PUBLIC_DIR": "/public"}))
	if sim.publishDir() != "" {
		t.Fatalf("simulate must not publish, got %q", sim.publishDir())
	}
	tseCfg, _ := loadConfig(envFrom(map[string]string{"PUBLIC_DIR": "/public"}))
	if tseCfg.publishDir() != "/public" {
		t.Fatalf("tse mode must publish to PUBLIC_DIR, got %q", tseCfg.publishDir())
	}
}

func TestCheck(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/health" {
			w.Write([]byte(`{"ok":true}`))
			return
		}
		w.WriteHeader(500)
	}))
	defer srv.Close()
	if runCheck(srv.URL+"/api/health") != 0 {
		t.Fatal("healthy server must return 0")
	}
	if runCheck(srv.URL+"/other") != 1 {
		t.Fatal("failing server must return 1")
	}
	if checkAddress("0.0.0.0", "3130") != "http://127.0.0.1:3130/api/health" || checkAddress("", "1") != "http://127.0.0.1:1/api/health" {
		t.Fatal(checkAddress("0.0.0.0", "3130"))
	}
}
