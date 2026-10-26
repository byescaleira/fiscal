package pages

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"liveresults/internal/site"
)

const (
	StateFile      = "pages-state.json"
	DeployDir      = "deploy"
	deployedMarker = "Deployment complete"
	FreeFiles      = 20000
)

type Runner func(ctx context.Context, name string, args, env []string) ([]byte, error)

type Config struct {
	PublicDir    string
	DataDir      string
	Project      string
	Branch       string
	AccountID    string
	Token        string
	Wrangler     string
	DataInterval time.Duration
	MaxPerDay    int
	Timeout      time.Duration
	Attempts     int
	Backoff      time.Duration
	DryRun       bool
	Force        bool
	Now          func() time.Time
	Logger       *log.Logger
	Run          Runner
}

type State struct {
	Release    string         `json:"release"`
	RacesHash  string         `json:"racesHash"`
	StatusHash string         `json:"statusHash"`
	DeployedAt string         `json:"deployedAt"`
	DataAt     string         `json:"dataAt"`
	Days       map[string]int `json:"days"`
}

type Outcome struct {
	Deployed bool
	Reason   string
	Release  string
	Files    int
	Dir      string
}

var ErrBudget = errors.New("daily deploy budget reached")

func (c *Config) now() time.Time {
	if c.Now == nil {
		return time.Now()
	}
	return c.Now()
}

func (c *Config) logf(format string, args ...any) {
	if c.Logger != nil {
		c.Logger.Printf(format, args...)
	}
}

func (c *Config) statePath() string {
	return filepath.Join(c.DataDir, StateFile)
}

func (c *Config) LoadState() (State, error) {
	st := State{Days: map[string]int{}}
	data, err := os.ReadFile(c.statePath())
	if errors.Is(err, fs.ErrNotExist) {
		return st, nil
	}
	if err != nil {
		return st, err
	}
	if err := json.Unmarshal(data, &st); err != nil {
		return st, fmt.Errorf("pages state: %w", err)
	}
	if st.Days == nil {
		st.Days = map[string]int{}
	}
	return st, nil
}

func (c *Config) saveState(st State) error {
	if err := os.MkdirAll(c.DataDir, 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(st)
	if err != nil {
		return err
	}
	tmp := c.statePath() + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, c.statePath())
}

func liveFiles(staging string) ([]string, error) {
	var out []string
	for _, name := range []string{"races.json", "status.json"} {
		if _, err := os.Stat(filepath.Join(staging, name)); err == nil {
			out = append(out, name)
		}
	}
	entries, err := os.ReadDir(filepath.Join(staging, "races"))
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".json") && !strings.HasPrefix(e.Name(), ".") {
			out = append(out, "races/"+e.Name())
		}
	}
	sort.Strings(out)
	return out, nil
}

