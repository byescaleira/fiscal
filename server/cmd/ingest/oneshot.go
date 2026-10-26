package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"liveresults/internal/datastore"
	"liveresults/internal/ingest"
	"liveresults/internal/jobctl"
	"liveresults/internal/sources/fetch"
)

const exitBusy = 75

func main() {
	var once onceFlag
	flag.Var(&once, "once", "run one load (full, the default, or live), stage the site and exit")
	healthCheck := flag.Bool("check", false, "exit 0 when the scheduler wrote a heartbeat recently")
	restore := flag.String("restore", "", "replace the store with this backup (stop the timers first) and exit")
	siteCmd := flag.String("site", "", "status or rollback: inspect or move the staged site that the Pages job deploys")
	to := flag.String("to", "", "with -site rollback: the site to go back to (default: the one before the current)")
	allowDrop := flag.Bool("allow-drop", false, "accept a release with more than SITE_MAX_DROP fewer files or people (this run only)")
	configCheck := flag.Bool("config-check", false, "validate the configuration and exit")
	phaseName := flag.String("phase", "", "run one phase ("+strings.Join(ingest.PhaseNames(), ", ")+"): refresh only its sources, rebuild the site from the store and exit")
	flag.Parse()
	log.SetFlags(log.LstdFlags | log.LUTC)
	kind, err := onceKind(once, flag.Args())
	if err != nil {
		log.Fatalf("flags: %v", err)
	}
	cfg, err := loadConfig(os.Getenv, time.Now())
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	cfg.site.AllowDrop = *allowDrop
	if *phaseName != "" {
		if kind != "" {
			log.Fatalf("flags: -phase and -once are exclusive")
		}
		ph, ok := ingest.PhaseByName(*phaseName)
		if !ok {
			log.Fatalf("flags: unknown phase %q (known: %s)", *phaseName, strings.Join(ingest.PhaseNames(), ", "))
		}
		kind = "full"
		cfg.ingest.Refresh = ph.Refresh()
		cfg.ingest.ReleaseKind = ph.Name
	}
	switch {
	case *configCheck:
		log.Printf("config ok")
		return
	case *healthCheck:
		os.Exit(check(cfg.ingest.DataDir, time.Now(), 2*cfg.live+5*time.Minute))
	case *siteCmd != "":
		os.Exit(siteCommand(cfg, *siteCmd, *to))
	}
	if err := os.MkdirAll(cfg.ingest.DataDir, 0o700); err != nil {
		log.Fatalf("data dir: %v", err)
	}
	if cfg.nice > 0 {
		if err := jobctl.Background(cfg.nice); err != nil {
			log.Printf("priority: %v", err)
		}
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if kind != "" {
		r, err := cfg.capacity.WaitFor(ctx)
		if err != nil {
			log.Printf("skipped: %v; the next window tries again", err)
			return
		}
		log.Printf("capacity ok: %s", r)
	}
	wait := cfg.lockWait
	if kind == "live" {
		wait = 0
	}
	lockPath := filepath.Join(cfg.ingest.DataDir, "ingest.lock")
	lock, err := jobctl.Acquire(ctx, lockPath, wait)
	if errors.Is(err, jobctl.ErrBusy) {
		log.Printf("skipped: another load holds %s", lockPath)
		if kind == "live" {
			return
		}
		os.Exit(exitBusy)
	}
	if err != nil {
		log.Fatalf("lock: %v", err)
	}
	code := runLocked(ctx, cfg, kind, *restore)
	lock.Release()
	stop()
	os.Exit(code)
}

func siteCommand(cfg config, cmd, to string) int {
	st := cfg.stager()
	switch cmd {
	case "status":
		cur, ok, err := st.Current()
		if err != nil {
			log.Printf("site: %v", err)
			return 1
		}
		names, _ := st.Names()
		if !ok {
			log.Printf("no staged site yet; kept: %v", names)
			return 0
		}
		log.Printf("ready: %s (%s, %d files, %d logical, %d people, generated %s); kept: %v", cur.Release, cur.Kind, cur.Files, cur.Logical, cur.People, cur.GeneratedAt, names)
		return 0
	case "rollback":
		name, err := st.Rollback(to)
		if err != nil {
			log.Printf("site: %v", err)
			return 1
		}
		log.Printf("ready now points to %s; the Pages job deploys it on its next run", name)
		return 0
	}
	log.Printf("-site takes status or rollback")
	return 2
}

func runLocked(ctx context.Context, cfg config, kind, restore string) int {
	if restore != "" {
		if err := datastore.Restore(context.Background(), restore, cfg.storePath); err != nil {
			log.Printf("restore: %v", err)
			return 1
		}
		log.Printf("restored %s from %s", cfg.storePath, filepath.Base(restore))
		return 0
	}
	db, err := datastore.Open(cfg.storePath, nil)
	if err != nil {
		log.Printf("store: %v", err)
		return 1
	}
	defer db.Close()
	if err := os.MkdirAll(filepath.Join(cfg.ingest.PublicDir, "v1"), 0o755); err != nil {
		log.Printf("public dir: %v", err)
		return 1
	}
	client := fetch.New(filepath.Join(cfg.ingest.DataDir, "cache", "http"), cfg.timeout)
	client.Gap = cfg.gap
	in := ingest.New(cfg.ingest, client, nil, nil)
	in.UseStore(db)
	in.UseSite(cfg.stager())
	log.Printf("ingest mode=%s phase=%s years=%v tse=%v+%v ufs=%v sources=%v live=%s fullAt=%02d:%02d site=min%d/drop%.0f%%/max%d", modeName(kind), cfg.ingest.ReleaseKind, cfg.ingest.Years, cfg.ingest.TSEYears, cfg.ingest.TSECandidateYears, cfg.ingest.UFs, keys(cfg.ingest.Sources), cfg.live, cfg.fullAt[0], cfg.fullAt[1], cfg.site.MinPeople, cfg.site.MaxDrop*100, cfg.site.MaxFiles)
	switch kind {
	case "full":
		rep, err := in.Full(ctx)
		logReport("full", rep, err)
		if err != nil {
			return 1
		}
		if err := in.SaveSnapshot(); err != nil {
			log.Printf("snapshot: %v (the next live run waits for another full load)", err)
		}
		backup(ctx, db, in, cfg)
		return 0
	case "live":
		if err := in.LoadSnapshot(); errors.Is(err, ingest.ErrNoSnapshot) {
			log.Printf("skipped: no full load yet")
			return 0
		} else if err != nil {
			log.Printf("snapshot: %v", err)
			return 1
		}
		rep, err := in.Live(ctx)
		logReport("live", rep, err)
		if err != nil {
			return 1
		}
		return 0
	}
	run(ctx, in, db, cfg)
	return 0
}

func modeName(kind string) string {
	if kind == "" {
		return "scheduler"
	}
	return "once-" + kind
}
