package repercussion

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"time"
)

type Count struct {
	Value     int64  `json:"value"`
	FetchedAt string `json:"fetchedAt"`
}

type Title struct {
	Title     string `json:"title"`
	FetchedAt string `json:"fetchedAt"`
}

type Store struct {
	News   map[string]Count `json:"news"`
	Titles map[string]Title `json:"titles"`
	Views  map[string]Count `json:"views"`
}

func NewStore() *Store {
	return &Store{News: map[string]Count{}, Titles: map[string]Title{}, Views: map[string]Count{}}
}

func LoadStore(path string) (*Store, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return NewStore(), nil
	}
	if err != nil {
		return nil, err
	}
	s := NewStore()
	if err := json.Unmarshal(data, s); err != nil {
		return nil, err
	}
	if s.News == nil {
		s.News = map[string]Count{}
	}
	if s.Titles == nil {
		s.Titles = map[string]Title{}
	}
	if s.Views == nil {
		s.Views = map[string]Count{}
	}
	return s, nil
}

func (s *Store) Save(path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(s)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func fresh(at string, ttl time.Duration, now time.Time) bool {
	t, err := time.Parse(time.RFC3339, at)
	return err == nil && now.Sub(t) < ttl
}

func (s *Store) Prune(now time.Time, keep time.Duration) {
	for k, v := range s.News {
		if !fresh(v.FetchedAt, keep, now) {
			delete(s.News, k)
		}
	}
	for k, v := range s.Views {
		if !fresh(v.FetchedAt, keep, now) {
			delete(s.Views, k)
		}
	}
	for k, v := range s.Titles {
		if !fresh(v.FetchedAt, keep, now) {
			delete(s.Titles, k)
		}
	}
}
