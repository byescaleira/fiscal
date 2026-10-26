package publish

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

const ManifestVersion = 1

type Manifest struct {
	path string

	mu      sync.Mutex
	entries map[string]string
	changed map[string]bool
	loaded  bool
	seeded  bool
}

type manifestFile struct {
	Version int               `json:"version"`
	Files   map[string]string `json:"files"`
	Pending []string          `json:"pending"`
}

func Hash(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

var stampKey = []byte(`"generatedAt":"`)

func ContentHash(data []byte) string {
	i := bytes.Index(data, stampKey)
	if i < 0 {
		return Hash(data)
	}
	start := i + len(stampKey)
	end := bytes.IndexByte(data[start:], '"')
	if end < 0 {
		return Hash(data)
	}
	sum := sha256.New()
	sum.Write(data[:start])
	sum.Write(data[start+end:])
	return "c" + hex.EncodeToString(sum.Sum(nil))
}

func LoadManifest(path string) (*Manifest, error) {
	m := &Manifest{path: path, entries: map[string]string{}, changed: map[string]bool{}}
	data, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return m, nil
	}
	if err != nil {
		return nil, err
	}
	var f manifestFile
	if err := json.Unmarshal(data, &f); err != nil || f.Version != ManifestVersion || f.Files == nil {
		return m, nil
	}
	m.entries = f.Files
	for _, p := range f.Pending {
		m.changed[p] = true
	}
	m.loaded = true
	return m, nil
}

func (m *Manifest) Loaded() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.loaded
}

func (m *Manifest) Seed(root string, dirs []string, top func(name string) bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	add := func(path string) {
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return
		}
		rel = filepath.ToSlash(rel)
		if _, ok := m.entries[rel]; !ok {
			m.entries[rel] = ""
		}
	}
	entries, err := os.ReadDir(root)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".json") && !strings.HasPrefix(e.Name(), ".") && top(e.Name()) {
			add(filepath.Join(root, e.Name()))
		}
	}
	for _, d := range dirs {
		base := filepath.Join(root, filepath.FromSlash(d))
		err := filepath.WalkDir(base, func(path string, de fs.DirEntry, err error) error {
			if errors.Is(err, fs.ErrNotExist) {
				return filepath.SkipDir
			}
			if err != nil {
				return err
			}
			if !de.IsDir() && strings.HasSuffix(path, ".json") && !strings.HasPrefix(de.Name(), ".") {
				add(path)
			}
			return nil
		})
		if err != nil {
			return err
		}
	}
	m.loaded = true
	m.seeded = true
	return nil
}

func (m *Manifest) Seeded() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.seeded
}

func (m *Manifest) Settle() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.changed = map[string]bool{}
	m.seeded = false
}

func (m *Manifest) Get(rel string) (string, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	h, ok := m.entries[rel]
	return h, ok
}

func (m *Manifest) set(rel, hash string, changed bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.entries[rel] = hash
	if changed {
		m.changed[rel] = true
	}
}

func (m *Manifest) keep(rel string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.entries[rel]; !ok {
		m.entries[rel] = ""
	}
}

func (m *Manifest) remove(rel string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.entries[rel]; ok {
		delete(m.entries, rel)
		m.changed[rel] = true
	}
}

func (m *Manifest) Paths() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]string, 0, len(m.entries))
	for k := range m.entries {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func (m *Manifest) Changed() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]string, 0, len(m.changed))
	for k := range m.changed {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func (m *Manifest) Save() error {
	pending := m.Changed()
	m.mu.Lock()
	data, err := json.Marshal(manifestFile{Version: ManifestVersion, Files: m.entries, Pending: pending})
	m.mu.Unlock()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(m.path), 0o700); err != nil {
		return err
	}
	tmp := m.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	if err := os.Rename(tmp, m.path); err != nil {
		return fmt.Errorf("manifest: %w", err)
	}
	return nil
}
