package deploy_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

const alertTopic = "private-topic-abc"

type notice struct{ path, title, body string }

type alertRig struct {
	t       *testing.T
	root    string
	state   string
	url     string
	mu      sync.Mutex
	notices []notice
}

func newAlertRig(t *testing.T) *alertRig {
	t.Helper()
	dir := t.TempDir()
	rig := &alertRig{t: t, root: filepath.Join(dir, "root"), state: filepath.Join(dir, "state")}
	for _, d := range []string{filepath.Join(rig.root, "secrets"), filepath.Join(rig.root, "public", "v1")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		rig.mu.Lock()
		defer rig.mu.Unlock()
		rig.notices = append(rig.notices, notice{r.URL.Path, r.Header.Get("Title"), string(body)})
	}))
	t.Cleanup(server.Close)
	rig.url = server.URL
	rig.writeTopic(alertTopic)
	rig.writeAge(time.Hour)
	return rig
}

func (a *alertRig) sent() []notice {
	a.mu.Lock()
	defer a.mu.Unlock()
	return append([]notice(nil), a.notices...)
}

func (a *alertRig) writeTopic(topic string) {
	a.t.Helper()
	if err := os.WriteFile(filepath.Join(a.root, "secrets", "ntfy-topic"), []byte(topic+"\n"), 0o600); err != nil {
		a.t.Fatal(err)
	}
}

func (a *alertRig) writeAge(age time.Duration) {
	a.t.Helper()
	stamp := time.Now().Add(-age).In(time.FixedZone("", -3*60*60)).Format(time.RFC3339)
	meta := []byte(`{"generatedAt":"` + stamp + `"}`)
	if err := os.WriteFile(filepath.Join(a.root, "public", "v1", "meta.json"), meta, 0o644); err != nil {
		a.t.Fatal(err)
	}
}

