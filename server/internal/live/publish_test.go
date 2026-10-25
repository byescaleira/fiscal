package live

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"os"
	"path/filepath"
	"testing"

	"liveresults/internal/tse"
)

func TestPublishWritesStaticFilesReadableByTheProxy(t *testing.T) {
	src := &fakeSource{races: map[string]tse.Race{}}
	dir := t.TempDir()
	svc := New(Options{Source: src, Sender: &recordingSender{}, Registry: newStore(t), PublishDir: dir, Logger: log.New(io.Discard, "", 0)})

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
