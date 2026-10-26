package ingest

import (
	"context"
	"errors"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"liveresults/internal/site"
)

type syncHarness struct {
	t     *testing.T
	in    *Ingest
	get   *fixtureFetcher
	clock time.Time
	saved int
}

func newSyncHarness(t *testing.T) *syncHarness {
	h := &syncHarness{t: t, get: senadoFixtures(t), clock: time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)}
	cfg := Config{Years: []int{2026}, UFs: []string{"ac"}, Sources: map[string]bool{"senado": true}, PublicDir: filepath.Join(t.TempDir(), "public"), DataDir: filepath.Join(t.TempDir(), "data")}
	h.in = New(cfg, h.get, func() time.Time { return h.clock }, log.New(io.Discard, "", 0))
	h.in.UseSite(&site.Stager{Staging: filepath.Join(cfg.PublicDir, "v1"), Root: filepath.Join(cfg.PublicDir, "site"), Rules: site.Rules{MinPeople: 1}, Now: func() time.Time { return h.clock }})
	return h
}

func (h *syncHarness) hooks() SyncHooks {
	return SyncHooks{AfterSources: func(context.Context, Job) {
		h.saved++
		if err := h.in.SaveSnapshot(); err != nil {
			h.t.Fatal(err)
		}
	}}
}

func (h *syncHarness) run(name string) Outcome {
	h.t.Helper()
	h.clock = h.clock.Add(time.Minute)
	outs, err := h.in.RunJob(context.Background(), name, h.hooks())
	if err != nil || len(outs) != 1 {
		h.t.Fatalf("%s: %v %+v", name, err, outs)
	}
	if outs[0].Err != nil {
		h.t.Fatalf("%s: %v", name, outs[0].Err)
	}
	return outs[0]
}

func TestSyncJobsBuildTheSiteAndTheHotPathOnlyTouchesTodaysFiles(t *testing.T) {
	h := newSyncHarness(t)
	if out := h.run("hot"); out.Ran || !strings.Contains(out.Result, "sem base nacional") {
		t.Fatalf("hot before any national build = %+v", out)
	}
	first := h.run("senado")
	if !first.Ran || first.Release == "" || h.saved != 1 {
		t.Fatalf("senado = %+v saved=%d", first, h.saved)
	}
	for _, f := range []string{HotBaseFile, ManifestFile, SnapshotFile} {
		if _, err := os.Stat(h.in.path(f)); err != nil {
			t.Fatalf("%s: %v", f, err)
		}
	}
	hot := h.run("hot")
	if !hot.Ran {
		t.Fatalf("the first hot run of the day records the fingerprint: %+v", hot)
	}
	calls := len(h.get.calls)
	again := h.run("hot")
	if again.Ran || !strings.Contains(again.Result, "sem mudança") {
		t.Fatalf("a hot run without news must do nothing: %+v", again)
	}
	for _, c := range h.get.calls[calls:] {
		if !strings.Contains(c, "agenda") && !strings.Contains(c, "votacao") {
			t.Fatalf("the hot run must only ask for today's agenda and votes, asked %s", c)
		}
	}
	st := h.in.LoadSyncState()
	if st.Jobs["senado"].LastRun.IsZero() || st.Jobs["hot"].Result == "" {
		t.Fatalf("state = %+v", st.Jobs)
	}
	for _, d := range h.in.Plan(h.clock, st, nil) {
		if d.Job.Name == "senado" && d.Due {
			t.Fatalf("senado just ran: %s", d.Why)
		}
	}
}

func TestSyncProbeSkipsAnUnchangedSourceUntilItsMaxAge(t *testing.T) {
	h := newSyncHarness(t)
	fp := "v1"
	probes := 0
	h.in.UseProbe(func(context.Context, Job) (string, error) {
		probes++
		return fp, nil
	})
	j := Job{Name: "senado", Kind: JobSources, Sources: []string{"senado"}, Probe: ProbeAPI, MaxAge: 48 * time.Hour, Schedule: Schedule{At: [2]int{1, 10}}}
	run := func() Outcome {
		h.clock = h.clock.Add(time.Hour)
		outs, err := h.in.runJobs(context.Background(), []Job{j}, nil, h.hooks())
		if err != nil || len(outs) != 1 || outs[0].Err != nil {
			t.Fatalf("%v %+v", err, outs)
		}
		return outs[0]
	}
	if out := run(); !out.Ran {
		t.Fatalf("first probe always runs: %+v", out)
	}
	calls := len(h.get.calls)
	if out := run(); out.Ran || !strings.Contains(out.Result, "sem mudança") || len(h.get.calls) != calls {
		t.Fatalf("an unchanged probe must not read the source: %+v (%d new calls)", out, len(h.get.calls)-calls)
	}
	fp = "v2"
	if out := run(); !out.Ran {
		t.Fatalf("a changed probe runs the source: %+v", out)
	}
	h.clock = h.clock.Add(49 * time.Hour)
	if out := run(); !out.Ran {
		t.Fatalf("past the max age the source runs even without a probe change: %+v", out)
	}
	h.in.UseProbe(func(context.Context, Job) (string, error) { return "", errors.New("offline") })
	if out := run(); !out.Ran {
		t.Fatalf("a failed probe must not starve the source: %+v", out)
	}
	if probes != 4 {
		t.Fatalf("probes = %d", probes)
	}
}

