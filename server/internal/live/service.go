package live

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"liveresults/internal/apns"
	"liveresults/internal/store"
	"liveresults/internal/tse"
)

var ErrNotReady = errors.New("race not ready")

type Registry interface {
	ForRace(raceID string) []store.Registration
	Delete(token string) bool
}

type Stats struct {
	Registrations int    `json:"registrations"`
	Sent          int64  `json:"sent"`
	Failed        int64  `json:"failed"`
	Removed       int64  `json:"removed"`
	Event         string `json:"event"`
}

type Service struct {
	defs       []tse.Definition
	source     tse.Source
	sender     apns.Sender
	registry   Registry
	now        func() time.Time
	statePath  string
	publishDir string
	workers    int
	logger     *log.Logger

	mu        sync.RWMutex
	races     map[string]tse.Race
	ended     map[string]bool
	fetchedAt time.Time
}

type Options struct {
	Source     tse.Source
	Sender     apns.Sender
	Registry   Registry
	Now        func() time.Time
	StatePath  string
	PublishDir string
	Workers    int
	Logger     *log.Logger
}

func New(o Options) *Service {
	if o.Now == nil {
		o.Now = time.Now
	}
	if o.Workers <= 0 {
		o.Workers = 8
	}
	if o.Logger == nil {
		o.Logger = log.Default()
	}
	return &Service{
		defs:       tse.Definitions(),
		source:     o.Source,
		sender:     o.Sender,
		registry:   o.Registry,
		now:        o.Now,
		statePath:  o.StatePath,
		publishDir: o.PublishDir,
		workers:    o.Workers,
		logger:     o.Logger,
		races:      map[string]tse.Race{},
		ended:      map[string]bool{},
	}
}

type state struct {
	Races     []tse.Race `json:"races"`
	Ended     []string   `json:"ended"`
	FetchedAt time.Time  `json:"fetchedAt"`
}

func (s *Service) LoadState() error {
	if s.statePath == "" {
		return nil
	}
	data, err := os.ReadFile(s.statePath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	var st state
	if err := json.Unmarshal(data, &st); err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, r := range st.Races {
		if tse.KnownRace(r.ID) {
			s.races[r.ID] = r
		}
	}
	for _, id := range st.Ended {
		s.ended[id] = true
	}
	s.fetchedAt = st.FetchedAt
	return nil
}

func (s *Service) saveState() {
	if s.statePath == "" {
		return
	}
	s.mu.RLock()
	st := state{FetchedAt: s.fetchedAt}
	for _, d := range s.defs {
		if r, ok := s.races[d.ID]; ok {
			st.Races = append(st.Races, r)
		}
		if s.ended[d.ID] {
			st.Ended = append(st.Ended, d.ID)
		}
	}
	s.mu.RUnlock()
	data, err := json.Marshal(st)
	if err == nil {
		err = store.WriteFileAtomic(s.statePath, data)
	}
	if err != nil {
		s.logger.Printf("save state: %v", err)
	}
}

func (s *Service) Snapshot() ([]tse.Race, time.Time) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]tse.Race, 0, len(s.defs))
	for _, d := range s.defs {
		if r, ok := s.races[d.ID]; ok {
			out = append(out, r)
		}
	}
	return out, s.fetchedAt
}

func (s *Service) Race(id string) (tse.Race, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	r, ok := s.races[id]
	return r, ok
}

func Changed(old, cur tse.Race) bool {
	if old.Sections.Counted != cur.Sections.Counted || old.Final != cur.Final || len(old.Candidates) != len(cur.Candidates) {
		return true
	}
	votes := make(map[string]int64, len(old.Candidates))
	for _, c := range old.Candidates {
		votes[c.Number] = c.Votes
	}
	for _, c := range cur.Candidates {
		v, ok := votes[c.Number]
		if !ok || v != c.Votes {
			return true
		}
	}
	return false
}

type fetchResult struct {
	race     tse.Race
	modified bool
	err      error
}

