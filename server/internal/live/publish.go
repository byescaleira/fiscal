package live

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"liveresults/internal/tse"
)

type raceList struct {
	Races     []tse.Race `json:"races"`
	FetchedAt string     `json:"fetchedAt"`
}

func (s *Service) ResetPublished() error {
	if s.publishDir == "" {
		return nil
	}
	if err := os.RemoveAll(filepath.Join(s.publishDir, "v1")); err != nil {
		return err
	}
	return s.publish()
}

func (s *Service) publish() error {
	if s.publishDir == "" {
		return nil
	}
	races, fetchedAt := s.Snapshot()
	if len(races) == 0 {
		return nil
	}
	dir := filepath.Join(s.publishDir, "v1")
	if err := os.MkdirAll(filepath.Join(dir, "races"), 0o755); err != nil {
		return err
	}
	changed := false
	for _, r := range races {
		data, err := json.Marshal(r)
		if err != nil {
			return err
		}
		wrote, err := writePublicPair(filepath.Join(dir, "races", r.ID+".json"), data)
		if err != nil {
			return err
		}
		changed = changed || wrote
	}
	listPath := filepath.Join(dir, "races.json")
	if !changed && exists(listPath) && exists(listPath+".gz") {
		return nil
	}
	list, err := json.Marshal(raceList{Races: races, FetchedAt: fetchedAt.UTC().Format(time.RFC3339)})
	if err != nil {
		return err
	}
	_, err = writePublicPair(listPath, list)
	return err
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func writePublicPair(path string, data []byte) (bool, error) {
	if old, err := os.ReadFile(path); err == nil && bytes.Equal(old, data) && exists(path+".gz") {
		return false, nil
	}
	var buf bytes.Buffer
	zw, err := gzip.NewWriterLevel(&buf, gzip.BestCompression)
	if err != nil {
		return false, err
	}
	if _, err := zw.Write(data); err != nil {
		return false, err
	}
	if err := zw.Close(); err != nil {
		return false, err
	}
	if err := writePublic(path+".gz", buf.Bytes()); err != nil {
		return false, err
	}
	return true, writePublic(path, data)
}

func writePublic(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), ".publish-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(name, path); err != nil {
		return fmt.Errorf("publish %s: %w", filepath.Base(path), err)
	}
	return nil
}
