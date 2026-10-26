package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"
)

const (
	FileName   = "registrations.json"
	DefaultTTL = 12 * time.Hour
)

var (
	ErrCapacity    = errors.New("capacity reached")
	ErrSourceLimit = errors.New("source registration limit reached")
	ErrBound       = errors.New("token bound to another race")
)

type Registration struct {
	RaceID      string    `json:"raceId"`
	PushToken   string    `json:"pushToken"`
	Environment string    `json:"environment"`
	CreatedAt   time.Time `json:"createdAt"`
	Source      string    `json:"-"`
}

type fileFormat struct {
	Registrations []Registration `json:"registrations"`
}

type Options struct {
	FileName  string
	Max       int
	PerSource int
	TTL       time.Duration
	Now       func() time.Time
}

type Store struct {
	path      string
	max       int
	perSource int
	ttl       time.Duration
	now       func() time.Time
	mu        sync.Mutex
	flushMu   sync.Mutex
	byToken   map[string]Registration
	bySource  map[string]int
	dirty     bool
}

func Open(dir string, o Options) (*Store, error) {
	if o.TTL <= 0 {
		o.TTL = DefaultTTL
	}
	if o.Now == nil {
		o.Now = time.Now
	}
	if o.FileName == "" {
		o.FileName = FileName
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, fmt.Errorf("data dir: %w", err)
	}
	if err := os.Chmod(dir, 0o700); err != nil {
		return nil, fmt.Errorf("data dir: %w", err)
	}
	s := &Store{path: filepath.Join(dir, o.FileName), max: o.Max, perSource: o.PerSource, ttl: o.TTL, now: o.Now, byToken: map[string]Registration{}, bySource: map[string]int{}}
	data, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read registrations: %w", err)
	}
	var f fileFormat
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("decode registrations: %w", err)
	}
	now := s.now()
	for _, r := range f.Registrations {
		r.PushToken = strings.ToLower(r.PushToken)
		if s.expired(r, now) {
			s.dirty = true
			continue
		}
		s.byToken[r.PushToken] = r
	}
	return s, nil
}

func (s *Store) expired(r Registration, now time.Time) bool {
	return now.Sub(r.CreatedAt) >= s.ttl
}

func (s *Store) removeLocked(r Registration) {
	delete(s.byToken, r.PushToken)
	if r.Source != "" {
		if s.bySource[r.Source] <= 1 {
			delete(s.bySource, r.Source)
		} else {
			s.bySource[r.Source]--
		}
	}
	s.dirty = true
}

func (s *Store) sweepLocked(now time.Time) {
	for _, r := range s.byToken {
		if s.expired(r, now) {
			s.removeLocked(r)
		}
	}
}

func (s *Store) Put(r Registration) error {
	r.PushToken = strings.ToLower(r.PushToken)
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now().UTC()
	if old, ok := s.byToken[r.PushToken]; ok {
		if !s.expired(old, now) {
			if old.RaceID != r.RaceID || old.Environment != r.Environment {
				return ErrBound
			}
			old.CreatedAt = now
			s.byToken[r.PushToken] = old
			s.dirty = true
			return nil
		}
		s.removeLocked(old)
	}
	if len(s.byToken) >= s.max {
		return ErrCapacity
	}
	if r.Source != "" && s.perSource > 0 && s.bySource[r.Source] >= s.perSource {
		return ErrSourceLimit
	}
	r.CreatedAt = now
	s.byToken[r.PushToken] = r
	if r.Source != "" {
		s.bySource[r.Source]++
	}
	s.dirty = true
	return nil
}

func (s *Store) Delete(token string) bool {
	token = strings.ToLower(token)
	s.mu.Lock()
	defer s.mu.Unlock()
	r, ok := s.byToken[token]
	if !ok {
		return false
	}
	s.removeLocked(r)
	return true
}

func (s *Store) ForRace(raceID string) []Registration {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	var out []Registration
	for _, r := range s.byToken {
		if r.RaceID == raceID && !s.expired(r, now) {
			out = append(out, r)
		}
	}
	return out
}

func (s *Store) Count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.byToken)
}

func (s *Store) Flush() error {
	s.flushMu.Lock()
	defer s.flushMu.Unlock()
	s.mu.Lock()
	s.sweepLocked(s.now())
	if !s.dirty {
		s.mu.Unlock()
		return nil
	}
	f := fileFormat{Registrations: make([]Registration, 0, len(s.byToken))}
	for _, r := range s.byToken {
		f.Registrations = append(f.Registrations, r)
	}
	s.dirty = false
	s.mu.Unlock()
	slices.SortFunc(f.Registrations, func(a, b Registration) int { return strings.Compare(a.PushToken, b.PushToken) })
	data, err := json.Marshal(f)
	if err == nil {
		err = WriteFileAtomic(s.path, data)
	}
	if err != nil {
		s.mu.Lock()
		s.dirty = true
		s.mu.Unlock()
		return err
	}
	return nil
}

func (s *Store) Run(ctx context.Context, interval time.Duration) {
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := s.Flush(); err != nil {
				log.Printf("store flush: %v", err)
			}
		}
	}
}

func WriteFileAtomic(path string, data []byte) error {
	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	cleanup := func() { os.Remove(name) }
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		cleanup()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		cleanup()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		cleanup()
		return err
	}
	if err := tmp.Close(); err != nil {
		cleanup()
		return err
	}
	if err := os.Rename(name, path); err != nil {
		cleanup()
		return err
	}
	return nil
}
