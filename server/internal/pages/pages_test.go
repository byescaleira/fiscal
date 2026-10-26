package pages

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"liveresults/internal/site"
)

type harness struct {
	t      *testing.T
	public string
	stager *site.Stager
	cfg    *Config
	clock  time.Time
	calls  [][]string
	envs   [][]string
	fail   bool
	silent bool
	seen   []string
}

func newHarness(t *testing.T) *harness {
	public := t.TempDir()
	h := &harness{t: t, public: public, clock: time.Date(2026, 10, 26, 12, 0, 0, 0, time.UTC)}
	h.stager = &site.Stager{Staging: filepath.Join(public, "v1"), Root: filepath.Join(public, "site"), Keep: 3, Rules: site.Rules{MinPeople: 1}, Now: func() time.Time { return h.clock }}
	h.cfg = &Config{PublicDir: public, DataDir: t.TempDir(), Project: "fiscal-dados", Branch: "main", AccountID: "acc", Token: "tok-secret-123", Wrangler: "wrangler", DataInterval: time.Hour, MaxPerDay: 5, Attempts: 2, Backoff: time.Millisecond, Now: func() time.Time { return h.clock }, Run: h.run}
	return h
}

func (h *harness) run(_ context.Context, name string, args, env []string) ([]byte, error) {
	h.calls = append(h.calls, append([]string{name}, args...))
	h.envs = append(h.envs, env)
	var files []string
	filepath.WalkDir(args[2], func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			rel, _ := filepath.Rel(args[2], p)
			files = append(files, filepath.ToSlash(rel))
		}
		return nil
	})
	h.seen = files
	if h.fail {
		return []byte("error: token tok-secret-123 rejected"), errors.New("exit status 1")
	}
	if h.silent {
		return []byte("Uploading... (0/3)"), nil
	}
	return []byte("✨ Deployment complete! Take a peek over at https://x.fiscal-dados.pages.dev"), nil
}

func (h *harness) write(path, body string) {
	full := filepath.Join(h.public, "v1", filepath.FromSlash(path))
	os.MkdirAll(filepath.Dir(full), 0o755)
	tmp := full + ".tmp"
	os.WriteFile(tmp, []byte(body), 0o644)
	os.Rename(tmp, full)
}

func (h *harness) stage(kind, day string) string {
	h.t.Helper()
	h.write("index/people.json", `[{"slug":"a","name":"A"}]`)
	h.write("people/a.json", `{"slug":"a"}`)
	h.write("meta.json", `{"generatedAt":"2026-10-26T06:30:00-03:00","counts":{"people":1}}`)
	h.write("today.json", `{"date":"`+day+`"}`)
	h.clock = h.clock.Add(time.Minute)
	rel, err := h.stager.Stage(kind, []string{"index/people.json", "people/a.json", "meta.json", "today.json"})
	if err != nil {
		h.t.Fatal(err)
	}
	return rel.Release
}

func (h *harness) cycle() Outcome {
	h.t.Helper()
	out, err := h.cfg.Cycle(context.Background())
	if err != nil {
		h.t.Fatal(err)
	}
	return out
}

