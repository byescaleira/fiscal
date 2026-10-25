package store

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func reg(token, race string) Registration {
	return Registration{RaceID: race, PushToken: token, Environment: "development"}
}

type clock struct{ t time.Time }

func (c *clock) now() time.Time { return c.t }

func newClock() *clock { return &clock{t: time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)} }

func opts(max int) Options { return Options{Max: max, PerSource: 20} }

func TestStorePersistsAtomically(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "data")
	s, err := Open(dir, opts(10))
	if err != nil {
		t.Fatal(err)
	}
	info, _ := os.Stat(dir)
	if info.Mode().Perm() != 0o700 {
		t.Fatalf("dir mode %v", info.Mode().Perm())
	}
	token := strings.Repeat("AB", 32)
	if err := s.Put(reg(token, "presidente-br")); err != nil {
		t.Fatal(err)
	}
	if err := s.Put(reg(strings.ToLower(token), "presidente-br")); err != nil {
		t.Fatal(err)
	}
	if s.Count() != 1 {
		t.Fatalf("same token stored twice: %d", s.Count())
	}
	if err := s.Put(reg(strings.Repeat("cd", 32), "governador-ac")); err != nil {
		t.Fatal(err)
	}
	if err := s.Flush(); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, FileName)
	info, err = os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("file mode %v", info.Mode().Perm())
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Fatalf("leftover temp files: %v", entries)
	}
	reopened, err := Open(dir, opts(10))
	if err != nil {
		t.Fatal(err)
	}
	if reopened.Count() != 2 || len(reopened.ForRace("presidente-br")) != 1 || reopened.ForRace("presidente-br")[0].PushToken != strings.ToLower(token) {
		t.Fatalf("reopened %d %+v", reopened.Count(), reopened.ForRace("presidente-br"))
	}
	if !reopened.Delete(strings.ToUpper(token)) || reopened.Delete(token) {
		t.Fatal("delete")
	}
	if err := reopened.Flush(); err != nil {
		t.Fatal(err)
	}
	again, _ := Open(dir, opts(10))
	if again.Count() != 1 {
		t.Fatalf("after delete %d", again.Count())
	}
}

func TestStoreCapacity(t *testing.T) {
	s, err := Open(t.TempDir(), opts(2))
	if err != nil {
		t.Fatal(err)
	}
	s.Put(reg(strings.Repeat("a", 64), "presidente-br"))
	s.Put(reg(strings.Repeat("b", 64), "presidente-br"))
	if err := s.Put(reg(strings.Repeat("c", 64), "presidente-br")); !errors.Is(err, ErrCapacity) {
		t.Fatalf("expected capacity error, got %v", err)
	}
	if err := s.Put(reg(strings.Repeat("a", 64), "presidente-br")); err != nil {
		t.Fatalf("renewing an existing token must work at capacity: %v", err)
	}
}

func TestPutKeepsTheOriginalRace(t *testing.T) {
	s, _ := Open(t.TempDir(), opts(10))
	tok := strings.Repeat("a", 64)
	if err := s.Put(reg(tok, "presidente-br")); err != nil {
		t.Fatal(err)
	}
	if err := s.Put(reg(tok, "governador-df")); !errors.Is(err, ErrBound) {
		t.Fatalf("other race must be refused, got %v", err)
	}
	prod := reg(tok, "presidente-br")
	prod.Environment = "production"
	if err := s.Put(prod); !errors.Is(err, ErrBound) {
		t.Fatalf("other environment must be refused, got %v", err)
	}
	got := s.ForRace("presidente-br")
	if len(got) != 1 || got[0].Environment != "development" || len(s.ForRace("governador-df")) != 0 {
		t.Fatalf("original changed: %+v", got)
	}
}

