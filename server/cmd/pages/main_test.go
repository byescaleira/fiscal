package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestLoadConfig(t *testing.T) {
	if _, err := loadConfig(env(nil), true); err == nil {
		t.Fatal("the project name is required")
	}
	dry, err := loadConfig(env(map[string]string{"PAGES_PROJECT": "fiscal-dados"}), true)
	if err != nil || dry.Branch != "main" || dry.DataInterval != time.Hour || dry.MaxPerDay != 400 {
		t.Fatalf("dry = %+v %v", dry, err)
	}
	token := filepath.Join(t.TempDir(), "token")
	os.WriteFile(token, []byte("abcdefghijklmnopqrstuvwxyz0123456789\n"), 0o600)
	base := map[string]string{"PAGES_PROJECT": "fiscal-dados", "CLOUDFLARE_ACCOUNT_ID": "0123456789abcdef0123456789abcdef", "CLOUDFLARE_API_TOKEN_FILE": token}
	c, err := loadConfig(env(base), false)
	if err != nil || c.Token != "abcdefghijklmnopqrstuvwxyz0123456789" {
		t.Fatalf("config = %v", err)
	}
	for _, change := range []map[string]string{
		{"CLOUDFLARE_ACCOUNT_ID": "acc"},
		{"CLOUDFLARE_API_TOKEN_FILE": filepath.Join(t.TempDir(), "missing")},
		{"PAGES_PROJECT": "Fiscal Dados"},
		{"PAGES_DATA_INTERVAL": "1m"},
		{"PAGES_MAX_DEPLOYS_PER_DAY": "0"},
	} {
		m := map[string]string{}
		for k, v := range base {
			m[k] = v
		}
		for k, v := range change {
			m[k] = v
		}
		if _, err := loadConfig(env(m), false); err == nil {
			t.Errorf("%v must fail", change)
		}
	}
}
