package site

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	ReadyLink    = "ready"
	SitesDir     = "sites"
	ReleaseFile  = "release.json"
	Layout       = "v2"
	MaxFileBytes = 25 << 20
	DefaultFiles = 18000
	LiveFiles    = 9
)

var DefaultRequired = []string{"meta.json", "index/people.json", "today.json"}

var ErrValidation = errors.New("site validation failed")

const Headers = `/*
  X-Content-Type-Options: nosniff
  Access-Control-Allow-Origin: *
/v2/races.json
  Cache-Control: public, max-age=10, stale-while-revalidate=20
/v2/races/*
  Cache-Control: public, max-age=10, stale-while-revalidate=20
/v2/meta.json
  Cache-Control: public, max-age=60, stale-while-revalidate=300
/v2/today.json
  Cache-Control: public, max-age=60, stale-while-revalidate=300
/v2/highlights.json
  Cache-Control: public, max-age=60, stale-while-revalidate=300
/v2/status.json
  Cache-Control: public, max-age=60, stale-while-revalidate=300
/v2/release.json
  Cache-Control: public, max-age=60, stale-while-revalidate=300
/v2/index/*
  Cache-Control: public, max-age=300, stale-while-revalidate=3600
/v2/agenda/*
  Cache-Control: public, max-age=300, stale-while-revalidate=3600
/v2/people/*
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
/v2/votes/*
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
/v2/places/*
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
/v2/money/*
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
/v2/method/*
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
/v2/indicators/*
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
`

const NotFoundPage = "<!doctype html><meta charset=\"utf-8\"><title>404</title><p>404</p>\n"

type Rules struct {
	Required  []string
	MinPeople int
	MaxDrop   float64
	AllowDrop bool
	MaxFiles  int
}

type Release struct {
	Release     string         `json:"release"`
	Kind        string         `json:"kind"`
	Layout      string         `json:"layout"`
	GeneratedAt string         `json:"generatedAt"`
	Files       int            `json:"files"`
	Logical     int            `json:"logical"`
	People      int            `json:"people"`
	Buckets     map[string]int `json:"buckets"`
}

type Stager struct {
	Staging string
	Root    string
	Keep    int
	Rules   Rules
	Now     func() time.Time
	Logger  *log.Logger
}

func (s *Stager) now() time.Time {
	if s.Now == nil {
		return time.Now()
	}
	return s.Now()
}

func (s *Stager) logf(format string, args ...any) {
	if s.Logger != nil {
		s.Logger.Printf(format, args...)
	}
}

func ValidName(name string) bool {
	if len(name) < 17 || len(name) > 48 || strings.HasPrefix(name, ".") {
		return false
	}
	for _, c := range name {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '-') {
			return false
		}
	}
	return true
}

func validKind(kind string) bool {
	if len(kind) < 3 || len(kind) > 16 {
		return false
	}
	for _, c := range kind {
		if c < 'a' || c > 'z' {
			return false
		}
	}
	return true
}

func validPath(p string) bool {
	if p == "" || strings.HasPrefix(p, "/") || strings.Contains(p, "\\") || !strings.HasSuffix(p, ".json") || p == ReleaseFile || strings.HasPrefix(p, CityPeopleIndex.Dir+"/") || strings.HasPrefix(p, VoteBundles.Dir+"/") {
		return false
	}
	for _, part := range strings.Split(p, "/") {
		if part == "" || part == "." || part == ".." || strings.HasPrefix(part, ".") {
			return false
		}
	}
	return true
}

func (s *Stager) sites() string {
	return filepath.Join(s.Root, SitesDir)
}

func (s *Stager) Names() ([]string, error) {
	entries, err := os.ReadDir(s.sites())
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var out []string
	for _, e := range entries {
		if e.IsDir() && ValidName(e.Name()) {
			out = append(out, e.Name())
		}
	}
	sort.Strings(out)
	return out, nil
}

