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

	"liveresults/internal/publicdata"
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
	aside := fresh.SnapshotPath() + ".aside"
	if err := os.Rename(fresh.SnapshotPath(), aside); err != nil {
		t.Fatal(err)
	}
	if _, err := fresh.Live(context.Background()); !errors.Is(err, ErrNoSnapshot) {
		t.Fatalf("live without the snapshot must fail: %v", err)
	}
	if err := os.Rename(aside, fresh.SnapshotPath()); err != nil {
		t.Fatal(err)
	}
	live, err := fresh.Live(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !live.Unchanged || live.Written != 0 || live.Release != rep.Release {
		t.Fatalf("live = %+v", live)
	}
	if _, err := os.Stat(filepath.Join(in.cfg.PublicDir, PublishedDir, "highlights.json")); err != nil {
		t.Fatalf("published highlights: %v", err)
	}
}

func TestSnapshotKeepsFalseAndZeroBehindPointers(t *testing.T) {
	in := testIngest(t, Config{}, senadoFixtures(t), time.Now())
	no, zero, empty := false, 0, ""
	in.dataset = &publicdata.Dataset{Votes: []*publicdata.HouseVote{{ID: "camara-1", Approved: &no, No: &zero}}, People: []*publicdata.Person{{Name: "A", Contact: &publicdata.Contact{Email: &empty}, Activity: map[int]*publicdata.YearActivity{2026: {Year: 2026, Present: &zero}}}}}
	if err := in.SaveSnapshot(); err != nil {
		t.Fatal(err)
	}
	fresh := testIngest(t, Config{DataDir: in.cfg.DataDir}, senadoFixtures(t), time.Now())
	fresh.cfg.DataDir = in.cfg.DataDir
	if err := fresh.LoadSnapshot(); err != nil {
		t.Fatal(err)
	}
	v := fresh.dataset.Votes[0]
	p := fresh.dataset.People[0]
	if v.Approved == nil || *v.Approved || v.No == nil || *v.No != 0 || p.Contact.Email == nil || p.Activity[2026].Present == nil {
		t.Fatalf("a rejected vote must stay rejected, not unknown: %+v %+v", v, p)
	}
	if err := os.WriteFile(fresh.SnapshotPath(), []byte("\x0e\xff gob"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := fresh.LoadSnapshot(); !errors.Is(err, ErrNoSnapshot) {
		t.Fatalf("an unreadable snapshot means no snapshot: %v", err)
	}
}

func TestLoadSnapshotWithoutFile(t *testing.T) {
	in := testIngest(t, Config{}, senadoFixtures(t), time.Now())
	if err := in.LoadSnapshot(); !errors.Is(err, ErrNoSnapshot) {
		t.Fatalf("err = %v", err)
	}
}