func TestCycleDeploysTheReadySiteWithTheLiveFiles(t *testing.T) {
	h := newHarness(t)
	if out := h.cycle(); out.Deployed || out.Reason != "no staged site yet" {
		t.Fatalf("out = %+v", out)
	}
	first := h.stage("full", "2026-10-26")
	h.write("races.json", `{"races":[]}`)
	h.write("races/presidente-br.json", `{"id":"presidente-br"}`)
	h.write("status.json", `{"full":{}}`)
	out := h.cycle()
	if !out.Deployed || out.Release != first || len(h.calls) != 1 {
		t.Fatalf("out = %+v calls=%v", out, h.calls)
	}
	joined := strings.Join(h.seen, ",")
	for _, want := range []string{"v2/races.json", "v2/races/presidente-br.json", "v2/status.json", "v2/people/a.json", "_headers", "404.html", "v2/release.json"} {
		if !strings.Contains(joined, want) {
			t.Fatalf("missing %s in %s", want, joined)
		}
	}
	if strings.Contains(joined, ".gz") {
		t.Fatalf("no .gz may be uploaded: %s", joined)
	}
	args := strings.Join(h.calls[0], " ")
	if !strings.Contains(args, "pages deploy") || !strings.Contains(args, "--project-name=fiscal-dados") || !strings.Contains(args, "--branch=main") || strings.Contains(args, "tok-secret") {
		t.Fatalf("args = %s", args)
	}
	if !strings.Contains(strings.Join(h.envs[0], " "), "CLOUDFLARE_API_TOKEN=tok-secret-123") {
		t.Fatal("token must go only in the environment")
	}
	if _, err := os.Stat(out.Dir); !os.IsNotExist(err) {
		t.Fatal("the deploy directory must be removed")
	}
	if again := h.cycle(); again.Deployed || again.Reason != "nothing changed" {
		t.Fatalf("again = %+v", again)
	}
	h.write("status.json", `{"full":{"x":1}}`)
	if again := h.cycle(); again.Deployed {
		t.Fatal("status alone must not deploy")
	}
	h.write("races/presidente-br.json", `{"id":"presidente-br","votes":1}`)
	if again := h.cycle(); !again.Deployed {
		t.Fatal("a race change must deploy right away")
	}
}

func TestLiveDataWaitsForTheIntervalButFullAndRollbackDoNot(t *testing.T) {
	h := newHarness(t)
	h.stage("full", "2026-10-26")
	h.cycle()
	h.stage("live", "2026-10-27")
	if out := h.cycle(); out.Deployed || !strings.Contains(out.Reason, "interval") {
		t.Fatalf("out = %+v", out)
	}
	h.clock = h.clock.Add(time.Hour)
	if out := h.cycle(); !out.Deployed {
		t.Fatalf("after the interval = %+v", out)
	}
	h.stage("full", "2026-10-28")
	if out := h.cycle(); !out.Deployed {
		t.Fatal("a full release deploys right away")
	}
	back, err := h.stager.Rollback("")
	if err != nil {
		t.Fatal(err)
	}
	if out := h.cycle(); !out.Deployed || out.Release != back {
		t.Fatalf("rollback = %+v", out)
	}
}

func TestMonthlyBudgetSpreadsRoutineDeploys(t *testing.T) {
	h := newHarness(t)
	h.cfg.MaxPerDay = 0
	h.cfg.MaxPerMonth = 300
	spread := h.cfg.Spread(h.clock, 0)
	if spread < 26*time.Minute || spread > 27*time.Minute {
		t.Fatalf("spread = %s, want 132h/300", spread)
	}
	h.stage("full", "2026-10-26")
	h.cycle()
	h.stage("camara", "2026-10-27")
	if out := h.cycle(); out.Deployed || !strings.Contains(out.Reason, "interval") {
		t.Fatalf("a phase release waits for the monthly spread: %+v", out)
	}
	h.clock = h.clock.Add(30 * time.Minute)
	if out := h.cycle(); !out.Deployed {
		t.Fatalf("after the spread = %+v", out)
	}
	h.stage("hot", "2026-10-28")
	h.clock = h.clock.Add(30 * time.Minute)
	if out := h.cycle(); out.Deployed {
		t.Fatal("hot releases also wait for PAGES_DATA_INTERVAL")
	}
	st, _ := h.cfg.LoadState()
	if st.Months["2026-10"] != 2 {
		t.Fatalf("months = %v", st.Months)
	}
	h.cfg.MaxPerMonth = 2
	h.cfg.Force = true
	if _, err := h.cfg.Cycle(context.Background()); !errors.Is(err, ErrBudget) {
		t.Fatalf("the monthly cap is hard: %v", err)
	}
	if got := h.cfg.Spread(h.clock, 2); got <= 24*time.Hour {
		t.Fatalf("with no budget left the spread runs to the end of the month: %s", got)
	}
}