func (a *alertRig) run(args []string, env ...string) (string, error) {
	a.t.Helper()
	cmd := exec.Command("sh", append([]string{"fiscal-load-alert.sh"}, args...)...)
	cmd.Env = append(os.Environ(), "FISCAL_ALERT_ROOT="+a.root, "STATE_DIRECTORY="+a.state, "FISCAL_NTFY_URL="+a.url)
	cmd.Env = append(cmd.Env, env...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func (a *alertRig) finish(result string, times int) string {
	a.t.Helper()
	var output strings.Builder
	for range times {
		out, err := a.run(nil, "SERVICE_RESULT="+result)
		if err != nil {
			a.t.Fatalf("script failed with %s: %v\n%s", result, err, out)
		}
		output.WriteString(out)
	}
	return output.String()
}

func TestLoadAlertNotifiesOnceOnTheSixthFailure(t *testing.T) {
	a := newAlertRig(t)
	a.finish("exit-code", 5)
	if len(a.sent()) != 0 {
		t.Fatalf("notified before the sixth failure: %+v", a.sent())
	}
	a.finish("exit-code", 1)
	if len(a.sent()) != 1 {
		t.Fatalf("sixth failure sent %d notices", len(a.sent()))
	}
	if got := a.sent()[0]; got.path != "/"+alertTopic || !strings.Contains(got.title, "falhou") {
		t.Fatalf("unexpected notice: %+v", got)
	}
	a.finish("timeout", 4)
	if len(a.sent()) != 1 {
		t.Fatalf("later failures sent more notices: %+v", a.sent())
	}
}

func (a *alertRig) ingestExits(code string) {
	a.t.Helper()
	if err := os.MkdirAll(a.state, 0o755); err != nil {
		a.t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(a.state, "ingest-exit"), []byte(code+"\n"), 0o644); err != nil {
		a.t.Fatal(err)
	}
}

func TestLoadAlertCountsAFailedIngestEvenWhenPublishingWorks(t *testing.T) {
	a := newAlertRig(t)
	for range 5 {
		a.ingestExits("1")
		a.finish("success", 1)
	}
	if len(a.sent()) != 0 {
		t.Fatalf("notified before the sixth failure: %+v", a.sent())
	}
	a.ingestExits("1")
	a.finish("success", 1)
	if len(a.sent()) != 1 || !strings.Contains(a.sent()[0].title, "falhou") {
		t.Fatalf("failed ingest did not notify: %+v", a.sent())
	}
	a.ingestExits("0")
	a.finish("success", 1)
	if len(a.sent()) != 2 || !strings.Contains(a.sent()[1].title, "voltou") {
		t.Fatalf("recovery of the ingest: %+v", a.sent())
	}
}

func TestLoadAlertNotifiesAtOnceAboutADivergenceWithoutCountingAFailure(t *testing.T) {
	a := newAlertRig(t)
	a.ingestExits("3")
	a.finish("success", 1)
	if len(a.sent()) != 1 || !strings.Contains(a.sent()[0].title, "divergiu") {
		t.Fatalf("a divergence must notify at once: %+v", a.sent())
	}
	a.finish("success", 3)
	if len(a.sent()) != 1 {
		t.Fatalf("the same divergence notified twice: %+v", a.sent())
	}
	if data, err := os.ReadFile(filepath.Join(a.state, "failures")); err != nil || strings.TrimSpace(string(data)) != "0" {
		t.Fatalf("a divergence is not a failed load: %q %v", data, err)
	}
}

func TestLoadAlertRetriesADivergenceWhenNtfyIsDown(t *testing.T) {
	a := newAlertRig(t)
	a.ingestExits("3")
	if out, err := a.run(nil, "SERVICE_RESULT=success", "FISCAL_NTFY_URL=http://127.0.0.1:1"); err != nil {
		t.Fatalf("script failed: %v\n%s", err, out)
	}
	if len(a.sent()) != 0 {
		t.Fatalf("nothing can arrive with ntfy down: %+v", a.sent())
	}
	a.finish("success", 1)
	if len(a.sent()) != 1 || !strings.Contains(a.sent()[0].title, "divergiu") {
		t.Fatalf("the divergence must be sent on the next run: %+v", a.sent())
	}
}

func TestLoadAlertForgetsFailuresBelowTheLimit(t *testing.T) {
	a := newAlertRig(t)
	a.finish("exit-code", 5)
	a.finish("success", 1)
	a.finish("exit-code", 5)
	if len(a.sent()) != 0 {
		t.Fatalf("failures that did not run in a row notified: %+v", a.sent())
	}
}

func TestLoadAlertNotifiesOnceOnRecovery(t *testing.T) {
	a := newAlertRig(t)
	a.finish("exit-code", 6)
	a.finish("success", 3)
	if len(a.sent()) != 2 || !strings.Contains(a.sent()[1].title, "voltou") {
		t.Fatalf("recovery notices: %+v", a.sent())
	}
}

func TestLoadAlertNotifiesOnceAboutStaleData(t *testing.T) {
	a := newAlertRig(t)
	a.writeAge(47 * time.Hour)
	a.finish("success", 1)
	if len(a.sent()) != 0 {
		t.Fatalf("data under the limit notified: %+v", a.sent())
	}
	a.writeAge(49 * time.Hour)
	a.finish("success", 3)
	if len(a.sent()) != 1 || !strings.Contains(a.sent()[0].body, "velhos") || strings.Contains(a.sent()[0].title, "falhou") {
		t.Fatalf("stale notices: %+v", a.sent())
	}
	a.writeAge(time.Hour)
	a.finish("success", 2)
	if len(a.sent()) != 2 || !strings.Contains(a.sent()[1].title, "voltou") {
		t.Fatalf("stale recovery notices: %+v", a.sent())
	}
}

func TestLoadAlertDoesNotClaimRecoveryWhileDataIsStale(t *testing.T) {
	a := newAlertRig(t)
	a.finish("exit-code", 6)
	a.writeAge(72 * time.Hour)
	a.finish("success", 2)
	if len(a.sent()) != 1 {
		t.Fatalf("recovery announced with stale data: %+v", a.sent())
	}
}

func TestLoadAlertWithoutTopicKeepsTheLoadAndNotifiesLater(t *testing.T) {
	a := newAlertRig(t)
	if err := os.Remove(filepath.Join(a.root, "secrets", "ntfy-topic")); err != nil {
		t.Fatal(err)
	}
	out := a.finish("exit-code", 6)
	if !strings.Contains(out, "tópico ausente") || len(a.sent()) != 0 {
		t.Fatalf("missing topic: out=%q notices=%+v", out, a.sent())
	}
	a.writeTopic(alertTopic)
	a.finish("exit-code", 1)
	if len(a.sent()) != 1 {
		t.Fatalf("notice after the topic came back: %+v", a.sent())
	}
}

func TestLoadAlertRejectsATopicThatCouldChangeTheRequest(t *testing.T) {
	a := newAlertRig(t)
	a.writeTopic(`x"` + "\n" + `url = "http://elsewhere/`)
	out := a.finish("exit-code", 6)
	if !strings.Contains(out, "inválido") || len(a.sent()) != 0 {
		t.Fatalf("bad topic: out=%q notices=%+v", out, a.sent())
	}
}

func TestLoadAlertRetriesWhenNtfyIsDownAndNeverPrintsTheTopic(t *testing.T) {
	a := newAlertRig(t)
	up := a.url
	a.url = "http://127.0.0.1:1"
	out := a.finish("exit-code", 7)
	if !strings.Contains(out, "ntfy não respondeu") {
		t.Fatalf("no retry log: %q", out)
	}
	if strings.Contains(out, alertTopic) {
		t.Fatalf("topic in the log: %q", out)
	}
	a.url = up
	a.finish("exit-code", 1)
	if len(a.sent()) != 1 {
		t.Fatalf("no notice once ntfy came back: %+v", a.sent())
	}
}

func TestLoadAlertNoticesCarryNoPersonalDataOrPaths(t *testing.T) {
	a := newAlertRig(t)
	a.finish("exit-code", 6)
	a.finish("success", 1)
	a.writeAge(49 * time.Hour)
	a.finish("success", 1)
	if len(a.sent()) != 3 {
		t.Fatalf("expected 3 notices, got %+v", a.sent())
	}
	for _, n := range a.sent() {
		text := n.title + " " + n.body
		if strings.Contains(text, "/") || strings.Contains(text, alertTopic) || strings.Contains(text, "@") {
			t.Fatalf("notice leaks something: %q", text)
		}
	}
}

func TestLoadAlertTestModeSendsAndReportsAMissingTopic(t *testing.T) {
	a := newAlertRig(t)
	if out, err := a.run([]string{"--test"}); err != nil || len(a.sent()) != 1 {
		t.Fatalf("test mode: err=%v out=%q notices=%+v", err, out, a.sent())
	}
	if err := os.Remove(filepath.Join(a.root, "secrets", "ntfy-topic")); err != nil {
		t.Fatal(err)
	}
	if out, err := a.run([]string{"--test"}); err == nil {
		t.Fatalf("test mode hid a missing topic: %q", out)
	}
}

func TestSyncUnitRunsTheAlertWithoutChangingTheResult(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("systemd", "fiscal-sync.service"))
	if err != nil {
		t.Fatal(err)
	}
	unit := string(data)
	for _, want := range []string{"ExecStopPost=-/opt/fiscal-api/fiscal-load-alert.sh", "StateDirectory=fiscal-load-alert", `echo $$? > "$$STATE_DIRECTORY/ingest-exit"`} {
		if !strings.Contains(unit, want) {
			t.Fatalf("unit misses %q", want)
		}
	}
}
