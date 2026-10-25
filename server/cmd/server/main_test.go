package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func envFrom(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestConfigFailsClosedWithoutAPNs(t *testing.T) {
	_, err := loadConfig(envFrom(map[string]string{}))
	if err == nil || !strings.Contains(err.Error(), "APNS_KEY_FILE, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC required") {
		t.Fatalf("expected fail closed, got %v", err)
	}
	_, err = loadConfig(envFrom(map[string]string{"APNS_KEY_FILE": "/k", "APNS_KEY_ID": "K", "APNS_TEAM_ID": "T"}))
	if err == nil || !strings.Contains(err.Error(), "APNS_TOPIC") {
		t.Fatalf("expected APNS_TOPIC error, got %v", err)
	}
	_, err = loadConfig(envFrom(map[string]string{"APNS_KEY_FILE": "/k", "APNS_KEY_ID": "K", "APNS_TEAM_ID": "T", "APNS_TOPIC": "com.example.app"}))
	if err == nil || !strings.Contains(err.Error(), ".push-type.liveactivity") {
		t.Fatalf("expected topic suffix error, got %v", err)
	}
}

func TestConfigDefaults(t *testing.T) {
	c, err := loadConfig(envFrom(map[string]string{"APNS_DISABLED": "1"}))
	if err != nil {
		t.Fatal(err)
	}
	if c.host != "127.0.0.1" || c.port != "3130" || c.dataDir != "./data" || c.poll != 20*time.Second || c.tseBase != "https://resultados.tse.jus.br/oficial/ele2026" || c.simulate || c.adminToken != "" {
		t.Fatalf("defaults %+v", c)
	}
	c, err = loadConfig(envFrom(map[string]string{"APNS_KEY_FILE": "/k", "APNS_KEY_ID": "K", "APNS_TEAM_ID": "T", "APNS_TOPIC": "com.example.app.push-type.liveactivity", "POLL_INTERVAL": "30"}))
	if err != nil || c.poll != 30*time.Second {
		t.Fatalf("config %+v %v", c, err)
	}
}

func TestConfigRejectsInvalidValues(t *testing.T) {
	bad := []map[string]string{
		{"APNS_DISABLED": "1", "POLL_INTERVAL": "1s"},
		{"APNS_DISABLED": "1", "POLL_INTERVAL": "abc"},
		{"APNS_DISABLED": "1", "PORT": "99999"},
		{"APNS_DISABLED": "1", "ADMIN_TOKEN": "short"},
		{"APNS_DISABLED": "1", "TSE_BASE_URL": "file:///etc"},
	}
	for _, m := range bad {
		if _, err := loadConfig(envFrom(m)); err == nil {
			t.Errorf("expected error for %v", m)
		}
	}
}

func TestBuildSenderValidatesKey(t *testing.T) {
	dir := t.TempDir()
	badPath := filepath.Join(dir, "bad.p8")
	os.WriteFile(badPath, []byte("nope"), 0o600)
	base := config{keyID: "K", teamID: "T", topic: "com.example.app.push-type.liveactivity"}
	base.keyFile = badPath
	if _, err := buildSender(base); err == nil {
		t.Fatal("bad key must fail")
	}
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	der, _ := x509.MarshalPKCS8PrivateKey(key)
	goodPath := filepath.Join(dir, "good.p8")
	os.WriteFile(goodPath, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), 0o600)
	base.keyFile = goodPath
	if _, err := buildSender(base); err != nil {
		t.Fatal(err)
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
