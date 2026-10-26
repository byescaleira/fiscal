package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"liveresults/internal/apns"
	"liveresults/internal/highlightalert"
	"liveresults/internal/httpapi"
	"liveresults/internal/live"
	"liveresults/internal/store"
	"liveresults/internal/tse"
)

const (
	maxRegistrations = 50000
	maxPerSource     = 20
	registrationTTL  = 12 * time.Hour
	topicSuffix      = ".push-type.liveactivity"
	simDuration      = 10 * time.Minute
	maxHighlightRegs = 200000
	maxHighlightIP   = 100
	highlightTTL     = 30 * 24 * time.Hour
	highlightRegFile = "highlight-registrations.json"
	highlightCheck   = time.Minute
)

type config struct {
	host         string
	port         string
	dataDir      string
	publicDir    string
	tseBase      string
	poll         time.Duration
	simulate     bool
	apnsDisabled bool
	keyFile      string
	keyID        string
	teamID       string
	topic        string
	adminToken   string
	alerts       bool
}

func loadConfig(getenv func(string) string) (config, error) {
	c := config{
		host:         getenv("HOST"),
		port:         getenv("PORT"),
		dataDir:      getenv("DATA_DIR"),
		publicDir:    getenv("PUBLIC_DIR"),
		tseBase:      getenv("TSE_BASE_URL"),
		simulate:     getenv("SIMULATE") == "1",
		apnsDisabled: getenv("APNS_DISABLED") == "1",
		keyFile:      getenv("APNS_KEY_FILE"),
		keyID:        strings.TrimSpace(getenv("APNS_KEY_ID")),
		teamID:       strings.TrimSpace(getenv("APNS_TEAM_ID")),
		topic:        strings.TrimSpace(getenv("APNS_TOPIC")),
		adminToken:   getenv("ADMIN_TOKEN"),
		poll:         20 * time.Second,
		alerts:       true,
	}
	switch v := strings.TrimSpace(getenv("HIGHLIGHT_ALERTS")); v {
	case "", "1":
	case "0":
		c.alerts = false
	default:
		return c, fmt.Errorf("HIGHLIGHT_ALERTS %q is invalid (use 1 or 0)", v)
	}
	if c.host == "" {
		c.host = "127.0.0.1"
	}
	if c.port == "" {
		c.port = "3130"
	}
	if n, err := strconv.Atoi(c.port); err != nil || n < 1 || n > 65535 {
		return c, fmt.Errorf("PORT %q is invalid", c.port)
	}
	if c.dataDir == "" {
		c.dataDir = "./data"
	}
	if c.publicDir == "" {
		c.publicDir = "./public"
	}
	if c.tseBase == "" {
		c.tseBase = "https://resultados.tse.jus.br/oficial/ele2026"
	}
	if u, err := url.Parse(c.tseBase); err != nil || u.Host == "" || (u.Scheme != "https" && !(c.simulate && u.Scheme == "http")) {
		return c, errors.New("TSE_BASE_URL must be an https URL (http only with SIMULATE=1)")
	}
	if v := strings.TrimSpace(getenv("POLL_INTERVAL")); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil {
			n, nerr := strconv.Atoi(v)
			if nerr != nil {
				return c, fmt.Errorf("POLL_INTERVAL %q is invalid", v)
			}
			d = time.Duration(n) * time.Second
		}
		if d < 5*time.Second || d > 10*time.Minute {
			return c, fmt.Errorf("POLL_INTERVAL must be between 5s and 10m")
		}
		c.poll = d
	}
	if c.adminToken != "" && len(c.adminToken) < 32 {
		return c, errors.New("ADMIN_TOKEN must have at least 32 characters, or be empty to disable the admin route")
	}
	if !c.apnsDisabled {
		var missing []string
		for name, v := range map[string]string{"APNS_KEY_FILE": c.keyFile, "APNS_KEY_ID": c.keyID, "APNS_TEAM_ID": c.teamID, "APNS_TOPIC": c.topic} {
			if v == "" {
				missing = append(missing, name)
			}
		}
		slices.Sort(missing)
		if len(missing) > 0 {
			return c, fmt.Errorf("%s required; set them, or set APNS_DISABLED=1 for local testing", strings.Join(missing, ", "))
		}
		if !strings.HasSuffix(c.topic, topicSuffix) || len(c.topic) == len(topicSuffix) {
			return c, fmt.Errorf("APNS_TOPIC must be the bundle id followed by %s", topicSuffix)
		}
	}
	return c, nil
}

func (c config) publishDir() string {
	if c.simulate {
		return ""
	}
	return c.publicDir
}

func checkAddress(host, port string) string {
	if host == "" || host == "0.0.0.0" || host == "::" || host == "[::]" {
		host = "127.0.0.1"
	}
	return "http://" + net.JoinHostPort(strings.Trim(host, "[]"), port) + "/api/health"
}

