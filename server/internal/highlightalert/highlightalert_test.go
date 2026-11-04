package highlightalert

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"liveresults/internal/apns"
	"liveresults/internal/store"
)

type fakeRegistry struct {
	mu   sync.Mutex
	regs []store.Registration
}

func (f *fakeRegistry) ForRace(string) []store.Registration {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]store.Registration(nil), f.regs...)
}

func (f *fakeRegistry) Delete(string) bool { return false }

func (f *fakeRegistry) add(token string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.regs = append(f.regs, store.Registration{RaceID: Bucket, PushToken: token, Environment: "production"})
}

type fakeSender struct {
	mu  sync.Mutex
	ids []string
}

func (f *fakeSender) Send(_ context.Context, n apns.Notification) apns.Result {
	var body struct {
		APS struct {
			Attributes struct {
				HighlightID string `json:"highlightId"`
			} `json:"attributes"`
		} `json:"aps"`
	}
	json.Unmarshal(n.Payload, &body)
	f.mu.Lock()
	f.ids = append(f.ids, body.APS.Attributes.HighlightID)
	f.mu.Unlock()
	return apns.Result{Status: http.StatusOK}
}

func (f *fakeSender) sent() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.ids...)
}

func writeHighlights(t *testing.T, path string, items ...Item) {
	t.Helper()
	data, err := json.Marshal(highlightFile{Items: items})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestEligibleHighlightWaitsForTheFirstRegistration(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "highlights.json")
	now := time.Date(2026, 10, 26, 15, 0, 0, 0, brasilia)
	writeHighlights(t, path,
		Item{ID: "h1", Kind: "vote", Title: "Votação", Weight: 92, Date: "2026-10-26"},
		Item{ID: "h2", Kind: "vote", Title: "Outra votação", Weight: 90, Date: "2026-10-26"},
	)
	regs, sender := &fakeRegistry{}, &fakeSender{}
	var logs bytes.Buffer
	w := New(Options{Path: path, SentPath: filepath.Join(dir, SentFile), Sender: sender, Registry: regs, Now: func() time.Time { return now }, Logger: log.New(&logs, "", 0)})
	ctx := context.Background()
	w.CheckOnce(ctx)
	w.CheckOnce(ctx)
	if got := sender.sent(); len(got) != 0 {
		t.Fatalf("sent without registrations: %v", got)
	}
	if n := bytes.Count(logs.Bytes(), []byte("waiting for registrations")); n != 1 {
		t.Fatalf("waiting logged %d times:\n%s", n, logs.String())
	}
	regs.add("aa11")
	w.CheckOnce(ctx)
	if got := sender.sent(); len(got) != 1 || got[0] != "h1" {
		t.Fatalf("after the first registration sent %v, want [h1]", got)
	}
	w.CheckOnce(ctx)
	if got := sender.sent(); len(got) != 1 {
		t.Fatalf("one alert per published file, got %v", got)
	}
	data, err := os.ReadFile(filepath.Join(dir, SentFile))
	if err != nil || !bytes.Contains(data, []byte(`"h1"`)) {
		t.Fatalf("sent file = %s, %v", data, err)
	}
	later := now.Add(time.Minute)
	writeHighlights(t, path,
		Item{ID: "h1", Kind: "vote", Title: "Votação", Weight: 92, Date: "2026-10-26"},
		Item{ID: "h2", Kind: "vote", Title: "Outra votação", Weight: 90, Date: "2026-10-26", Subtitle: "novo"},
	)
	os.Chtimes(path, later, later)
	w.CheckOnce(ctx)
	if got := sender.sent(); len(got) != 1 {
		t.Fatalf("a new file must wait while an alert is on screen, got %v", got)
	}
}

func TestPendingHighlightExpiresWithoutRegistrations(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "highlights.json")
	now := time.Date(2026, 10, 26, 15, 0, 0, 0, brasilia)
	writeHighlights(t, path, Item{ID: "h1", Kind: "vote", Title: "Votação", Weight: 92, Date: "2026-10-26"})
	regs, sender := &fakeRegistry{}, &fakeSender{}
	clock := now
	w := New(Options{Path: path, Sender: sender, Registry: regs, Now: func() time.Time { return clock }, Logger: log.New(io.Discard, "", 0)})
	w.CheckOnce(context.Background())
	clock = now.Add(48 * time.Hour)
	w.CheckOnce(context.Background())
	regs.add("aa11")
	w.CheckOnce(context.Background())
	if got := sender.sent(); len(got) != 0 {
		t.Fatalf("an expired highlight must not be sent, got %v", got)
	}
	if w.pending {
		t.Fatal("expired highlight still pending")
	}
}

func TestEligibleAsksForTheMinimumWeight(t *testing.T) {
	now := time.Date(2026, 11, 3, 12, 0, 0, 0, brasilia)
	if !Eligible(Item{ID: "a", Weight: 70, Date: "2026-11-03"}, now) {
		t.Fatal("weight 70 must be eligible")
	}
	if Eligible(Item{ID: "a", Weight: 69, Date: "2026-11-03"}, now) {
		t.Fatal("weight 69 must not be eligible")
	}
}

func TestPickWaitsForTheLifetimeSinceTheLastAlert(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, brasilia)
	items := []Item{{ID: "a", Weight: 80, Date: "2026-11-04"}, {ID: "b", Weight: 80, Date: "2026-11-04"}}
	if it, ok := Pick(items, map[string]time.Time{}, now); !ok || it.ID != "a" {
		t.Fatalf("first alert: %+v %v", it, ok)
	}
	sent := map[string]time.Time{"a": now.Add(-Lifetime + time.Minute)}
	if it, ok := Pick(items, sent, now); ok {
		t.Fatalf("sent %s while the previous one is on screen", it.ID)
	}
	sent["a"] = now.Add(-Lifetime)
	if it, ok := Pick(items, sent, now); !ok || it.ID != "b" {
		t.Fatalf("after the lifetime: %+v %v", it, ok)
	}
}