func TestRegistrationsExpireAndRenew(t *testing.T) {
	c := newClock()
	dir := t.TempDir()
	s, _ := Open(dir, Options{Max: 10, PerSource: 20, Now: c.now})
	a, b := strings.Repeat("a", 64), strings.Repeat("b", 64)
	s.Put(reg(a, "presidente-br"))
	s.Put(reg(b, "presidente-br"))
	c.t = c.t.Add(11 * time.Hour)
	if err := s.Put(reg(a, "presidente-br")); err != nil {
		t.Fatal(err)
	}
	c.t = c.t.Add(time.Hour)
	got := s.ForRace("presidente-br")
	if len(got) != 1 || got[0].PushToken != a {
		t.Fatalf("expired registration must be ignored on send: %+v", got)
	}
	if s.Count() != 2 {
		t.Fatalf("sweep belongs to Flush, count %d", s.Count())
	}
	if err := s.Flush(); err != nil {
		t.Fatal(err)
	}
	if s.Count() != 1 {
		t.Fatalf("flush must sweep expired, count %d", s.Count())
	}
	reopened, _ := Open(dir, Options{Max: 10, Now: c.now})
	if reopened.Count() != 1 {
		t.Fatalf("reopened %d", reopened.Count())
	}
	c.t = c.t.Add(11 * time.Hour)
	again, _ := Open(dir, Options{Max: 10, Now: c.now})
	if again.Count() != 0 || len(again.ForRace("presidente-br")) != 0 {
		t.Fatalf("expired on disk must not load, count %d", again.Count())
	}
	if err := again.Put(reg(a, "governador-df")); err != nil {
		t.Fatalf("expired token may be registered again for another race: %v", err)
	}
}

func TestPerSourceLimitAndSourceNotPersisted(t *testing.T) {
	c := newClock()
	dir := t.TempDir()
	s, _ := Open(dir, Options{Max: 100, PerSource: 3, Now: c.now})
	src := "3f2a9c0d1e2b4a5f6c7d8e9f0a1b2c3d"
	put := func(tok string, source string) error {
		r := reg(tok, "presidente-br")
		r.Source = source
		return s.Put(r)
	}
	for i := 0; i < 3; i++ {
		if err := put(strings.Repeat(string(rune('a'+i)), 64), src); err != nil {
			t.Fatal(err)
		}
	}
	if err := put(strings.Repeat("d", 64), src); !errors.Is(err, ErrSourceLimit) {
		t.Fatalf("expected source limit, got %v", err)
	}
	if err := put(strings.Repeat("a", 64), src); err != nil {
		t.Fatalf("renewal must not count against the limit: %v", err)
	}
	if err := put(strings.Repeat("d", 64), "other"); err != nil {
		t.Fatalf("other source must pass: %v", err)
	}
	s.Delete(strings.Repeat("a", 64))
	if err := put(strings.Repeat("e", 64), src); err != nil {
		t.Fatalf("delete must free a slot: %v", err)
	}
	c.t = c.t.Add(DefaultTTL)
	s.Flush()
	for i := 0; i < 3; i++ {
		if err := put(strings.Repeat(string(rune('f'+i)), 64), src); err != nil {
			t.Fatalf("expired registrations must free slots: %v", err)
		}
	}
	if err := s.Flush(); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(filepath.Join(dir, FileName))
	if strings.Contains(string(data), src) || strings.Contains(string(data), "source") || !strings.Contains(string(data), "createdAt") {
		t.Fatalf("file must carry createdAt and never the source: %s", data)
	}
}

func TestWriteFileAtomicReplaces(t *testing.T) {
	path := filepath.Join(t.TempDir(), "x.json")
	if err := WriteFileAtomic(path, []byte("one")); err != nil {
		t.Fatal(err)
	}
	if err := WriteFileAtomic(path, []byte("two")); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != "two" {
		t.Fatalf("got %q", data)
	}
}

func TestOpenRejectsCorruptFile(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, FileName), []byte("{"), 0o600)
	if _, err := Open(dir, opts(10)); err == nil {
		t.Fatal("expected error")
	}
}
