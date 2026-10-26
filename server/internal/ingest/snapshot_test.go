package ingest

import (
	"context"
	"errors"
	"io"
	"log"
	"os"
	"path/filepath"
	"testing"
	"time"

	"liveresults/internal/site"
)

func TestOneShotLiveRunsFromTheSnapshotAndPublishesNothingWithoutNews(t *testing.T) {
	now := time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)
	get := senadoFixtures(t)
	cfg := Config{Years: []int{2026}, UFs: []string{"ac"}, Sources: map[string]bool{"senado": true}}
	in := testIngest(t, cfg, get, now)
	stager := func(ig *Ingest) *site.Stager {
		return &site.Stager{Staging: filepath.Join(ig.cfg.PublicDir, "v1"), Root: filepath.Join(ig.cfg.PublicDir, "site"), Rules: site.Rules{MinPeople: 1}, Now: func() time.Time { return now }}
	}
	in.UseSite(stager(in))
	rep, err := in.Full(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if rep.Release == "" || rep.Unchanged {
		t.Fatalf("report = %+v", rep)
	}
	cur, ok, err := stager(in).Current()
	if err != nil || !ok || cur.Release != rep.Release || cur.People != 1 {
		t.Fatalf("site = %+v %v", cur, err)
	}
	if err := in.SaveSnapshot(); err != nil {
		t.Fatal(err)
	}
	fresh := New(in.cfg, get, func() time.Time { return now }, log.New(io.Discard, "", 0))
	fresh.UseSite(stager(fresh))
	if _, err := fresh.Live(context.Background()); err == nil {
		t.Fatal("live without the snapshot must fail")
	}
	if err := fresh.LoadSnapshot(); err != nil {
		t.Fatal(err)
	}
	live, err := fresh.Live(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !live.Unchanged || live.Written != 0 || live.Release != rep.Release {
		t.Fatalf("live = %+v", live)
	}
	if _, err := os.Stat(filepath.Join(in.cfg.PublicDir, "published", "highlights.json")); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("the load must leave published highlights to the Pages job: %v", err)
	}
}

func TestLoadSnapshotWithoutFile(t *testing.T) {
	in := testIngest(t, Config{}, senadoFixtures(t), time.Now())
	if err := in.LoadSnapshot(); !errors.Is(err, ErrNoSnapshot) {
		t.Fatalf("err = %v", err)
	}
}