func (s *Service) PollOnce(ctx context.Context) {
	results := make([]fetchResult, len(s.defs))
	var wg sync.WaitGroup
	for i, d := range s.defs {
		wg.Add(1)
		go func() {
			defer wg.Done()
			fctx, cancel := context.WithTimeout(ctx, 10*time.Second)
			defer cancel()
			r, modified, err := s.source.Fetch(fctx, d)
			results[i] = fetchResult{race: r, modified: modified, err: err}
		}()
	}
	wg.Wait()
	var toPush []tse.Race
	updated := false
	s.mu.Lock()
	for i, res := range results {
		d := s.defs[i]
		if res.err != nil {
			s.logger.Printf("fetch %s: %v", d.ID, res.err)
			continue
		}
		s.fetchedAt = s.now().UTC()
		updated = true
		if !res.modified {
			continue
		}
		old, had := s.races[d.ID]
		s.races[d.ID] = res.race
		if (!had || Changed(old, res.race)) && !s.ended[d.ID] {
			toPush = append(toPush, res.race)
		}
	}
	s.mu.Unlock()
	if updated {
		if err := s.publish(); err != nil {
			s.logger.Printf("publish: %v", err)
		}
	}
	for _, r := range toPush {
		if ctx.Err() != nil {
			break
		}
		stats := s.dispatch(ctx, r)
		if stats.Event == "end" {
			s.mu.Lock()
			s.ended[r.ID] = true
			s.mu.Unlock()
		}
	}
	if updated {
		s.saveState()
	}
}

func (s *Service) Run(ctx context.Context, interval time.Duration) {
	s.PollOnce(ctx)
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.PollOnce(ctx)
		}
	}
}

func (s *Service) PushRace(ctx context.Context, id string) (Stats, error) {
	r, ok := s.Race(id)
	if !ok {
		return Stats{}, ErrNotReady
	}
	return s.dispatch(ctx, r), nil
}

func tokenPrefix(token string) string {
	if len(token) > 6 {
		return token[:6]
	}
	return token
}

func (s *Service) dispatch(ctx context.Context, r tse.Race) Stats {
	now := s.now()
	msg, err := apns.BuildMessage(r, now)
	if err != nil {
		s.logger.Printf("push %s: build: %v", r.ID, err)
		return Stats{}
	}
	stats := Stats{Event: "update"}
	if msg.End {
		stats.Event = "end"
	}
	regs := s.registry.ForRace(r.ID)
	stats.Registrations = len(regs)
	if len(regs) == 0 {
		return stats
	}
	var sent, failed, removed atomic.Int64
	jobs := make(chan store.Registration)
	var wg sync.WaitGroup
	workers := min(s.workers, len(regs))
	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for reg := range jobs {
				res := s.sender.Send(ctx, apns.Notification{Token: reg.PushToken, Environment: reg.Environment, Priority: msg.Priority, Payload: msg.Payload})
				switch {
				case res.OK():
					sent.Add(1)
				case res.TokenInvalid():
					s.registry.Delete(reg.PushToken)
					removed.Add(1)
					s.logger.Printf("push race=%s token=%s… status=%d reason=%s removed", r.ID, tokenPrefix(reg.PushToken), res.Status, res.Reason)
				default:
					failed.Add(1)
					if res.Err != nil {
						s.logger.Printf("push race=%s token=%s… error=%v", r.ID, tokenPrefix(reg.PushToken), res.Err)
					} else {
						s.logger.Printf("push race=%s token=%s… status=%d reason=%s", r.ID, tokenPrefix(reg.PushToken), res.Status, res.Reason)
					}
				}
			}
		}()
	}
	for _, reg := range regs {
		if ctx.Err() != nil {
			break
		}
		jobs <- reg
	}
	close(jobs)
	wg.Wait()
	stats.Sent, stats.Failed, stats.Removed = sent.Load(), failed.Load(), removed.Load()
	s.logger.Printf("push race=%s event=%s sections=%.2f registrations=%d sent=%d failed=%d removed=%d", r.ID, stats.Event, r.Sections.Percent, stats.Registrations, stats.Sent, stats.Failed, stats.Removed)
	return stats
}
