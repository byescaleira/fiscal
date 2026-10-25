package httpapi

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"liveresults/internal/live"
	"liveresults/internal/store"
	"liveresults/internal/tse"
)

const (
	maxBody      = 4 << 10
	tokenMinLen  = 32
	tokenMaxLen  = 400
	livePrefix   = "/api/v1/live-activities/"
	maxLoggedLen = 200
)

type Races interface {
	Snapshot() ([]tse.Race, time.Time)
	Race(id string) (tse.Race, bool)
	PushRace(ctx context.Context, id string) (live.Stats, error)
}

type Registrations interface {
	Put(r store.Registration) error
	Delete(token string) bool
}

type Config struct {
	Races         Races
	Registrations Registrations
	AdminToken    string
	Limiter       *RateLimiter
	Now           func() time.Time
	Logger        *log.Logger
}

type server struct {
	races      Races
	regs       Registrations
	adminToken string
	limiter    *RateLimiter
	now        func() time.Time
	logger     *log.Logger
}

func New(c Config) http.Handler {
	if c.Now == nil {
		c.Now = time.Now
	}
	if c.Logger == nil {
		c.Logger = log.Default()
	}
	if c.Limiter == nil {
		c.Limiter = NewRateLimiter(c.Now, 120, 30)
	}
	s := &server{races: c.Races, regs: c.Registrations, adminToken: c.AdminToken, limiter: c.Limiter, now: c.Now, logger: c.Logger}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("GET /api/v1/races", s.limit(ClassRead, s.listRaces))
	mux.HandleFunc("GET /api/v1/races/{id}", s.limit(ClassRead, s.getRace))
	mux.HandleFunc("POST /api/v1/live-activities", s.limit(ClassWrite, s.register))
	mux.HandleFunc("DELETE /api/v1/live-activities/{pushToken}", s.limit(ClassWrite, s.unregister))
	mux.HandleFunc("POST /api/v1/admin/push-test", s.limit(ClassWrite, s.pushTest))
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

func (s *server) limit(class string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.limiter.Allow(ClientIP(r), class) {
			w.Header().Set("Retry-After", "60")
			writeError(w, http.StatusTooManyRequests, "rate_limited", "too many requests")
			return
		}
		h(w, r)
	}
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
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func notReady(w http.ResponseWriter) {
	w.Header().Set("Retry-After", "20")
	writeError(w, http.StatusServiceUnavailable, "not_ready", "results not available yet")
}

func (s *server) listRaces(w http.ResponseWriter, r *http.Request) {
	races, fetchedAt := s.races.Snapshot()
	if len(races) == 0 {
		notReady(w)
		return
	}
	writeJSON(w, http.StatusOK, struct {
		Races     []tse.Race `json:"races"`
		FetchedAt string     `json:"fetchedAt"`
	}{Races: races, FetchedAt: fetchedAt.UTC().Format(time.RFC3339)})
}

func (s *server) getRace(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !tse.KnownRace(id) {
		writeError(w, http.StatusNotFound, "race_not_found", "race not found")
		return
	}
	race, ok := s.races.Race(id)
	if !ok {
		notReady(w)
		return
	}
	writeJSON(w, http.StatusOK, race)
}

func readBody(w http.ResponseWriter, r *http.Request, v any) bool {
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBody))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", "body exceeds 4 KiB")
			return false
		}
		writeError(w, http.StatusBadRequest, "bad_request", "could not read body")
		return false
	}
	if err := json.Unmarshal(data, v); err != nil {
		writeError(w, http.StatusUnprocessableEntity, "invalid_request", "body must be a JSON object")
		return false
	}
	return true
}

func ValidToken(t string) bool {
	if len(t) < tokenMinLen || len(t) > tokenMaxLen {
		return false
	}
	for i := 0; i < len(t); i++ {
		c := t[i]
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F') {
			return false
		}
	}
	return true
}

func (s *server) register(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RaceID      string `json:"raceId"`
		PushToken   string `json:"pushToken"`
		Environment string `json:"environment"`
	}
	if !readBody(w, r, &body) {
		return
	}
	switch {
	case !tse.KnownRace(body.RaceID):
		writeError(w, http.StatusUnprocessableEntity, "invalid_request", "unknown raceId")
		return
	case !ValidToken(body.PushToken):
		writeError(w, http.StatusUnprocessableEntity, "invalid_request", "pushToken must be 32 to 400 hexadecimal characters")
		return
	case body.Environment != "development" && body.Environment != "production":
		writeError(w, http.StatusUnprocessableEntity, "invalid_request", "environment must be development or production")
		return
	}
	err := s.regs.Put(store.Registration{RaceID: body.RaceID, PushToken: strings.ToLower(body.PushToken), Environment: body.Environment, CreatedAt: s.now().UTC()})
	if errors.Is(err, store.ErrCapacity) {
		writeError(w, http.StatusInsufficientStorage, "capacity_reached", "registration capacity reached")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "internal error")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) unregister(w http.ResponseWriter, r *http.Request) {
	s.regs.Delete(r.PathValue("pushToken"))
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) authorizedAdmin(r *http.Request) bool {
	if s.adminToken == "" {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), []byte("Bearer "+s.adminToken)) == 1
}

func (s *server) pushTest(w http.ResponseWriter, r *http.Request) {
	if s.adminToken == "" {
		writeError(w, http.StatusNotFound, "not_found", "route not found")
		return
	}
	if !s.authorizedAdmin(r) {
		writeError(w, http.StatusUnauthorized, "unauthorized", "invalid token")
		return
	}
	var body struct {
		RaceID string `json:"raceId"`
	}
	if !readBody(w, r, &body) {
		return
	}
	if !tse.KnownRace(body.RaceID) {
		writeError(w, http.StatusUnprocessableEntity, "invalid_request", "unknown raceId")
		return
	}
	stats, err := s.races.PushRace(r.Context(), body.RaceID)
	if errors.Is(err, live.ErrNotReady) {
		notReady(w)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "internal error")
		return
	}
	writeJSON(w, http.StatusOK, stats)
}
