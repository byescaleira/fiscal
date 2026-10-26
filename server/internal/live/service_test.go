package live

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"liveresults/internal/apns"
	"liveresults/internal/store"
	"liveresults/internal/tse"
)

type fakeSource struct {
	mu    sync.Mutex
	races map[string]tse.Race
}

func (f *fakeSource) set(r tse.Race) {
	f.mu.Lock()
	f.races[r.ID] = r
	f.mu.Unlock()
}

func (f *fakeSource) Fetch(_ context.Context, d tse.Definition) (tse.Race, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	r, ok := f.races[d.ID]
	if !ok {
		return tse.Race{}, false, nil
	}
	r.Candidates = append([]tse.Candidate(nil), r.Candidates...)
	return r, true, nil
}

type recordingSender struct {
	mu     sync.Mutex
	events []string
	tokens []string
}

func (s *recordingSender) Send(_ context.Context, n apns.Notification) apns.Result {
	var body struct {
		Aps struct {
			Event string `json:"event"`
		} `json:"aps"`
	}
	json.Unmarshal(n.Payload, &body)
	s.mu.Lock()
	s.events = append(s.events, body.Aps.Event)
	s.tokens = append(s.tokens, n.Token)
	s.mu.Unlock()
	return apns.Result{Status: 200}
}

func (s *recordingSender) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.events)
}

func baseRace(counted int64, votes ...int64) tse.Race {
	r := tse.Race{ID: "presidente-br", Office: "president", UF: "br", Round: 2, Sections: tse.Sections{Total: 100, Counted: counted, Percent: float64(counted)}}
	for i, v := range votes {
		r.Candidates = append(r.Candidates, tse.Candidate{Number: []string{"13", "22"}[i], Name: []string{"Lula", "Flavio Bolsonaro"}[i], Votes: v})
	}
	return r
}

func token(c byte) string {
	return strings.Repeat(string(c), 64)
}

func newStore(t *testing.T, tokens ...string) *store.Store {
	t.Helper()
	st, err := store.Open(t.TempDir(), store.Options{Max: 100})
	if err != nil {
		t.Fatal(err)
	}
	for _, tk := range tokens {
		st.Put(store.Registration{RaceID: "presidente-br", PushToken: tk, Environment: "development"})
	}
	st.Put(store.Registration{RaceID: "governador-ac", PushToken: token('f'), Environment: "development"})
	return st
}

func TestPollPushesOnlyOnChangeAndStopsAfterEnd(t *testing.T) {
	src := &fakeSource{races: map[string]tse.Race{}}
	sender := &recordingSender{}
	st := newStore(t, token('a'), token('b'))
	var logs bytes.Buffer
	svc := New(Options{Source: src, Sender: sender, Registry: st, Logger: log.New(&logs, "", 0)})
	ctx := context.Background()

	svc.PollOnce(ctx)
	if races, _ := svc.Snapshot(); len(races) != 0 {
		t.Fatal("snapshot must be empty before data")
	}

	src.set(baseRace(0, 0, 0))
	svc.PollOnce(ctx)
	if sender.count() != 2 {
		t.Fatalf("first data must push to the race registrations only, got %d", sender.count())
	}
	svc.PollOnce(ctx)
	if sender.count() != 2 {
		t.Fatalf("unchanged data must not push, got %d", sender.count())
	}
	src.set(baseRace(10, 50, 40))
	svc.PollOnce(ctx)
	if sender.count() != 4 {
		t.Fatalf("changed data must push, got %d", sender.count())
	}
	final := baseRace(100, 500, 400)
	final.Final = true
	final.Candidates[0].Elected = true
	src.set(final)
	svc.PollOnce(ctx)
	if sender.count() != 6 || sender.events[5] != "end" || sender.events[4] != "end" {
		t.Fatalf("final must push end, got %v", sender.events)
	}
	more := final
	more.Candidates = []tse.Candidate{{Number: "13", Votes: 501, Elected: true}, {Number: "22", Votes: 400}}
	src.set(more)
	svc.PollOnce(ctx)
	if sender.count() != 6 {
		t.Fatalf("no updates after end, got %d", sender.count())
	}
	for _, tk := range sender.tokens {
		if tk == token('f') {
			t.Fatal("pushed to another race registration")
		}
	}
	if strings.Contains(logs.String(), token('a')) {
		t.Fatal("full token in logs")
	}
}

