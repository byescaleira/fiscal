package live

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	"liveresults/internal/tse"
)

type Service struct {
	defs       []tse.Definition
	source     tse.Source
	now        func() time.Time
	statePath  string
	publishDir string
	logger     *log.Logger

	mu        sync.RWMutex
	races     map[string]tse.Race
	fetchedAt time.Time
}

type Options struct {
	Source     tse.Source
	Now        func() time.Time
	StatePath  string
	PublishDir string
	Logger     *log.Logger
}

func New(o Options) *Service {
	if o.Now == nil {
		o.Now = time.Now
	}
	if o.Logger == nil {
		o.Logger = log.Default()
	}
	return &Service{
		defs:       tse.Definitions(),
		source:     o.Source,
		now:        o.Now,
		statePath:  o.StatePath,
		publishDir: o.PublishDir,
		logger:     o.Logger,
		races:      map[string]tse.Race{},
	}
}

type state struct {
	Races     []tse.Race `json:"races"`
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
	s.fetchedAt = st.FetchedAt
	return nil
}

func (s *Service) saveState() {
	if s.statePath == "" {
		return
	}
	races, fetchedAt := s.Snapshot()
	data, err := json.Marshal(state{Races: races, FetchedAt: fetchedAt})
	if err == nil {
		err = writeFileAtomic(s.statePath, data)
	}
	if err != nil {
		s.logger.Printf("save state: %v", err)
	}
}

func writeFileAtomic(path string, data []byte) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(name, path)
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
		if res.modified {
			s.races[d.ID] = res.race
		}
	}
	s.mu.Unlock()
	if !updated {
		return
	}
	if err := s.publish(); err != nil {
		s.logger.Printf("publish: %v", err)
	}
	s.saveState()
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
