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

	"liveresults/internal/datastore"
	"liveresults/internal/ingest"
	"liveresults/internal/sources/fetch"
	"liveresults/internal/sources/tse"
)

var knownSources = []string{"camara", "senado", "tse", "ibge", "receita", "assembleias", "comprova", "cidades"}

var knownUFs = map[string]bool{}

func init() {
	for _, uf := range strings.Fields("ac al ap am ba ce df es go ma mt ms mg pa pb pr pe pi rj rn rs ro rr sc sp se to") {
		knownUFs[uf] = true
	}
}

type config struct {
	ingest     ingest.Config
	storePath  string
	backupDir  string
	backupKeep int
	fullAt     [2]int
	live       time.Duration
	gap        time.Duration
	timeout    time.Duration
	location   *time.Location
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
	c.storePath = envOr(getenv, "STORE_PATH", filepath.Join(c.ingest.DataDir, datastore.FileName))
	if !strings.HasSuffix(c.storePath, ".db") {
		return c, errors.New("STORE_PATH must be a path ending in .db")
	}
	c.backupDir = filepath.Join(c.ingest.DataDir, "backups")
	c.backupKeep = datastore.DefaultBackup
	if v := strings.TrimSpace(getenv("BACKUP_KEEP")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 365 {
			return c, errors.New("BACKUP_KEEP must be between 1 and 365")
		}
		c.backupKeep = n
	}
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
	c.ingest.CityYear = 2024
	if v := strings.TrimSpace(getenv("TSE_CITY_YEAR")); v != "" {
		y, err := strconv.Atoi(v)
		if err != nil || !tse.MunicipalYear(y) || y > year {
			return c, fmt.Errorf("TSE_CITY_YEAR: %q is not a past municipal election year", v)
		}
		c.ingest.CityYear = y
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
	if v := strings.TrimSpace(getenv("COMPROVA_SINCE")); v != "" {
		d, err := time.ParseInLocation("2006-01-02", v, loc)
		if err != nil || d.Year() < 2018 || d.After(now) {
			return c, errors.New("COMPROVA_SINCE must be a date (YYYY-MM-DD) from 2018 up to today")
		}
		c.ingest.ChecksSince = v
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
	restore := flag.String("restore", "", "replace the store with this backup (stop the scheduler first) and exit")
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
	if *restore != "" {
		if err := datastore.Restore(context.Background(), *restore, cfg.storePath); err != nil {
			log.Fatalf("restore: %v", err)
		}
		log.Printf("restored %s from %s", cfg.storePath, filepath.Base(*restore))
		return
	}
	db, err := datastore.Open(cfg.storePath, nil)
	if err != nil {
		log.Fatalf("store: %v", err)
	}
	defer db.Close()
	if err := os.MkdirAll(filepath.Join(cfg.ingest.PublicDir, "v1"), 0o755); err != nil {
		log.Fatalf("public dir: %v", err)
	}
	client := fetch.New(filepath.Join(cfg.ingest.DataDir, "cache", "http"), cfg.timeout)
	client.Gap = cfg.gap
	in := ingest.New(cfg.ingest, client, nil, nil)
	in.UseStore(db)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	log.Printf("ingest years=%v tse=%v+%v ufs=%v sources=%v live=%s fullAt=%02d:%02d", cfg.ingest.Years, cfg.ingest.TSEYears, cfg.ingest.TSECandidateYears, cfg.ingest.UFs, keys(cfg.ingest.Sources), cfg.live, cfg.fullAt[0], cfg.fullAt[1])
	if *once {
		rep, err := in.Full(ctx)
		logReport("full", rep, err)
		if err != nil {
			db.Close()
			os.Exit(1)
		}
		backup(ctx, db, in, cfg)
		return
	}
	run(ctx, in, db, cfg)
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
	log.Printf("%s load ok: people=%d cities=%d cityPeople=%d votes=%d checks=%d checkPeople=%d checkLinks=%d checkReviews=%d files=%d written=%d removed=%d json=%s gzip=%s warnings=%d in %s", kind, rep.People, rep.Cities, rep.CityPeople, rep.Votes, rep.Checks, rep.CheckPeople, rep.CheckLinks, rep.Reviews, rep.Files, rep.Written, rep.Removed, mib(rep.Bytes), mib(rep.Gzip), len(rep.Warnings), rep.Duration.Round(time.Second))
}

func mib(n int64) string {
	return strconv.FormatFloat(float64(n)/(1<<20), 'f', 1, 64) + " MiB"
}

func backup(ctx context.Context, db *datastore.Store, in *ingest.Ingest, cfg config) {
	started := time.Now()
	day := started.In(cfg.location).Format("2006-01-02")
	path, size, err := db.Backup(ctx, cfg.backupDir, day, cfg.backupKeep)
	status := datastore.StatusOK
	if err != nil {
		status = datastore.StatusFailed
		log.Printf("backup failed: %v", err)
	} else {
		log.Printf("backup ok: %s (%s, keeping %d)", filepath.Base(path), mib(size), cfg.backupKeep)
	}
	if e := db.Record(context.WithoutCancel(ctx), "backup", "backup", status, started, map[string]int{"kib": int(size >> 10), "keep": cfg.backupKeep}, err); e != nil {
		log.Printf("backup record: %v", e)
	}
	in.WriteStatus(context.WithoutCancel(ctx))
}

func run(ctx context.Context, in *ingest.Ingest, db *datastore.Store, cfg config) {
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
		if err != nil {
			st.LastError = err.Error()
			mu.Unlock()
			return
		}
		loaded = true
		attempt = 0
		st.LastFull, st.LastError, st.People, st.Files = time.Now().UTC().Format(time.RFC3339), "", rep.People, rep.Files
		mu.Unlock()
		backup(ctx, db, in, cfg)
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