func TestVerifyFindsNoDivergenceBetweenIncrementalAndFullRebuild(t *testing.T) {
	h := newSyncHarness(t)
	h.run("senado")
	h.run("hot")
	h.clock = h.clock.Add(time.Minute)
	outs, err := h.in.RunJob(context.Background(), "memoria", h.hooks())
	if err != nil || len(outs) != 1 || outs[0].Err != nil {
		data, _ := os.ReadFile(h.in.path(ConsistencyFile))
		t.Fatalf("memoria: %v %+v %s", err, outs, data)
	}
	var c Consistency
	readJSON(t, h.in.path(ConsistencyFile), &c)
	if c.Full == "" || c.Incremental == "" || c.Staging != 0 || c.Site != 0 {
		t.Fatalf("consistency = %+v", c)
	}
}

func TestOverlayJobsReuseTheSnapshotInsteadOfRestoringEverySource(t *testing.T) {
	h := newSyncHarness(t)
	j := Job{Name: "checagens", Kind: JobSources, Sources: []string{"comprova"}, Overlay: true, Probe: ProbeNone}
	outs, err := h.in.runJobs(context.Background(), []Job{j}, nil, h.hooks())
	if err != nil || len(outs) != 1 || outs[0].Err != nil || !outs[0].Ran || outs[0].Release == "" {
		t.Fatalf("without a snapshot the overlay falls back to a full load: %v %+v", err, outs)
	}
	calls := len(h.get.calls)
	h.clock = h.clock.Add(time.Hour)
	outs, err = h.in.runJobs(context.Background(), []Job{j}, nil, h.hooks())
	if err != nil || outs[0].Err != nil || outs[0].Changed != 0 {
		t.Fatalf("an overlay with nothing new changes nothing: %v %+v %v", err, outs, h.in.LoadSyncState().Jobs)
	}
	for _, c := range h.get.calls[calls:] {
		if strings.Contains(c, "/senador/") {
			t.Fatalf("the overlay must not read the Senate again: %s", c)
		}
	}
}

func TestSourceSetKeepThenAddMovesTheTimestamp(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sources.json")
	first := newSourceSet("2026-10-25T10:00:00-03:00")
	first.add("comprova", "Comprova", "https://projetocomprova.com.br", []int{1})
	if err := first.settle(path); err != nil {
		t.Fatal(err)
	}
	next := newSourceSet("2026-10-26T10:00:00-03:00")
	next.keep("comprova", "Comprova", "https://projetocomprova.com.br")
	next.add("comprova", "Comprova", "https://projetocomprova.com.br", []int{1, 2})
	if err := next.settle(path); err != nil {
		t.Fatal(err)
	}
	if got := next.list["comprova"].UpdatedAt; got != "2026-10-26T10:00:00-03:00" {
		t.Fatalf("a fresh read after keep must move updatedAt, got %s", got)
	}
}

func TestFirstSyncAssumesTheDataIsCurrentInsteadOfRunningEverything(t *testing.T) {
	h := newSyncHarness(t)
	h.in.cfg.Sources = map[string]bool{"senado": true}
	outs, err := h.in.Sync(context.Background(), nil, h.hooks())
	if err != nil {
		t.Fatal(err)
	}
	for _, o := range outs {
		if o.Job != "hot" {
			t.Fatalf("only the hot job runs on the first tick, ran %s", o.Job)
		}
	}
	if st := h.in.LoadSyncState(); st.Jobs["camara"].LastOK.IsZero() {
		t.Fatal("the first sync seeds the state")
	}
}
