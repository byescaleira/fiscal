package ingest

import (
	"context"
	"io"
	"log"
	"path/filepath"
	"testing"
	"time"

	"liveresults/internal/datastore"
	"liveresults/internal/site"
)

func TestPhaseRebuildsFromTheStoreWithoutReadingOtherSources(t *testing.T) {
	now := time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)
	cfg := Config{Years: []int{2026}, UFs: []string{"ac"}, Sources: map[string]bool{"senado": true}}
	in := testIngest(t, cfg, senadoFixtures(t), now)
	db, err := datastore.Open(filepath.Join(in.cfg.DataDir, "fiscal.db"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	stager := &site.Stager{Staging: filepath.Join(in.cfg.PublicDir, "v1"), Root: filepath.Join(in.cfg.PublicDir, "site"), Rules: site.Rules{MinPeople: 1}, Now: func() time.Time { return now }}
	in.UseStore(db)
	in.UseSite(stager)
	first, err := in.Full(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	ph, ok := PhaseByName("memoria")
	if !ok {
		t.Fatal("memoria phase")
	}
	offline := &fixtureFetcher{t: t, routes: map[string]string{}}
	pcfg := in.cfg
	pcfg.Refresh = ph.Refresh()
	pcfg.ReleaseKind = ph.Name
	phase := New(pcfg, offline, func() time.Time { return now.Add(time.Hour) }, log.New(io.Discard, "", 0))
	phase.UseStore(db)
	phase.UseSite(stager)
	rep, err := phase.Full(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(offline.calls) != 0 {
		t.Fatalf("a phase without sources must not read the network: %v", offline.calls)
	}
	if rep.People != first.People || rep.Votes != first.Votes {
		t.Fatalf("phase = %+v, first = %+v", rep, first)
	}
	senado, ok := PhaseByName("senado")
	if !ok || !senado.Refresh()["senado"] || senado.Refresh()["camara"] {
		t.Fatal("senado phase refresh set")
	}
	if _, ok := PhaseByName("nada"); ok {
		t.Fatal("unknown phase")
	}
}