func runCheck(url string) int {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	var body struct {
		OK bool `json:"ok"`
	}
	if resp.StatusCode != http.StatusOK || json.NewDecoder(resp.Body).Decode(&body) != nil || !body.OK {
		return 1
	}
	return 0
}

func buildSender(c config) (apns.Sender, error) {
	if c.apnsDisabled {
		return apns.DisabledSender{}, nil
	}
	key, err := apns.LoadKey(c.keyFile)
	if err != nil {
		return nil, err
	}
	tokens := apns.NewTokenProvider(key, c.keyID, c.teamID, nil)
	if _, err := tokens.Token(); err != nil {
		return nil, fmt.Errorf("apns token: %w", err)
	}
	return apns.NewClient(tokens, c.topic), nil
}

func main() {
	check := flag.Bool("check", false, "query the local health endpoint and exit 0 or 1")
	flag.Parse()
	if *check {
		os.Exit(runCheck(checkAddress(os.Getenv("HOST"), envOr("PORT", "3130"))))
	}
	log.SetFlags(log.LstdFlags | log.LUTC)

	cfg, err := loadConfig(os.Getenv)
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	regs, err := store.Open(cfg.dataDir, store.Options{Max: maxRegistrations, PerSource: maxPerSource, TTL: registrationTTL})
	if err != nil {
		log.Fatalf("store: %v", err)
	}
	sender, err := buildSender(cfg)
	if err != nil {
		log.Fatalf("apns: %v", err)
	}
	var source tse.Source
	statePath := ""
	if cfg.simulate {
		sim, err := tse.NewSimSource(nil, simDuration)
		if err != nil {
			log.Fatalf("simulate: %v", err)
		}
		source = sim
	} else {
		source = tse.NewHTTPSource(cfg.tseBase, &http.Client{Timeout: 10 * time.Second})
		statePath = filepath.Join(cfg.dataDir, "state.json")
	}
	svc := live.New(live.Options{Source: source, Sender: sender, Registry: regs, StatePath: statePath, PublishDir: cfg.publishDir()})
	if err := svc.LoadState(); err != nil {
		log.Fatalf("state: %v", err)
	}
	if err := svc.ResetPublished(); err != nil {
		log.Fatalf("publish: %v", err)
	}

	var highlightRegs *store.Store
	var watcher *highlightalert.Watcher
	if cfg.alerts {
		highlightRegs, err = store.Open(cfg.dataDir, store.Options{FileName: highlightRegFile, Max: maxHighlightRegs, PerSource: maxHighlightIP, TTL: highlightTTL})
		if err != nil {
			log.Fatalf("highlight store: %v", err)
		}
		watcher = highlightalert.New(highlightalert.Options{
			Path:     filepath.Join(cfg.publicDir, "v1", "highlights.json"),
			SentPath: filepath.Join(cfg.dataDir, highlightalert.SentFile),
			Sender:   sender,
			Registry: highlightRegs,
		})
		if err := watcher.Load(); err != nil {
			log.Fatalf("highlight alerts: %v", err)
		}
	}
	apiConfig := httpapi.Config{Races: svc, Registrations: regs, AdminToken: cfg.adminToken}
	if highlightRegs != nil {
		apiConfig.Highlights = highlightRegs
	}
	handler := httpapi.New(apiConfig)
	address := net.JoinHostPort(cfg.host, cfg.port)
	httpServer := &http.Server{
		Addr:              address,
		Handler:           handler,
		ReadHeaderTimeout: 15 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var workers sync.WaitGroup
	workers.Add(2)
	go func() {
		defer workers.Done()
		svc.Run(ctx, cfg.poll)
	}()
	go func() {
		defer workers.Done()
		regs.Run(ctx, 2*time.Second)
	}()
	if watcher != nil {
		workers.Add(2)
		go func() {
			defer workers.Done()
			highlightRegs.Run(ctx, 2*time.Second)
		}()
		go func() {
			defer workers.Done()
			watcher.Run(ctx, highlightCheck)
		}()
	}

	go func() {
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()
	mode := "tse"
	if cfg.simulate {
		mode = "simulate"
	}
	apnsMode := "enabled"
	if cfg.apnsDisabled {
		apnsMode = "disabled"
	}
	log.Printf("listening on %s source=%s apns=%s poll=%s registrations=%d admin=%v publish=%v highlightAlerts=%v", address, mode, apnsMode, cfg.poll, regs.Count(), cfg.adminToken != "", cfg.publishDir() != "", cfg.alerts)

	<-ctx.Done()
	log.Printf("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
	workers.Wait()
	if err := regs.Flush(); err != nil {
		log.Printf("store flush: %v", err)
	}
	if highlightRegs != nil {
		if err := highlightRegs.Flush(); err != nil {
			log.Printf("highlight store flush: %v", err)
		}
	}
}

func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