func (s *Stager) CurrentName() (string, error) {
	target, err := os.Readlink(filepath.Join(s.Root, ReadyLink))
	if errors.Is(err, fs.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	name := filepath.Base(target)
	if !ValidName(name) || filepath.ToSlash(target) != SitesDir+"/"+name {
		return "", fmt.Errorf("site: unexpected ready link %q", target)
	}
	return name, nil
}

func ReadRelease(dir string) (Release, error) {
	var r Release
	data, err := os.ReadFile(filepath.Join(dir, Layout, ReleaseFile))
	if err != nil {
		return r, err
	}
	if err := json.Unmarshal(data, &r); err != nil || !ValidName(r.Release) {
		return r, errors.New("site: invalid release.json")
	}
	return r, nil
}

func (s *Stager) Current() (Release, bool, error) {
	name, err := s.CurrentName()
	if err != nil || name == "" {
		return Release{}, false, err
	}
	r, err := ReadRelease(filepath.Join(s.sites(), name))
	if err != nil {
		return Release{}, false, err
	}
	return r, true, nil
}

func (s *Stager) newName(kind string) (string, error) {
	names, err := s.Names()
	if err != nil {
		return "", err
	}
	taken := map[string]bool{}
	for _, n := range names {
		taken[n] = true
	}
	base := s.now().UTC().Format("20060102T150405Z") + "-" + kind
	name := base
	for i := 2; taken[name]; i++ {
		name = base + "-" + strconv.Itoa(i)
	}
	return name, nil
}

func (s *Stager) indexed() (map[string]bool, int, error) {
	data, err := os.ReadFile(filepath.Join(s.Staging, "index", "people.json"))
	if errors.Is(err, fs.ErrNotExist) {
		return map[string]bool{}, 0, nil
	}
	if err != nil {
		return nil, 0, err
	}
	var cards []struct {
		Slug string `json:"slug"`
		Name string `json:"name"`
	}
	if err := json.Unmarshal(data, &cards); err != nil {
		return nil, 0, fmt.Errorf("%w: index/people.json is not a list of people", ErrValidation)
	}
	out := make(map[string]bool, len(cards))
	for _, c := range cards {
		if c.Slug == "" || c.Name == "" {
			return nil, 0, fmt.Errorf("%w: index/people.json has a person without slug or name", ErrValidation)
		}
		out[c.Slug] = true
	}
	return out, len(cards), nil
}

func copyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func writeFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

func (s *Stager) Stage(kind string, paths []string) (Release, error) {
	if !validKind(kind) {
		return Release{}, errors.New("site: kind must be full, live or a phase name")
	}
	if err := os.MkdirAll(s.sites(), 0o755); err != nil {
		return Release{}, err
	}
	s.clearTemp()
	indexed, people, err := s.indexed()
	if err != nil {
		return Release{}, err
	}
	name, err := s.newName(kind)
	if err != nil {
		return Release{}, err
	}
	tmp := filepath.Join(s.sites(), ".tmp-"+name)
	rel, err := s.build(tmp, name, kind, paths, indexed, people)
	if err == nil {
		err = s.validate(tmp, rel)
	}
	if err == nil {
		err = os.Rename(tmp, filepath.Join(s.sites(), name))
	}
	if err != nil {
		os.RemoveAll(tmp)
		return rel, err
	}
	if err := s.point(name); err != nil {
		return rel, err
	}
	s.prune(name)
	s.logf("site %s ready: files=%d logical=%d people=%d", name, rel.Files, rel.Logical, rel.People)
	return rel, nil
}

func (s *Stager) clearTemp() {
	entries, _ := os.ReadDir(s.sites())
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".tmp-") {
			os.RemoveAll(filepath.Join(s.sites(), e.Name()))
		}
	}
}

