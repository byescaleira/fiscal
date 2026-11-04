package ingest

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"maps"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"liveresults/internal/datastore"
	"liveresults/internal/publicdata"
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

func tamperSnapshot(t *testing.T, in *Ingest) {
	t.Helper()
	if err := in.LoadSnapshot(); err != nil {
		t.Fatal(err)
	}
	in.mu.Lock()
	for _, p := range in.dataset.People {
		for i := range p.Roles {
			p.Roles[i].Party = "TESTE"
		}
	}
	in.mu.Unlock()
	if err := in.SaveSnapshot(); err != nil {
		t.Fatal(err)
	}
}

func TestADivergentCheckHoldsThePathsUntilTheyArePublishedByHand(t *testing.T) {
	h := newSyncHarness(t)
	h.run("senado")
	tamperSnapshot(t, h.in)
	h.clock = h.clock.Add(time.Minute)
	outs, err := h.in.RunJob(context.Background(), "memoria", h.hooks())
	if !errors.Is(err, ErrDivergence) || len(outs) != 1 {
		t.Fatalf("memoria: %v %+v", err, outs)
	}
	c, ok, err := ReadConsistency(h.in.cfg.DataDir)
	if err != nil || !ok || c.Staging == 0 || c.Site == 0 || len(c.Held) == 0 {
		t.Fatalf("consistency: %v %v %+v", ok, err, c)
	}
	if current, _ := h.in.site.CurrentName(); current != c.Incremental {
		t.Fatalf("ready = %s, want the incremental %s", current, c.Incremental)
	}
	held := filepath.Join(h.in.site.Dir(c.Incremental), "v2", "index", "people.json")
	before, err := os.ReadFile(held)
	if err != nil || !strings.Contains(string(before), "TESTE") {
		t.Fatalf("the incremental release should keep what was published: %v", err)
	}
	h.clock = h.clock.Add(time.Minute)
	h.run("senado")
	current, _ := h.in.site.CurrentName()
	data, err := os.ReadFile(filepath.Join(h.in.site.Dir(current), "v2", "index", "people.json"))
	if err != nil || !strings.Contains(string(data), "TESTE") {
		t.Fatalf("a later job must not publish the held paths by itself: %v", err)
	}
	if c, _, _ := ReadConsistency(h.in.cfg.DataDir); len(c.Held) == 0 {
		t.Fatal("a later job must keep the record of the held paths")
	}
	h.clock = h.clock.Add(time.Minute)
	rel, err := PublishStaging(h.in.cfg.DataDir, h.in.site)
	if err != nil {
		t.Fatal(err)
	}
	if current, _ := h.in.site.CurrentName(); current != rel.Release {
		t.Fatalf("ready = %s, want %s", current, rel.Release)
	}
	data, err = os.ReadFile(filepath.Join(h.in.site.Dir(rel.Release), "v2", "index", "people.json"))
	if err != nil || strings.Contains(string(data), "TESTE") {
		t.Fatalf("publishing must carry the staging area: %v", err)
	}
	c, _, err = ReadConsistency(h.in.cfg.DataDir)
	if err != nil || len(c.Held) != 0 || c.Released != rel.Release {
		t.Fatalf("after publishing: %v %+v", err, c)
	}
}

func TestPublishStagingNeedsAManifest(t *testing.T) {
	st := &site.Stager{Staging: t.TempDir(), Root: t.TempDir()}
	if _, err := PublishStaging(t.TempDir(), st); err == nil {
		t.Fatal("no manifest means nothing to publish")
	}
}

