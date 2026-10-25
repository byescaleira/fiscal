package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	_ "time/tzdata"

	"liveresults/internal/ingest"
	"liveresults/internal/sources/fetch"
)

var knownSources = []string{"camara", "senado", "tse", "ibge", "receita", "assembleias"}

var knownUFs = map[string]bool{}

func init() {
	for _, uf := range strings.Fields("ac al ap am ba ce df es go ma mt ms mg pa pb pr pe pi rj rn rs ro rr sc sp se to") {
		knownUFs[uf] = true
	}
}

type config struct {
	ingest   ingest.Config
	fullAt   [2]int
	live     time.Duration
	gap      time.Duration
	timeout  time.Duration
	location *time.Location
}

func parseYears(v string, def []int) ([]int, error) {
	v = strings.TrimSpace(v)
	if v == "" {
		return def, nil
	}
	set := map[int]bool{}
	for _, part := range strings.Split(v, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		lo, hi, isRange := strings.Cut(part, "-")
		a, err := strconv.Atoi(lo)
		if err != nil {
			return nil, fmt.Errorf("invalid year %q", part)
		}
		b := a
		if isRange {
			if b, err = strconv.Atoi(hi); err != nil {
				return nil, fmt.Errorf("invalid year %q", part)
			}
		}
		if a < 2000 || b > 2100 || b < a {
			return nil, fmt.Errorf("invalid year range %q", part)
		}
		for y := a; y <= b; y++ {
			set[y] = true
		}
	}
	out := make([]int, 0, len(set))
	for y := range set {
		out = append(out, y)
	}
	sort.Ints(out)
	return out, nil
}

func loadConfig(getenv func(string) string, now time.Time) (config, error) {
	loc, err := time.LoadLocation("America/Sao_Paulo")
	if err != nil {
		return config{}, err
	}
	year := now.In(loc).Year()
	c := config{location: loc, live: 10 * time.Minute, gap: 150 * time.Millisecond, timeout: 120 * time.Second, fullAt: [2]int{6, 30}}
	c.ingest.PublicDir = envOr(getenv, "PUBLIC_DIR", "./public")
	c.ingest.DataDir = envOr(getenv, "DATA_DIR", "./data")
	legislature := []int{}
	for y := 2023; y <= year; y++ {
		legislature = append(legislature, y)
	}
	if c.ingest.Years, err = parseYears(getenv("INGEST_YEARS"), legislature); err != nil {
		return c, fmt.Errorf("INGEST_YEARS: %w", err)
	}
	for _, y := range c.ingest.Years {
		if y > year {
			return c, fmt.Errorf("INGEST_YEARS: %d is in the future", y)
		}
	}
	if c.ingest.TSEYears, err = parseYears(getenv("TSE_YEARS"), []int{2022, 2026}); err != nil {
		return c, fmt.Errorf("TSE_YEARS: %w", err)
	}
	for _, y := range c.ingest.TSEYears {
		if y%4 != 2 {
			return c, fmt.Errorf("TSE_YEARS: %d is not a general election year", y)
		}
	}
	if c.ingest.TSECandidateYears, err = parseYears(getenv("TSE_CANDIDATE_YEARS"), []int{2018}); err != nil {
		return c, fmt.Errorf("TSE_CANDIDATE_YEARS: %w", err)
	}
	if v := strings.TrimSpace(getenv("INGEST_UFS")); v != "" {
		for _, uf := range strings.Split(strings.ToLower(v), ",") {
			uf = strings.TrimSpace(uf)
			if !knownUFs[uf] {
				return c, fmt.Errorf("INGEST_UFS: unknown UF %q", uf)
			}
			c.ingest.UFs = append(c.ingest.UFs, uf)
		}
	}
	if v := strings.TrimSpace(getenv("INGEST_SOURCES")); v != "" {
		c.ingest.Sources = map[string]bool{}
		for _, s := range strings.Split(strings.ToLower(v), ",") {
			s = strings.TrimSpace(s)
			ok := false
			for _, k := range knownSources {
				ok = ok || k == s
			}
			if !ok {
				return c, fmt.Errorf("INGEST_SOURCES: unknown source %q (known: %s)", s, strings.Join(knownSources, ", "))
			}
			c.ingest.Sources[s] = true
		}
	}
	if v := strings.TrimSpace(getenv("INGEST_FULL_AT")); v != "" {
		h, m, ok := strings.Cut(v, ":")
		hh, err1 := strconv.Atoi(h)
		mm, err2 := strconv.Atoi(m)
		if !ok || err1 != nil || err2 != nil || hh < 0 || hh > 23 || mm < 0 || mm > 59 {
			return c, fmt.Errorf("INGEST_FULL_AT %q must be HH:MM (Brasília time)", v)
		}
		c.fullAt = [2]int{hh, mm}
	}
	if v := strings.TrimSpace(getenv("INGEST_LIVE_INTERVAL")); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d < 2*time.Minute || d > time.Hour {
			return c, errors.New("INGEST_LIVE_INTERVAL must be a duration between 2m and 1h")
		}
		c.live = d
	}
	if v := strings.TrimSpace(getenv("INGEST_REQUEST_GAP")); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d < 50*time.Millisecond || d > 10*time.Second {
			return c, errors.New("INGEST_REQUEST_GAP must be a duration between 50ms and 10s")
		}
		c.gap = d
	}
	c.ingest.Workers = 4
	if v := strings.TrimSpace(getenv("INGEST_WORKERS")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 16 {
			return c, errors.New("INGEST_WORKERS must be between 1 and 16")
		}
		c.ingest.Workers = n
	}
	return c, nil
}

