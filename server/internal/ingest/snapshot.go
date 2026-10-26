package ingest

import (
	"bufio"
	"encoding/gob"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"liveresults/internal/publicdata"
)

const (
	SnapshotFile    = "live-snapshot.gob"
	snapshotVersion = 1
)

var ErrNoSnapshot = errors.New("no full load snapshot yet")

type snapshot struct {
	Version int
	Dataset *publicdata.Dataset
	Cities  []string
}

func (in *Ingest) SnapshotPath() string {
	return filepath.Join(in.cfg.DataDir, SnapshotFile)
}

func (in *Ingest) SaveSnapshot() error {
	in.mu.Lock()
	snap := snapshot{Version: snapshotVersion, Dataset: in.dataset, Cities: in.cities}
	in.mu.Unlock()
	if snap.Dataset == nil {
		return ErrNoSnapshot
	}
	path := in.SnapshotPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".snapshot-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	w := bufio.NewWriterSize(tmp, 1<<20)
	if err := gob.NewEncoder(w).Encode(snap); err != nil {
		tmp.Close()
		return fmt.Errorf("snapshot: %w", err)
	}
	if err := w.Flush(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(0o600); err != nil {
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
	return os.Rename(tmp.Name(), path)
}

func (in *Ingest) LoadSnapshot() error {
	f, err := os.Open(in.SnapshotPath())
	if errors.Is(err, os.ErrNotExist) {
		return ErrNoSnapshot
	}
	if err != nil {
		return err
	}
	defer f.Close()
	var snap snapshot
	if err := gob.NewDecoder(bufio.NewReaderSize(f, 1<<20)).Decode(&snap); err != nil {
		return fmt.Errorf("snapshot: %w", err)
	}
	if snap.Version != snapshotVersion || snap.Dataset == nil {
		return ErrNoSnapshot
	}
	in.mu.Lock()
	in.dataset = snap.Dataset
	in.cities = snap.Cities
	in.mu.Unlock()
	return nil
}
