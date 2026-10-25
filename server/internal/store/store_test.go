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
	return Registration{RaceID: race, PushToken: token, Environment: "development", CreatedAt: time.Unix(1792960000, 0).UTC()}
}

func TestStorePersistsAtomically(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "data")
	s, err := Open(dir, 10)
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
	reopened, err := Open(dir, 10)
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
	again, _ := Open(dir, 10)
	if again.Count() != 1 {
		t.Fatalf("after delete %d", again.Count())
	}
}

func TestStoreCapacity(t *testing.T) {
	s, err := Open(t.TempDir(), 2)
	if err != nil {
		t.Fatal(err)
	}
	s.Put(reg(strings.Repeat("a", 64), "presidente-br"))
	s.Put(reg(strings.Repeat("b", 64), "presidente-br"))
	if err := s.Put(reg(strings.Repeat("c", 64), "presidente-br")); !errors.Is(err, ErrCapacity) {
		t.Fatalf("expected capacity error, got %v", err)
	}
	if err := s.Put(reg(strings.Repeat("a", 64), "governador-df")); err != nil {
		t.Fatalf("updating an existing token must work at capacity: %v", err)
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
	if _, err := Open(dir, 10); err == nil {
		t.Fatal("expected error")
	}
}