func envOr(getenv func(string) string, name, def string) string {
	if v := strings.TrimSpace(getenv(name)); v != "" {
		return v
	}
	return def
}

func nextFull(now time.Time, at [2]int, loc *time.Location) time.Time {
	l := now.In(loc)
	t := time.Date(l.Year(), l.Month(), l.Day(), at[0], at[1], 0, 0, loc)
	if !t.After(now) {
		t = t.AddDate(0, 0, 1)
	}
	return t
}

type status struct {
	Heartbeat string `json:"heartbeat"`
	LastFull  string `json:"lastFull,omitempty"`
	LastLive  string `json:"lastLive,omitempty"`
	LastError string `json:"lastError,omitempty"`
	People    int    `json:"people,omitempty"`
	Files     int    `json:"files,omitempty"`
}

func statusPath(dataDir string) string {
	return filepath.Join(dataDir, "ingest-status.json")
}

func writeStatus(dataDir string, s status) {
	data, err := json.Marshal(s)
	if err != nil {
		return
	}
	tmp := statusPath(dataDir) + ".tmp"
	if os.WriteFile(tmp, data, 0o600) == nil {
		os.Rename(tmp, statusPath(dataDir))
	}
}

func check(dataDir string, now time.Time, maxAge time.Duration) int {
	data, err := os.ReadFile(statusPath(dataDir))
	if err != nil {
		return 1
	}
	var s status
	if json.Unmarshal(data, &s) != nil {
		return 1
	}
	t, err := time.Parse(time.RFC3339, s.Heartbeat)
	if err != nil || now.Sub(t) > maxAge {
		return 1
	}
	return 0
}