func TestBudgetFailureAndDryRun(t *testing.T) {
	h := newHarness(t)
	h.stage("full", "2026-10-26")
	h.cfg.DryRun = true
	if out := h.cycle(); out.Deployed || len(h.calls) != 0 || out.Files == 0 {
		t.Fatalf("dry run = %+v", out)
	}
	h.cfg.DryRun = false
	h.fail = true
	_, err := h.cfg.Cycle(context.Background())
	if err == nil || strings.Contains(err.Error(), "tok-secret") || !strings.Contains(err.Error(), "[redacted]") {
		t.Fatalf("err = %v", err)
	}
	st, _ := h.cfg.LoadState()
	if st.Release != "" || len(h.calls) != 2 {
		t.Fatalf("a failed deploy must retry and not move the state: %d calls", len(h.calls))
	}
	h.fail = false
	h.cfg.MaxPerDay = 1
	h.cycle()
	h.cfg.Force = true
	if _, err := h.cfg.Cycle(context.Background()); !errors.Is(err, ErrBudget) {
		t.Fatalf("err = %v", err)
	}
}

func TestASilentWranglerExitIsNotADeploy(t *testing.T) {
	h := newHarness(t)
	h.stage("full", "2026-10-26")
	h.silent = true
	_, err := h.cfg.Cycle(context.Background())
	if err == nil || !strings.Contains(err.Error(), "finished without a deployment") {
		t.Fatalf("err = %v", err)
	}
	st, _ := h.cfg.LoadState()
	if st.Release != "" || len(h.calls) != 2 {
		t.Fatalf("a silent exit must retry and not move the state: %d calls", len(h.calls))
	}
}

func (h *harness) stageHighlights(kind, day, highlights string) string {
	h.t.Helper()
	h.write("highlights.json", highlights)
	h.write("index/people.json", `[{"slug":"a","name":"A"}]`)
	h.write("people/a.json", `{"slug":"a"}`)
	h.write("meta.json", `{"generatedAt":"2026-10-26T06:30:00-03:00","counts":{"people":1}}`)
	h.write("today.json", `{"date":"`+day+`"}`)
	h.clock = h.clock.Add(time.Minute)
	rel, err := h.stager.Stage(kind, []string{"index/people.json", "people/a.json", "meta.json", "today.json", "highlights.json"})
	if err != nil {
		h.t.Fatal(err)
	}
	return rel.Release
}

func (h *harness) published() string {
	data, err := os.ReadFile(filepath.Join(h.public, PublishedDir, HighlightsFile))
	if err != nil {
		return ""
	}
	return string(data)
}

func TestHighlightsArePublishedOnlyAfterTheDeployIsConfirmed(t *testing.T) {
	h := newHarness(t)
	first := `{"items":[{"id":"h1"}]}`
	h.stageHighlights("full", "2026-10-26", first)
	h.cfg.DryRun = true
	h.cycle()
	h.cfg.DryRun = false
	if got := h.published(); got != "" {
		t.Fatalf("a dry run published %s", got)
	}
	h.silent = true
	if _, err := h.cfg.Cycle(context.Background()); err == nil {
		t.Fatal("silent wrangler must fail")
	}
	if got := h.published(); got != "" {
		t.Fatalf("an unconfirmed deploy published %s", got)
	}
	h.silent = false
	if out := h.cycle(); !out.Deployed || h.published() != first {
		t.Fatalf("after the deploy: %+v published=%q", out, h.published())
	}
	if _, err := os.Stat(filepath.Join(h.public, PublishedDir, HighlightsFile+".gz")); err != nil {
		t.Fatalf("gzip pair: %v", err)
	}
	second := `{"items":[{"id":"h2"}]}`
	h.stageHighlights("live", "2026-10-27", second)
	if out := h.cycle(); out.Deployed || h.published() != first {
		t.Fatalf("waiting for the interval: %+v published=%q", out, h.published())
	}
	h.clock = h.clock.Add(time.Hour)
	if out := h.cycle(); !out.Deployed || h.published() != second {
		t.Fatalf("after the interval: %+v published=%q", out, h.published())
	}
	h.write("highlights.json", `{"items":[{"id":"staged-only"}]}`)
	os.Remove(filepath.Join(h.public, PublishedDir, HighlightsFile))
	if out := h.cycle(); out.Deployed || out.Reason != "nothing changed" || h.published() != second {
		t.Fatalf("nothing changed must restore the deployed highlights: %+v published=%q", out, h.published())
	}
}