func (s *Stager) build(tmp, name, kind string, paths []string, indexed map[string]bool, people int) (Release, error) {
	rel := Release{Release: name, Kind: kind, Layout: Layout, GeneratedAt: s.now().UTC().Format(time.RFC3339), Logical: len(paths), People: people, Buckets: map[string]int{CityPeopleIndex.Dir: CityPeopleIndex.Count, VoteBundles.Dir: VoteBundles.Count}}
	out := filepath.Join(tmp, Layout)
	for _, p := range paths {
		if !validPath(p) {
			return rel, fmt.Errorf("site: invalid path %q", p)
		}
	}
	pl := planLayout(paths, indexed)
	read := func(p string) (json.RawMessage, error) {
		src := filepath.Join(s.Staging, filepath.FromSlash(p))
		info, err := os.Stat(src)
		if err != nil {
			return nil, fmt.Errorf("site: %s: %w", p, err)
		}
		if info.Size() > MaxFileBytes {
			return nil, fmt.Errorf("%w: %s is larger than 25 MiB", ErrValidation, p)
		}
		data, err := os.ReadFile(src)
		if err != nil {
			return nil, err
		}
		if !json.Valid(data) {
			return nil, fmt.Errorf("%w: %s is not valid JSON", ErrValidation, p)
		}
		return data, nil
	}
	write := func(p string, v any) error {
		data, err := json.Marshal(v)
		if err != nil {
			return err
		}
		if len(data) > MaxFileBytes {
			return fmt.Errorf("%w: %s would be larger than 25 MiB", ErrValidation, p)
		}
		return writeFile(filepath.Join(out, filepath.FromSlash(p)), data)
	}
	for _, p := range pl.direct {
		src := filepath.Join(s.Staging, filepath.FromSlash(p))
		info, err := os.Stat(src)
		if err != nil {
			return rel, fmt.Errorf("site: %s: %w", p, err)
		}
		if info.Size() > MaxFileBytes {
			return rel, fmt.Errorf("%w: %s is larger than 25 MiB", ErrValidation, p)
		}
		if err := copyFile(src, filepath.Join(out, filepath.FromSlash(p))); err != nil {
			return rel, err
		}
	}
	if err := pl.write(read, write); err != nil {
		return rel, err
	}
	if err := writeFile(filepath.Join(tmp, "_headers"), []byte(Headers)); err != nil {
		return rel, err
	}
	if err := writeFile(filepath.Join(tmp, "404.html"), []byte(NotFoundPage)); err != nil {
		return rel, err
	}
	count := 0
	err := filepath.WalkDir(tmp, func(_ string, d fs.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			count++
		}
		return err
	})
	if err != nil {
		return rel, err
	}
	rel.Files = count + 1 + LiveFiles
	data, err := json.Marshal(rel)
	if err != nil {
		return rel, err
	}
	return rel, writeFile(filepath.Join(out, ReleaseFile), data)
}

