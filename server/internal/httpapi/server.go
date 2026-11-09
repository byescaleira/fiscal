package httpapi

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"
)

const (
	livePrefix   = "/api/v1/live-activities/"
	maxLoggedLen = 200
)

type Config struct {
	Now     func() time.Time
	Logger  *log.Logger
	Version string
}

type server struct {
	now     func() time.Time
	logger  *log.Logger
	version string
}

func New(c Config) http.Handler {
	if c.Now == nil {
		c.Now = time.Now
	}
	if c.Logger == nil {
		c.Logger = log.Default()
	}
	if c.Version == "" {
		c.Version = "dev"
	}
	s := &server{now: c.Now, logger: c.Logger, version: c.Version}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "not_found", "route not found")
	})
	return s.logRequests(s.recoverPanics(headers(mux)))
}

func headers(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	if r.status == 0 {
		r.status = code
	}
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
	if r.status == 0 {
		r.status = http.StatusOK
	}
	return r.ResponseWriter.Write(b)
}

func RedactPath(p string) string {
	if strings.HasPrefix(p, livePrefix) {
		rest := p[len(livePrefix):]
		if len(rest) > 6 {
			rest = rest[:6] + "…"
		}
		p = livePrefix + rest
	}
	if len(p) > maxLoggedLen {
		p = p[:maxLoggedLen] + "…"
	}
	return p
}

func (s *server) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := s.now()
		rec := &statusRecorder{ResponseWriter: w}
		next.ServeHTTP(rec, r)
		status := rec.status
		if status == 0 {
			status = http.StatusOK
		}
		s.logger.Printf("%s %s %d %s", r.Method, RedactPath(r.URL.Path), status, s.now().Sub(start).Round(time.Microsecond))
	})
}

func (s *server) recoverPanics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if v := recover(); v != nil {
				if v == http.ErrAbortHandler {
					panic(v)
				}
				s.logger.Printf("panic: %s %s: %v", r.Method, RedactPath(r.URL.Path), v)
				writeError(w, http.StatusInternalServerError, "internal_error", "internal error")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]apiError{"error": {Code: code, Message: message}})
}

func (s *server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, struct {
		OK      bool   `json:"ok"`
		Version string `json:"version"`
	}{OK: true, Version: s.version})
}
