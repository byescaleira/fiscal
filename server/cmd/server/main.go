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
	"strconv"
	"strings"
	"syscall"
	"time"

	"liveresults/internal/httpapi"
	"liveresults/internal/live"
	"liveresults/internal/tse"
)

const simDuration = 10 * time.Minute

type config struct {
	host      string
	port      string
	dataDir   string
	publicDir string
	tseBase   string
	poll      time.Duration
	simulate  bool
}

func loadConfig(getenv func(string) string) (config, error) {
	c := config{
		host:      getenv("HOST"),
		port:      getenv("PORT"),
		dataDir:   getenv("DATA_DIR"),
		publicDir: getenv("PUBLIC_DIR"),
		tseBase:   getenv("TSE_BASE_URL"),
		simulate:  getenv("SIMULATE") == "1",
		poll:      20 * time.Second,
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

var version = "dev"

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
	svc := live.New(live.Options{Source: source, StatePath: statePath, PublishDir: cfg.publishDir()})
	if err := svc.LoadState(); err != nil {
		log.Fatalf("state: %v", err)
	}
	if err := svc.ResetPublished(); err != nil {
		log.Fatalf("publish: %v", err)
	}

	address := net.JoinHostPort(cfg.host, cfg.port)
	httpServer := &http.Server{
		Addr:              address,
		Handler:           httpapi.New(httpapi.Config{Version: version}),
		ReadHeaderTimeout: 15 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	done := make(chan struct{})
	go func() {
		defer close(done)
		svc.Run(ctx, cfg.poll)
	}()

	go func() {
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()
	mode := "tse"
	if cfg.simulate {
		mode = "simulate"
	}
	log.Printf("listening on %s version=%s source=%s poll=%s publish=%v", address, version, mode, cfg.poll, cfg.publishDir() != "")

	<-ctx.Done()
	log.Printf("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
	<-done
}

func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