func (s *Stager) validate(dir string, rel Release) error {
	fail := func(format string, args ...any) error {
		return fmt.Errorf("%w: %s", ErrValidation, fmt.Sprintf(format, args...))
	}
	v1 := filepath.Join(dir, Layout)
	required := s.Rules.Required
	if required == nil {
		required = DefaultRequired
	}
	for _, r := range required {
		if _, err := os.Stat(filepath.Join(v1, filepath.FromSlash(r))); err != nil {
			return fail("required file %s is missing", r)
		}
	}
	indexed := map[string]bool{}
	if data, err := os.ReadFile(filepath.Join(v1, "index", "people.json")); err == nil {
		var cards []struct {
			Slug string `json:"slug"`
		}
		json.Unmarshal(data, &cards)
		for _, c := range cards {
			indexed[c.Slug] = true
			if _, err := os.Stat(filepath.Join(v1, "people", c.Slug+".json")); err != nil {
				return fail("index/people.json lists %s without people/%s.json", c.Slug, c.Slug)
			}
		}
	}
	if data, err := os.ReadFile(filepath.Join(v1, "meta.json")); err == nil {
		var meta struct {
			GeneratedAt string `json:"generatedAt"`
			Counts      *struct {
				People int `json:"people"`
			} `json:"counts"`
		}
		if err := json.Unmarshal(data, &meta); err != nil || meta.Counts == nil {
			return fail("meta.json has no counts")
		}
		if _, err := time.Parse(time.RFC3339, meta.GeneratedAt); err != nil {
			return fail("meta.json has no generatedAt")
		}
		if meta.Counts.People != rel.People {
			return fail("meta.json counts %d people but the index lists %d", meta.Counts.People, rel.People)
		}
	}
	if data, err := os.ReadFile(filepath.Join(v1, "today.json")); err == nil {
		var today struct {
			Date string `json:"date"`
		}
		if err := json.Unmarshal(data, &today); err != nil || today.Date == "" {
			return fail("today.json has no date")
		}
	}
	if rel.People < s.Rules.MinPeople {
		return fail("%d people, at least %d expected", rel.People, s.Rules.MinPeople)
	}
	maxFiles := s.Rules.MaxFiles
	if maxFiles <= 0 {
		maxFiles = DefaultFiles
	}
	if rel.Files > maxFiles {
		return fail("%d files, the limit is %d", rel.Files, maxFiles)
	}
	err := filepath.WalkDir(v1, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		relPath, _ := filepath.Rel(v1, p)
		relPath = filepath.ToSlash(relPath)
		if !json.Valid(data) {
			return fail("%s is not valid JSON", relPath)
		}
		if slug, ok := strings.CutPrefix(relPath, "people/"); ok && indexed[strings.TrimSuffix(slug, ".json")] {
			var pf struct {
				Profile json.RawMessage `json:"profile"`
			}
			if json.Unmarshal(data, &pf) != nil || len(pf.Profile) == 0 || string(pf.Profile) == "null" {
				return fail("%s has no profile", relPath)
			}
		}
		return nil
	})
	if err != nil {
		return err
	}
	prev, ok, err := s.Current()
	if err != nil || !ok || s.Rules.AllowDrop {
		return nil
	}
	maxDrop := s.Rules.MaxDrop
	if maxDrop <= 0 {
		maxDrop = 0.2
	}
	if prev.Logical > 0 && float64(rel.Logical) < float64(prev.Logical)*(1-maxDrop) {
		return fail("%d files against %d in %s (more than %.0f%% fewer)", rel.Logical, prev.Logical, prev.Release, maxDrop*100)
	}
	if prev.People > 0 && float64(rel.People) < float64(prev.People)*(1-maxDrop) {
		return fail("%d people against %d in %s (more than %.0f%% fewer)", rel.People, prev.People, prev.Release, maxDrop*100)
	}
	return nil
}

func (s *Stager) point(name string) error {
	tmp := filepath.Join(s.Root, ".ready-"+name)
	os.Remove(tmp)
	if err := os.Symlink(SitesDir+"/"+name, tmp); err != nil {
		return err
	}
	if err := os.Rename(tmp, filepath.Join(s.Root, ReadyLink)); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}

func (s *Stager) prune(current string) {
	keep := s.Keep
	if keep < 2 {
		keep = 3
	}
	names, err := s.Names()
	if err != nil {
		return
	}
	for i := 0; i < len(names)-keep; i++ {
		if names[i] != current {
			os.RemoveAll(filepath.Join(s.sites(), names[i]))
		}
	}
}

func (s *Stager) Rollback(target string) (string, error) {
	current, err := s.CurrentName()
	if err != nil {
		return "", err
	}
	names, err := s.Names()
	if err != nil {
		return "", err
	}
	if target == "" {
		for i := len(names) - 1; i >= 0; i-- {
			if current == "" || names[i] < current {
				target = names[i]
				break
			}
		}
		if target == "" {
			return "", errors.New("rollback: no earlier site to go back to")
		}
	}
	if !ValidName(target) {
		return "", fmt.Errorf("rollback: invalid site %q", target)
	}
	if _, err := ReadRelease(filepath.Join(s.sites(), target)); err != nil {
		return "", fmt.Errorf("rollback: %s: %w", target, err)
	}
	if err := s.point(target); err != nil {
		return "", err
	}
	s.logf("rollback: ready now points to %s (was %s)", target, current)
	return target, nil
}