func TestChanged(t *testing.T) {
	a := baseRace(10, 50, 40)
	if Changed(a, baseRace(10, 50, 40)) {
		t.Fatal("same race reported as changed")
	}
	if !Changed(a, baseRace(11, 50, 40)) || !Changed(a, baseRace(10, 51, 40)) {
		t.Fatal("change not detected")
	}
	b := baseRace(10, 50, 40)
	b.Final = true
	if !Changed(a, b) {
		t.Fatal("final not detected")
	}
}

func TestStatePersistsEnded(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	src := &fakeSource{races: map[string]tse.Race{}}
	sender := &recordingSender{}
	st := newStore(t, token('a'))
	final := baseRace(100, 500, 400)
	final.Final = true
	final.Candidates[0].Elected = true
	src.set(final)
	svc := New(Options{Source: src, Sender: sender, Registry: st, StatePath: path, Logger: log.New(io.Discard, "", 0)})
	svc.PollOnce(context.Background())
	if sender.count() != 1 {
		t.Fatalf("got %d", sender.count())
	}
	restarted := New(Options{Source: src, Sender: sender, Registry: st, StatePath: path, Logger: log.New(io.Discard, "", 0)})
	if err := restarted.LoadState(); err != nil {
		t.Fatal(err)
	}
	if r, ok := restarted.Race("presidente-br"); !ok || !r.Final {
		t.Fatal("snapshot not restored")
	}
	restarted.PollOnce(context.Background())
	if sender.count() != 1 {
		t.Fatalf("restart must not resend end, got %d", sender.count())
	}
}

func TestDispatchRemovesInvalidTokensWithRealClient(t *testing.T) {
	gone := token('a')
	bad := token('b')
	ok := token('c')
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor != 2 {
			t.Errorf("proto %s", r.Proto)
		}
		switch strings.TrimPrefix(r.URL.Path, "/3/device/") {
		case gone:
			w.WriteHeader(http.StatusGone)
			w.Write([]byte(`{"reason":"Unregistered"}`))
		case bad:
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(`{"reason":"BadDeviceToken"}`))
		default:
			w.WriteHeader(http.StatusOK)
		}
	}))
	srv.EnableHTTP2 = true
	srv.StartTLS()
	defer srv.Close()
	pool := x509.NewCertPool()
	pool.AddCert(srv.Certificate())
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	client := apns.NewClient(apns.NewTokenProvider(key, "K", "T", nil), "com.example.push-type.liveactivity")
	client.HTTP = &http.Client{Transport: apns.NewTransport(&tls.Config{RootCAs: pool}), Timeout: 5 * time.Second}
	client.Hosts = map[string]string{"development": srv.URL, "production": srv.URL}

	st := newStore(t, gone, bad, ok)
	src := &fakeSource{races: map[string]tse.Race{}}
	src.set(baseRace(5, 10, 9))
	var logs bytes.Buffer
	svc := New(Options{Source: src, Sender: client, Registry: st, Logger: log.New(&logs, "", 0)})
	svc.PollOnce(context.Background())
	regs := st.ForRace("presidente-br")
	if len(regs) != 1 || regs[0].PushToken != ok {
		t.Fatalf("remaining %+v", regs)
	}
	stats, err := svc.PushRace(context.Background(), "presidente-br")
	if err != nil || stats.Sent != 1 || stats.Removed != 0 || stats.Event != "update" {
		t.Fatalf("push test %+v %v", stats, err)
	}
	if _, err := svc.PushRace(context.Background(), "governador-df"); err != ErrNotReady {
		t.Fatalf("expected not ready, got %v", err)
	}
	if strings.Contains(logs.String(), gone) || !strings.Contains(logs.String(), gone[:6]+"…") {
		t.Fatalf("log must carry only the token prefix: %s", logs.String())
	}
}
