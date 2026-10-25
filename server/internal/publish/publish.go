package publish

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

func Exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func WritePair(path string, data []byte) (bool, error) {
	if old, err := os.ReadFile(path); err == nil && bytes.Equal(old, data) && Exists(path+".gz") {
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
	if err := WriteFile(path+".gz", buf.Bytes()); err != nil {
		return false, err
	}
	return true, WriteFile(path, data)
}

func WriteFile(path string, data []byte) error {
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

type Stats struct {
	Files     int
	Written   int
	Bytes     int64
	GzipBytes int64
	Removed   int
}

type Tree struct {
	root string

	mu    sync.Mutex
	seen  map[string]bool
	stats Stats
}

func NewTree(root string) *Tree {
	return &Tree{root: root, seen: map[string]bool{}}
}

func (t *Tree) Root() string {
	return t.root
}

func (t *Tree) WriteJSON(rel string, v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("encode %s: %w", rel, err)
	}
	return t.Write(rel, data)
}

func (t *Tree) Write(rel string, data []byte) error {
	clean := filepath.Clean(filepath.FromSlash(rel))
	if clean == "." || strings.HasPrefix(clean, "..") || filepath.IsAbs(clean) {
		return fmt.Errorf("publish: invalid path %q", rel)
	}
	path := filepath.Join(t.root, clean)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	wrote, err := WritePair(path, data)
	if err != nil {
		return err
	}
	var gz int64
	if info, err := os.Stat(path + ".gz"); err == nil {
		gz = info.Size()
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.seen[filepath.ToSlash(clean)] = true
	t.stats.Files++
	t.stats.Bytes += int64(len(data))
	t.stats.GzipBytes += gz
	if wrote {
		t.stats.Written++
	}
	return nil
}

func (t *Tree) Retain(rels []string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	for _, rel := range rels {
		clean := filepath.ToSlash(filepath.Clean(filepath.FromSlash(rel)))
		if Exists(filepath.Join(t.root, filepath.FromSlash(clean))) {
			t.seen[clean] = true
		}
	}
}

func (t *Tree) Prune(dirs ...string) error {
	for _, dir := range dirs {
		base := filepath.Join(t.root, filepath.FromSlash(dir))
		if !Exists(base) {
			continue
		}
		var stale []string
		err := filepath.WalkDir(base, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				return nil
			}
			rel, err := filepath.Rel(t.root, path)
			if err != nil {
				return err
			}
			rel = filepath.ToSlash(rel)
			key := strings.TrimSuffix(rel, ".gz")
			if !strings.HasSuffix(key, ".json") {
				return nil
			}
			t.mu.Lock()
			keep := t.seen[key]
			t.mu.Unlock()
			if !keep {
				stale = append(stale, path)
			}
			return nil
		})
		if err != nil {
			return err
		}
		sort.Strings(stale)
		for _, path := range stale {
			if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
				return err
			}
			t.mu.Lock()
			t.stats.Removed++
			t.mu.Unlock()
		}
		removeEmptyDirs(base)
	}
	return nil
}

func removeEmptyDirs(base string) {
	var dirs []string
	filepath.WalkDir(base, func(path string, d fs.DirEntry, err error) error {
		if err == nil && d.IsDir() && path != base {
			dirs = append(dirs, path)
		}
		return nil
	})
	sort.Sort(sort.Reverse(sort.StringSlice(dirs)))
	for _, d := range dirs {
		os.Remove(d)
	}
}

func (t *Tree) Stats() Stats {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.stats
}