func hashFiles(staging string, names []string) (string, error) {
	h := sha256.New()
	for _, n := range names {
		data, err := os.ReadFile(filepath.Join(staging, filepath.FromSlash(n)))
		if err != nil {
			return "", err
		}
		if !json.Valid(data) {
			return "", fmt.Errorf("%s is not valid JSON", n)
		}
		fmt.Fprintf(h, "%s\x00%d\x00", n, len(data))
		h.Write(data)
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func (c *Config) Cycle(ctx context.Context) (Outcome, error) {
	stager := site.Stager{Root: filepath.Join(c.PublicDir, "site")}
	current, err := stager.CurrentName()
	if err != nil {
		return Outcome{}, err
	}
	if current == "" {
		return Outcome{Reason: "no staged site yet"}, nil
	}
	siteDir := filepath.Join(c.PublicDir, "site", site.SitesDir, current)
	rel, err := site.ReadRelease(siteDir)
	if err != nil {
		return Outcome{}, err
	}
	staging := filepath.Join(c.PublicDir, "v1")
	files, err := liveFiles(staging)
	if err != nil {
		return Outcome{}, err
	}
	var races, status []string
	for _, f := range files {
		if f == "status.json" {
			status = append(status, f)
		} else {
			races = append(races, f)
		}
	}
	racesHash, err := hashFiles(staging, races)
	if err != nil {
		return Outcome{}, err
	}
	statusHash, err := hashFiles(staging, status)
	if err != nil {
		return Outcome{}, err
	}
	st, err := c.LoadState()
	if err != nil {
		return Outcome{}, err
	}
	now := c.now()
	out := Outcome{Release: current}
	dataChanged := current != st.Release
	racesChanged := racesHash != st.RacesHash
	if !dataChanged && !racesChanged && !c.Force {
		out.Reason = "nothing changed"
		return out, nil
	}
	if dataChanged && !racesChanged && !c.Force && rel.Kind == "live" && current > st.Release {
		if last, err := time.Parse(time.RFC3339, st.DataAt); err == nil && now.Sub(last) < c.DataInterval {
			out.Reason = "data waits for the interval (" + c.DataInterval.String() + ")"
			return out, nil
		}
	}
	day := now.UTC().Format("2006-01-02")
	if c.MaxPerDay > 0 && st.Days[day] >= c.MaxPerDay {
		return out, fmt.Errorf("%w (%d today)", ErrBudget, st.Days[day])
	}
	dir := filepath.Join(c.PublicDir, DeployDir, current+"-"+strconv.FormatInt(now.Unix(), 10))
	os.RemoveAll(filepath.Join(c.PublicDir, DeployDir))
	count, err := assemble(siteDir, dir, staging, files)
	if err != nil {
		os.RemoveAll(dir)
		return out, err
	}
	out.Files, out.Dir = count, dir
	if count > FreeFiles {
		os.RemoveAll(dir)
		return out, fmt.Errorf("%d files, the Pages free plan accepts %d", count, FreeFiles)
	}
	if c.DryRun {
		out.Reason = "dry run"
		c.logf("dry run: would deploy %s (%d files, data=%v races=%v) to %s/%s", current, count, dataChanged, racesChanged, c.Project, c.Branch)
		return out, nil
	}
	defer os.RemoveAll(dir)
	if err := c.deploy(ctx, dir, current); err != nil {
		return out, err
	}
	out.Deployed = true
	if dataChanged {
		st.DataAt = now.UTC().Format(time.RFC3339)
	}
	st.Release, st.RacesHash, st.StatusHash, st.DeployedAt = current, racesHash, statusHash, now.UTC().Format(time.RFC3339)
	st.Days[day]++
	for d := range st.Days {
		if t, err := time.Parse("2006-01-02", d); err != nil || now.Sub(t) > 72*time.Hour {
			delete(st.Days, d)
		}
	}
	if err := c.saveState(st); err != nil {
		return out, err
	}
	c.logf("deployed %s to %s/%s: files=%d data=%v races=%v today=%d", current, c.Project, c.Branch, count, dataChanged, racesChanged, st.Days[day])
	return out, nil
}

func assemble(siteDir, dir, staging string, live []string) (int, error) {
	count := 0
	err := filepath.WalkDir(siteDir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(siteDir, p)
		if err != nil {
			return err
		}
		dst := filepath.Join(dir, rel)
		if d.IsDir() {
			return os.MkdirAll(dst, 0o755)
		}
		count++
		if err := os.Link(p, dst); err == nil {
			return nil
		}
		return copyFile(p, dst)
	})
	if err != nil {
		return 0, err
	}
	for _, f := range live {
		if err := copyFile(filepath.Join(staging, filepath.FromSlash(f)), filepath.Join(dir, site.Layout, filepath.FromSlash(f))); err != nil {
			return 0, err
		}
		count++
	}
	return count, nil
}

func copyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func (c *Config) deploy(ctx context.Context, dir, release string) error {
	timeout := c.Timeout
	if timeout <= 0 {
		timeout = 20 * time.Minute
	}
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	args := []string{"pages", "deploy", dir, "--project-name=" + c.Project, "--branch=" + c.Branch, "--commit-dirty=true", "--commit-message=" + release}
	home := filepath.Join(os.TempDir(), "wrangler-home")
	env := []string{
		"CLOUDFLARE_API_TOKEN=" + c.Token,
		"CLOUDFLARE_ACCOUNT_ID=" + c.AccountID,
		"WRANGLER_SEND_METRICS=false",
		"HOME=" + home,
		"XDG_CONFIG_HOME=" + home,
		"PATH=/usr/local/bin:/usr/bin:/bin",
		"NODE_OPTIONS=--max-old-space-size=2048",
	}
	run := c.Run
	if run == nil {
		run = execRunner
	}
	attempts := max(c.Attempts, 1)
	var last error
	for i := range attempts {
		if i > 0 {
			wait := c.Backoff * time.Duration(1<<(i-1))
			c.logf("deploy attempt %d failed, retrying in %s: %v", i, wait, last)
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(wait):
			}
		}
		output, err := run(ctx, c.Wrangler, args, env)
		if err == nil && strings.Contains(string(output), deployedMarker) {
			return nil
		}
		if err == nil {
			err = errors.New("finished without a deployment")
		}
		last = fmt.Errorf("wrangler pages deploy: %w: %s", err, tail(redact(string(output), c.Token), 2000))
	}
	return last
}

func execRunner(ctx context.Context, name string, args, env []string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = env
	return cmd.CombinedOutput()
}

func redact(s, secret string) string {
	if secret == "" {
		return s
	}
	return strings.ReplaceAll(s, secret, "[redacted]")
}

func tail(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[len(s)-n:]
}
