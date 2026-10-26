package live

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"

	"liveresults/internal/publish"
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
	dir := filepath.Join(s.publishDir, "v1")
	if err := os.RemoveAll(filepath.Join(dir, "races")); err != nil {
		return err
	}
	for _, name := range []string{"races.json", "races.json.gz"} {
		if err := os.Remove(filepath.Join(dir, name)); err != nil && !os.IsNotExist(err) {
			return err
		}
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
		wrote, err := publish.WritePair(filepath.Join(dir, "races", r.ID+".json"), data)
		if err != nil {
			return err
		}
		changed = changed || wrote
	}
	listPath := filepath.Join(dir, "races.json")
	if !changed && publish.Exists(listPath) && publish.Exists(listPath+".gz") {
		return nil
	}
	list, err := json.Marshal(raceList{Races: races, FetchedAt: fetchedAt.UTC().Format(time.RFC3339)})
	if err != nil {
		return err
	}
	_, err = publish.WritePair(listPath, list)
	return err
}