func TestRepeatedStoreKeysEndTheJobAsADivergence(t *testing.T) {
	h := newSyncHarness(t)
	db, err := datastore.Open(filepath.Join(t.TempDir(), "fiscal.db"), func() time.Time { return h.clock })
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	h.in.UseStore(db)
	data, err := os.ReadFile(h.get.routes["/despesas_ceaps/2026"])
	if err != nil {
		t.Fatal(err)
	}
	var rows []map[string]any
	if err := json.Unmarshal(data, &rows); err != nil || len(rows) == 0 {
		t.Fatalf("fixture: %v", err)
	}
	repeated := maps.Clone(rows[0])
	repeated["valorReembolsado"] = 1.5
	data, err = json.Marshal(append(rows, repeated))
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "ceaps.json")
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatal(err)
	}
	h.get.routes["/despesas_ceaps/2026"] = path
	h.clock = h.clock.Add(time.Minute)
	outs, err := h.in.RunJob(context.Background(), "senado", h.hooks())
	if !errors.Is(err, ErrDivergence) || len(outs) != 1 || !errors.Is(outs[0].Err, ErrDivergence) {
		t.Fatalf("a repeated key must end as a divergence: %v %+v", err, outs)
	}
	if outs[0].Release == "" {
		t.Fatalf("the data read from the source still goes out: %+v", outs[0])
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

func TestYesterdaysLiveVotesStayUntilAPhaseReadsThemFromTheStore(t *testing.T) {
	in := testIngest(t, Config{}, senadoFixtures(t), time.Now())
	vote := func(id, date string) *publicdata.HouseVote {
		return &publicdata.HouseVote{ID: id, Date: date, House: publicdata.HouseCamara}
	}
	prev := HotState{Date: "2026-10-26", Votes: []*publicdata.HouseVote{vote("b", "2026-10-26")}, Carry: []*publicdata.HouseVote{vote("a", "2026-10-23"), vote("old", "2026-10-01")}}
	carry := in.carry(prev, "2026-10-27")
	if len(carry) != 2 || carry[0].ID != "a" || carry[1].ID != "b" {
		t.Fatalf("carry = %v", carry)
	}
	if same := in.carry(prev, "2026-10-26"); len(same) != 1 || same[0].ID != "a" {
		t.Fatalf("the same day keeps only the older carry: %v", same)
	}
	ds := &publicdata.Dataset{Today: "2026-10-27", Votes: []*publicdata.HouseVote{vote("z", "2026-10-20")}}
	HotState{Date: "2026-10-27", Votes: []*publicdata.HouseVote{vote("c", "2026-10-27")}, Agenda: []publicdata.RawAgendaHouse{{House: "camara"}}, Carry: carry}.merge(ds)
	if len(ds.Votes) != 4 || len(ds.Agenda) != 1 {
		t.Fatalf("merge = %d votes, %d agenda houses", len(ds.Votes), len(ds.Agenda))
	}
}

func TestYesterdaysLiveVotesSurviveTheNightBeforeTheFirstHotTick(t *testing.T) {
	vote := func(id, date string) *publicdata.HouseVote {
		return &publicdata.HouseVote{ID: id, Date: date, House: publicdata.HouseCamara}
	}
	st := HotState{Date: "2026-10-27", Votes: []*publicdata.HouseVote{vote("late", "2026-10-27")}, Agenda: []publicdata.RawAgendaHouse{{House: "camara"}}, Carry: []*publicdata.HouseVote{vote("a", "2026-10-23")}}
	ds := &publicdata.Dataset{Today: "2026-10-28"}
	st.merge(ds)
	if len(ds.Votes) != 2 || len(ds.Agenda) != 0 {
		t.Fatalf("after midnight the last day's votes stay and its agenda goes: %d votes, %d agenda houses", len(ds.Votes), len(ds.Agenda))
	}
	stale := &publicdata.Dataset{Today: "2026-11-10"}
	st.merge(stale)
	for _, v := range stale.Votes {
		if v.ID == "late" {
			t.Fatal("a hot state older than the carry window must not come back")
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

func TestADivergentRebuildLeavesTheIncrementalReleasePublished(t *testing.T) {
	h := newSyncHarness(t)
	first := h.run("senado").Release
	h.clock = h.clock.Add(time.Minute)
	m, err := h.in.manifest()
	if err != nil {
		t.Fatal(err)
	}
	rebuilt, err := h.in.site.Stage("memoria", m.Paths())
	if err != nil || rebuilt.Release == first {
		t.Fatalf("stage: %v %s", err, rebuilt.Release)
	}
	h.in.keepPublished(first)
	if current, _ := h.in.site.CurrentName(); current != first {
		t.Fatalf("ready = %s, want the incremental %s", current, first)
	}
}
