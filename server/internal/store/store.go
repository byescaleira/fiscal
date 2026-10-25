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

const FileName = "registrations.json"

var ErrCapacity = errors.New("capacity reached")

type Registration struct {
	RaceID      string    `json:"raceId"`
	PushToken   string    `json:"pushToken"`
	Environment string    `json:"environment"`
	CreatedAt   time.Time `json:"createdAt"`
}

type fileFormat struct {
	Registrations []Registration `json:"registrations"`
}

type Store struct {
	path    string
	max     int
	mu      sync.Mutex
	flushMu sync.Mutex
	byToken map[string]Registration
	dirty   bool
}

func Open(dir string, max int) (*Store, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, fmt.Errorf("data dir: %w", err)
	}
	if err := os.Chmod(dir, 0o700); err != nil {
		return nil, fmt.Errorf("data dir: %w", err)
	}
	s := &Store{path: filepath.Join(dir, FileName), max: max, byToken: map[string]Registration{}}
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
	for _, r := range f.Registrations {
		s.byToken[strings.ToLower(r.PushToken)] = r
	}
	return s, nil
}

func (s *Store) Put(r Registration) error {
	r.PushToken = strings.ToLower(r.PushToken)
	s.mu.Lock()
	defer s.mu.Unlock()
	old, exists := s.byToken[r.PushToken]
	if !exists && len(s.byToken) >= s.max {
		return ErrCapacity
	}
	if exists && old.RaceID == r.RaceID && old.Environment == r.Environment {
		return nil
	}
	s.byToken[r.PushToken] = r
	s.dirty = true
	return nil
}

func (s *Store) Delete(token string) bool {
	token = strings.ToLower(token)
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.byToken[token]; !ok {
		return false
	}
	delete(s.byToken, token)
	s.dirty = true
	return true
}

func (s *Store) ForRace(raceID string) []Registration {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []Registration
	for _, r := range s.byToken {
		if r.RaceID == raceID {
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
