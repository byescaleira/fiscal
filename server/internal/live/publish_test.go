package live

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"os"
	"path/filepath"
	"testing"
	"time"

	"liveresults/internal/tse"
)

func TestPublishWritesStaticFilesReadableByTheProxy(t *testing.T) {
	src := &fakeSource{races: map[string]tse.Race{}}
	dir := t.TempDir()
	svc := New(Options{Source: src, PublishDir: dir, Logger: log.New(io.Discard, "", 0)})

	svc.PollOnce(context.Background())
	if _, err := os.Stat(filepath.Join(dir, "v1", "races.json")); !os.IsNotExist(err) {
		t.Fatal("nothing should be published before the first race")
	}

	src.set(baseRace(10, 600, 400))
	svc.PollOnce(context.Background())

	list := filepath.Join(dir, "v1", "races.json")
	info, err := os.Stat(list)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o644 {
		t.Fatalf("races.json mode = %v, want 0644", info.Mode().Perm())
	}
	var body raceList
	data, _ := os.ReadFile(list)
	if err := json.Unmarshal(data, &body); err != nil || len(body.Races) != 1 || body.Races[0].ID != "presidente-br" || body.FetchedAt == "" {
		t.Fatalf("races.json = %s", data)
	}
	one, err := os.ReadFile(filepath.Join(dir, "v1", "races", "presidente-br.json"))
	if err != nil {
		t.Fatal(err)
	}
	var race tse.Race
	if err := json.Unmarshal(one, &race); err != nil || race.Sections.Counted != 10 {
		t.Fatalf("race file = %s", one)
	}
	if _, err := os.Stat(list + ".gz"); err != nil {
		t.Fatal("races.json.gz must be published for precompressed serving")
	}
	leftovers, _ := filepath.Glob(filepath.Join(dir, "v1", ".publish-*"))
	if len(leftovers) != 0 {
		t.Fatalf("temporary files left: %v", leftovers)
	}
	dirInfo, _ := os.Stat(filepath.Join(dir, "v1", "races"))
	if dirInfo.Mode().Perm() != 0o755 {
		t.Fatalf("races dir mode = %v, want 0755", dirInfo.Mode().Perm())
	}
}

func TestPublishRewritesOnlyWhenContentChanges(t *testing.T) {
	src := &fakeSource{races: map[string]tse.Race{}}
	dir := t.TempDir()
	clock := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	svc := New(Options{Source: src, PublishDir: dir, Now: func() time.Time { return clock }, Logger: log.New(io.Discard, "", 0)})
	src.set(baseRace(10, 600, 400))
	svc.PollOnce(context.Background())
	list := filepath.Join(dir, "v1", "races.json")
	one := filepath.Join(dir, "v1", "races", "presidente-br.json")
	old := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	paths := []string{list, list + ".gz", one, one + ".gz"}
	for _, p := range paths {
		if err := os.Chtimes(p, old, old); err != nil {
			t.Fatal(err)
		}
	}
	clock = clock.Add(20 * time.Second)
	svc.PollOnce(context.Background())
	for _, p := range paths {
		info, _ := os.Stat(p)
		if !info.ModTime().Equal(old) {
			t.Fatalf("%s rewritten without a change", filepath.Base(p))
		}
	}
	os.Remove(one + ".gz")
	svc.PollOnce(context.Background())
	if _, err := os.Stat(one + ".gz"); err != nil {
		t.Fatal("missing .gz must be restored")
	}
	src.set(baseRace(20, 1200, 800))
	clock = clock.Add(20 * time.Second)
	svc.PollOnce(context.Background())
	for _, p := range []string{list, list + ".gz", one, one + ".gz"} {
		info, _ := os.Stat(p)
		if info.ModTime().Equal(old) {
			t.Fatalf("%s not rewritten after a change", filepath.Base(p))
		}
	}
	var body raceList
	data, _ := os.ReadFile(list)
	json.Unmarshal(data, &body)
	if body.FetchedAt != "2026-10-25T20:00:40Z" || body.Races[0].Sections.Counted != 20 {
		t.Fatalf("races.json = %s", data)
	}
}

func TestResetPublishedDropsStaleFiles(t *testing.T) {
	dir := t.TempDir()
	stale := filepath.Join(dir, "v1", "races", "governador-am.json")
	os.MkdirAll(filepath.Dir(stale), 0o755)
	os.WriteFile(stale, []byte(`{"id":"governador-am"}`), 0o644)
	os.WriteFile(filepath.Join(dir, "keep.txt"), []byte("x"), 0o644)
	ingested := filepath.Join(dir, "v1", "meta.json")
	os.WriteFile(ingested, []byte(`{}`), 0o644)
	statePath := filepath.Join(t.TempDir(), "state.json")
	st, _ := json.Marshal(state{Races: []tse.Race{baseRace(10, 600, 400)}, FetchedAt: time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)})
	os.WriteFile(statePath, st, 0o600)
	svc := New(Options{Source: &fakeSource{races: map[string]tse.Race{}}, StatePath: statePath, PublishDir: dir, Logger: log.New(io.Discard, "", 0)})
	if err := svc.LoadState(); err != nil {
		t.Fatal(err)
	}
	if err := svc.ResetPublished(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Fatal("stale race file must be removed")
	}
	if _, err := os.Stat(filepath.Join(dir, "keep.txt")); err != nil {
		t.Fatal("files outside v1 must stay")
	}
	if _, err := os.Stat(ingested); err != nil {
		t.Fatal("files published by the ingest must stay")
	}
	if _, err := os.Stat(filepath.Join(dir, "v1", "races", "presidente-br.json")); err != nil {
		t.Fatal("races from the saved state must be published again")
	}
	empty := New(Options{Source: &fakeSource{races: map[string]tse.Race{}}, PublishDir: dir, Logger: log.New(io.Discard, "", 0)})
	if err := empty.ResetPublished(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "v1", "races")); !os.IsNotExist(err) {
		t.Fatal("with no saved state no race file may be left")
	}
	if _, err := os.Stat(filepath.Join(dir, "v1", "races.json")); !os.IsNotExist(err) {
		t.Fatal("with no saved state races.json must be removed")
	}
	if _, err := os.Stat(ingested); err != nil {
		t.Fatal("files published by the ingest must survive an empty reset")
	}
}