func main() {
	once := flag.Bool("once", false, "run one full load, publish and exit")
	healthCheck := flag.Bool("check", false, "exit 0 when the scheduler wrote a heartbeat recently")
	flag.Parse()
	log.SetFlags(log.LstdFlags | log.LUTC)
	cfg, err := loadConfig(os.Getenv, time.Now())
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	if *healthCheck {
		os.Exit(check(cfg.ingest.DataDir, time.Now(), 2*cfg.live+5*time.Minute))
	}
	if err := os.MkdirAll(cfg.ingest.DataDir, 0o700); err != nil {
		log.Fatalf("data dir: %v", err)
	}
	if err := os.MkdirAll(filepath.Join(cfg.ingest.PublicDir, "v1"), 0o755); err != nil {
		log.Fatalf("public dir: %v", err)
	}
	client := fetch.New(filepath.Join(cfg.ingest.DataDir, "cache", "http"), cfg.timeout)
	client.Gap = cfg.gap
	in := ingest.New(cfg.ingest, client, nil, nil)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	log.Printf("ingest years=%v tse=%v+%v ufs=%v sources=%v live=%s fullAt=%02d:%02d", cfg.ingest.Years, cfg.ingest.TSEYears, cfg.ingest.TSECandidateYears, cfg.ingest.UFs, keys(cfg.ingest.Sources), cfg.live, cfg.fullAt[0], cfg.fullAt[1])
	if *once {
		rep, err := in.Full(ctx)
		logReport("full", rep, err)
		if err != nil {
			os.Exit(1)
		}
		return
	}
	run(ctx, in, cfg)
}

func keys(m map[string]bool) []string {
	if len(m) == 0 {
		return []string{"all"}
	}
	var out []string
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func logReport(kind string, rep ingest.Report, err error) {
	if err != nil {
		log.Printf("%s load failed, nothing new published: %v", kind, err)
		return
	}
	log.Printf("%s load ok: people=%d votes=%d files=%d written=%d removed=%d json=%s gzip=%s warnings=%d in %s", kind, rep.People, rep.Votes, rep.Files, rep.Written, rep.Removed, mib(rep.Bytes), mib(rep.Gzip), len(rep.Warnings), rep.Duration.Round(time.Second))
}

func mib(n int64) string {
	return strconv.FormatFloat(float64(n)/(1<<20), 'f', 1, 64) + " MiB"
}

func run(ctx context.Context, in *ingest.Ingest, cfg config) {
	var mu sync.Mutex
	st := status{}
	beat := func() {
		mu.Lock()
		defer mu.Unlock()
		st.Heartbeat = time.Now().UTC().Format(time.RFC3339)
		writeStatus(cfg.ingest.DataDir, st)
	}
	beat()
	go func() {
		t := time.NewTicker(time.Minute)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				beat()
			}
		}
	}()
	retry := []time.Duration{5 * time.Minute, 15 * time.Minute, 30 * time.Minute}
	attempt := 0
	loaded := false
	full := func() {
		rep, err := in.Full(ctx)
		logReport("full", rep, err)
		mu.Lock()
		defer mu.Unlock()
		if err != nil {
			st.LastError = err.Error()
			return
		}
		loaded = true
		attempt = 0
		st.LastFull, st.LastError, st.People, st.Files = time.Now().UTC().Format(time.RFC3339), "", rep.People, rep.Files
	}
	full()
	beat()
	due := nextFull(time.Now(), cfg.fullAt, cfg.location)
	if !loaded {
		due = time.Now().Add(retry[0])
		attempt = 1
	}
	ticker := time.NewTicker(cfg.live)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Printf("ingest stopping")
			return
		case <-ticker.C:
		}
		now := time.Now()
		if !now.Before(due) {
			full()
			mu.Lock()
			failed := st.LastError != ""
			mu.Unlock()
			if loaded && !failed {
				due = nextFull(now, cfg.fullAt, cfg.location)
			} else {
				due = now.Add(retry[min(attempt, len(retry)-1)])
				attempt++
			}
		} else if loaded {
			rep, err := in.Live(ctx)
			if err != nil {
				log.Printf("live refresh failed: %v", err)
			} else {
				mu.Lock()
				st.LastLive = now.UTC().Format(time.RFC3339)
				mu.Unlock()
				if rep.Written > 0 {
					log.Printf("live refresh: written=%d warnings=%d", rep.Written, len(rep.Warnings))
				}
			}
		}
		beat()
	}
}
