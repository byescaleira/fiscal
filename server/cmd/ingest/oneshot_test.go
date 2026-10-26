package main

import (
	"context"
	"testing"
	"time"

	"liveresults/internal/jobctl"
)

func TestSiteRollbackWaitsForTheIngestLock(t *testing.T) {
	cfg, err := loadConfig(env(map[string]string{"DATA_DIR": t.TempDir(), "PUBLIC_DIR": t.TempDir(), "INGEST_LOCK_WAIT": "0s"}), now)
	if err != nil {
		t.Fatal(err)
	}
	held, err := jobctl.Acquire(context.Background(), cfg.lockPath(), 0)
	if err != nil {
		t.Fatal(err)
	}
	if code := siteCommand(context.Background(), cfg, "rollback", ""); code != exitBusy {
		t.Fatalf("rollback while a load runs = %d, want %d", code, exitBusy)
	}
	if code := siteCommand(context.Background(), cfg, "status", ""); code != 0 {
		t.Fatalf("status while a load runs = %d", code)
	}
	held.Release()
	if code := siteCommand(context.Background(), cfg, "rollback", ""); code != 1 {
		t.Fatalf("rollback without staged sites = %d, want 1", code)
	}
	again, err := jobctl.Acquire(context.Background(), cfg.lockPath(), 0)
	if err != nil {
		t.Fatalf("rollback kept the lock: %v", err)
	}
	again.Release()
}

func TestOnceKind(t *testing.T) {
	cases := []struct {
		value string
		args  []string
		want  string
		ok    bool
	}{
		{"", nil, "", true},
		{"true", nil, "full", true},
		{"true", []string{"live"}, "live", true},
		{"true", []string{"full"}, "full", true},
		{"live", nil, "live", true},
		{"true", []string{"later"}, "", false},
		{"", []string{"live"}, "", false},
		{"full", []string{"live"}, "", false},
	}
	for _, c := range cases {
		got, err := onceKind(onceFlag{value: c.value}, c.args)
		if got != c.want || (err == nil) != c.ok {
			t.Errorf("onceKind(%q, %v) = %q, %v", c.value, c.args, got, err)
		}
	}
	var f onceFlag
	if f.Set("sometimes") == nil || f.Set("live") != nil || f.String() != "live" || !f.IsBoolFlag() {
		t.Fatal("flag value")
	}
}

func TestSiteConfig(t *testing.T) {
	c, err := loadConfig(env(nil), now)
	if err != nil {
		t.Fatal(err)
	}
	if c.site.MinPeople != 500 || c.site.MaxDrop != 0.2 || c.site.MaxFiles != 18000 || c.siteKeep != 3 || c.lockWait != 20*time.Minute || c.nice != 19 {
		t.Fatalf("defaults = %+v keep=%d wait=%s nice=%d", c.site, c.siteKeep, c.lockWait, c.nice)
	}
	scoped, err := loadConfig(env(map[string]string{"INGEST_UFS": "ac"}), now)
	if err != nil || scoped.site.MinPeople != 1 {
		t.Fatalf("scoped = %+v %v", scoped.site, err)
	}
	set, err := loadConfig(env(map[string]string{"SITE_MIN_PEOPLE": "10", "SITE_MAX_DROP": "0.1", "SITE_MAX_FILES": "15000", "SITE_KEEP": "5", "INGEST_LOCK_WAIT": "0s", "INGEST_NICE": "0"}), now)
	if err != nil || set.site.MinPeople != 10 || set.site.MaxDrop != 0.1 || set.site.MaxFiles != 15000 || set.siteKeep != 5 || set.lockWait != 0 || set.nice != 0 {
		t.Fatalf("set = %+v %v", set.site, err)
	}
	for _, bad := range []map[string]string{{"SITE_MAX_FILES": "25000"}, {"SITE_MAX_DROP": "1"}, {"SITE_KEEP": "1"}, {"INGEST_NICE": "20"}, {"INGEST_LOCK_WAIT": "5h"}, {"SITE_MIN_PEOPLE": "-1"}} {
		if _, err := loadConfig(env(bad), now); err == nil {
			t.Errorf("%v must fail", bad)
		}
	}
}
