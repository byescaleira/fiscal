package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"liveresults/internal/jobctl"
	"liveresults/internal/pages"
)

var (
	projectName = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,57}$`)
	accountID   = regexp.MustCompile(`^[0-9a-f]{32}$`)
)

func loadConfig(getenv func(string) string, dryRun bool) (pages.Config, error) {
	c := pages.Config{
		PublicDir:    envOr(getenv, "PUBLIC_DIR", "./public"),
		DataDir:      envOr(getenv, "DATA_DIR", "./data"),
		Project:      strings.TrimSpace(getenv("PAGES_PROJECT")),
		Branch:       envOr(getenv, "PAGES_BRANCH", "main"),
		AccountID:    strings.TrimSpace(getenv("CLOUDFLARE_ACCOUNT_ID")),
		Wrangler:     envOr(getenv, "WRANGLER", "/usr/local/bin/wrangler"),
		DataInterval: time.Hour,
		MaxPerDay:    400,
		MaxPerMonth:  450,
		Attempts:     3,
		Backoff:      30 * time.Second,
		DryRun:       dryRun,
	}
	if !projectName.MatchString(c.Project) {
		return c, errors.New("PAGES_PROJECT must be the Pages project name (lowercase letters, digits and hyphens)")
	}
	if !projectName.MatchString(c.Branch) {
		return c, errors.New("PAGES_BRANCH is invalid")
	}
	if v := strings.TrimSpace(getenv("PAGES_DATA_INTERVAL")); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d < 10*time.Minute || d > 24*time.Hour {
			return c, errors.New("PAGES_DATA_INTERVAL must be a duration between 10m and 24h")
		}
		c.DataInterval = d
	}
	if v := strings.TrimSpace(getenv("PAGES_MAX_DEPLOYS_PER_DAY")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 2000 {
			return c, errors.New("PAGES_MAX_DEPLOYS_PER_DAY must be between 1 and 2000")
		}
		c.MaxPerDay = n
	}
	if v := strings.TrimSpace(getenv("PAGES_MAX_DEPLOYS_PER_MONTH")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 0 || n > 100000 {
			return c, errors.New("PAGES_MAX_DEPLOYS_PER_MONTH must be between 0 (no monthly cap) and 100000")
		}
		c.MaxPerMonth = n
	}
	if dryRun {
		return c, nil
	}
	if !accountID.MatchString(c.AccountID) {
		return c, errors.New("CLOUDFLARE_ACCOUNT_ID must be the 32-character account id")
	}
	file := envOr(getenv, "CLOUDFLARE_API_TOKEN_FILE", "/secrets/cloudflare-pages-token")
	data, err := os.ReadFile(file)
	if err != nil {
		return c, fmt.Errorf("CLOUDFLARE_API_TOKEN_FILE: %w", err)
	}
	c.Token = strings.TrimSpace(string(data))
	if len(c.Token) < 20 || strings.ContainsAny(c.Token, " \n\r\t") {
		return c, errors.New("CLOUDFLARE_API_TOKEN_FILE must hold only the API token")
	}
	return c, nil
}

func envOr(getenv func(string) string, name, def string) string {
	if v := strings.TrimSpace(getenv(name)); v != "" {
		return v
	}
	return def
}

func main() {
	dryRun := flag.Bool("dry-run", false, "assemble the site and print the plan without deploying")
	force := flag.Bool("force", false, "deploy now even without changes or before the data interval")
	configCheck := flag.Bool("config-check", false, "validate the configuration (and the token file) and exit")
	flag.Parse()
	log.SetFlags(log.LstdFlags | log.LUTC)
	cfg, err := loadConfig(os.Getenv, *dryRun)
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	if *configCheck {
		log.Printf("config ok: project=%s branch=%s", cfg.Project, cfg.Branch)
		return
	}
	cfg.Force = *force
	cfg.Logger = log.Default()
	if err := jobctl.Background(10); err != nil {
		log.Printf("priority: %v", err)
	}
	if err := os.MkdirAll(cfg.DataDir, 0o700); err != nil {
		log.Fatalf("data dir: %v", err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	lock, err := jobctl.Acquire(ctx, filepath.Join(cfg.DataDir, "pages.lock"), 0)
	if errors.Is(err, jobctl.ErrBusy) {
		log.Printf("skipped: another deploy is running")
		return
	}
	if err != nil {
		log.Fatalf("lock: %v", err)
	}
	defer lock.Release()
	out, err := cfg.Cycle(ctx)
	if err != nil {
		lock.Release()
		log.Fatalf("deploy failed, the site on Pages did not change: %v", err)
	}
	if !out.Deployed {
		log.Printf("no deploy: %s", out.Reason)
	}
}
