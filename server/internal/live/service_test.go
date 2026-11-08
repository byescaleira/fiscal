package live

import (
	"context"
	"errors"
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"liveresults/internal/tse"
)

type fakeSource struct {
	mu    sync.Mutex
	races map[string]tse.Race
	err   error
}

func (f *fakeSource) set(r tse.Race) {
	f.mu.Lock()
	f.races[r.ID] = r
	f.mu.Unlock()
}

func (f *fakeSource) fail(err error) {
	f.mu.Lock()
	f.err = err
	f.mu.Unlock()
}

func (f *fakeSource) Fetch(_ context.Context, d tse.Definition) (tse.Race, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return tse.Race{}, false, f.err
	}
	r, ok := f.races[d.ID]
	if !ok {
		return tse.Race{}, false, nil
	}
	r.Candidates = append([]tse.Candidate(nil), r.Candidates...)
	return r, true, nil
}

func baseRace(counted int64, votes ...int64) tse.Race {
	r := tse.Race{ID: "presidente-br", Office: "president", UF: "br", Round: 2, Sections: tse.Sections{Total: 100, Counted: counted, Percent: float64(counted)}}
	for i, v := range votes {
		r.Candidates = append(r.Candidates, tse.Candidate{Number: []string{"13", "22"}[i], Name: []string{"Lula", "Flavio Bolsonaro"}[i], Votes: v})
	}
	return r
}

func quiet() *log.Logger {
	return log.New(io.Discard, "", 0)
}

func TestPollKeepsTheLatestRaces(t *testing.T) {
	src := &fakeSource{races: map[string]tse.Race{}}
	clock := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	svc := New(Options{Source: src, Now: func() time.Time { return clock }, Logger: quiet()})
	svc.PollOnce(context.Background())
	if races, at := svc.Snapshot(); len(races) != 0 || !at.Equal(clock) {
		t.Fatalf("snapshot before data = %v %v", races, at)
	}
	src.set(baseRace(10, 50, 40))
	clock = clock.Add(20 * time.Second)
	svc.PollOnce(context.Background())
	races, at := svc.Snapshot()
	if len(races) != 1 || races[0].Sections.Counted != 10 || !at.Equal(clock) {
		t.Fatalf("snapshot = %+v %v", races, at)
	}
	src.fail(errors.New("tse down"))
	svc.PollOnce(context.Background())
	if races, at := svc.Snapshot(); len(races) != 1 || !at.Equal(clock) {
		t.Fatalf("a failed read must keep the last races and time: %+v %v", races, at)
	}
}

func TestStatePersistsTheRaces(t *testing.T) {
	path := filepath.Join(t.TempDir(), "data", "state.json")
	src := &fakeSource{races: map[string]tse.Race{}}
	final := baseRace(100, 500, 400)
	final.Final = true
	final.Candidates[0].Elected = true
	src.set(final)
	svc := New(Options{Source: src, StatePath: path, Logger: quiet()})
	svc.PollOnce(context.Background())
	info, err := os.Stat(path)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("state file %v %v", info, err)
	}
	restarted := New(Options{Source: &fakeSource{races: map[string]tse.Race{}}, StatePath: path, Logger: quiet()})
	if err := restarted.LoadState(); err != nil {
		t.Fatal(err)
	}
	if races, _ := restarted.Snapshot(); len(races) != 1 || !races[0].Final || races[0].Sections.Counted != 100 {
		t.Fatalf("snapshot not restored: %+v", races)
	}
}

func TestLoadStateReadsTheOldFormat(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	old := `{"races":[{"id":"presidente-br","sections":{"counted":7}},{"id":"unknown"}],"ended":["presidente-br"],"fetchedAt":"2026-10-25T20:00:00Z"}`
	if err := os.WriteFile(path, []byte(old), 0o600); err != nil {
		t.Fatal(err)
	}
	svc := New(Options{Source: &fakeSource{races: map[string]tse.Race{}}, StatePath: path, Logger: quiet()})
	if err := svc.LoadState(); err != nil {
		t.Fatal(err)
	}
	races, at := svc.Snapshot()
	if len(races) != 1 || races[0].ID != "presidente-br" || !at.Equal(time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)) {
		t.Fatalf("snapshot = %+v %v", races, at)
	}
}
