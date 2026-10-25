package publish

import (
	"bytes"
	"compress/gzip"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestWritePairWritesJSONAndGzipAtomically(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "a.json")
	wrote, err := WritePair(path, []byte(`{"a":1}`))
	if err != nil || !wrote {
		t.Fatalf("wrote=%v err=%v", wrote, err)
	}
	info, _ := os.Stat(path)
	if info.Mode().Perm() != 0o644 {
		t.Fatalf("mode = %v", info.Mode().Perm())
	}
	f, _ := os.Open(path + ".gz")
	defer f.Close()
	zr, err := gzip.NewReader(f)
	if err != nil {
		t.Fatal(err)
	}
	plain, _ := io.ReadAll(zr)
	if !bytes.Equal(plain, []byte(`{"a":1}`)) {
		t.Fatalf("gz = %s", plain)
	}
	leftovers, _ := filepath.Glob(filepath.Join(dir, ".publish-*"))
	if len(leftovers) != 0 {
		t.Fatalf("temporary files left: %v", leftovers)
	}
}

func TestRetainKeepsFilesThisRunDidNotRewrite(t *testing.T) {
	root := t.TempDir()
	first := NewTree(root)
	for _, rel := range []string{"places/city/1.json", "places/city/2.json", "people/a.json"} {
		if err := first.WriteJSON(rel, map[string]string{"x": rel}); err != nil {
			t.Fatal(err)
		}
	}
	next := NewTree(root)
	next.Retain([]string{"places/city/1.json", "people/a.json", "people/missing.json"})
	if err := next.Prune("places", "people"); err != nil {
		t.Fatal(err)
	}
	if !Exists(filepath.Join(root, "places", "city", "1.json")) || !Exists(filepath.Join(root, "people", "a.json.gz")) {
		t.Fatal("retained files were pruned")
	}
	if Exists(filepath.Join(root, "places", "city", "2.json")) {
		t.Fatal("a file nobody retained must be pruned")
	}
}

func TestWritePairSkipsUnchangedContent(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "a.json")
	WritePair(path, []byte(`{"a":1}`))
	old := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	os.Chtimes(path, old, old)
	os.Chtimes(path+".gz", old, old)
	wrote, err := WritePair(path, []byte(`{"a":1}`))
	if err != nil || wrote {
		t.Fatalf("unchanged content rewritten: wrote=%v err=%v", wrote, err)
	}
	info, _ := os.Stat(path)
	if !info.ModTime().Equal(old) {
		t.Fatal("mtime changed without new content")
	}
	os.Remove(path + ".gz")
	if wrote, _ := WritePair(path, []byte(`{"a":1}`)); !wrote || !Exists(path+".gz") {
		t.Fatal("missing .gz must be restored")
	}
	if wrote, _ := WritePair(path, []byte(`{"a":2}`)); !wrote {
		t.Fatal("changed content must be written")
	}
}

func TestTreeRejectsPathsOutsideRoot(t *testing.T) {
	tree := NewTree(t.TempDir())
	for _, rel := range []string{"../x.json", "/etc/x.json", "."} {
		if err := tree.WriteJSON(rel, 1); err == nil {
			t.Fatalf("%q accepted", rel)
		}
	}
}

func TestTreePrunesOnlyStaleFilesInManagedDirs(t *testing.T) {
	root := t.TempDir()
	first := NewTree(root)
	first.WriteJSON("people/a.json", 1)
	first.WriteJSON("people/b.json", 2)
	first.WriteJSON("people/b/votes-2026.json", 3)
	first.WriteJSON("races.json", 4)
	second := NewTree(root)
	if err := second.WriteJSON("people/a.json", 1); err != nil {
		t.Fatal(err)
	}
	if err := second.Prune("people", "votes"); err != nil {
		t.Fatal(err)
	}
	for _, gone := range []string{"people/b.json", "people/b.json.gz", "people/b/votes-2026.json"} {
		if Exists(filepath.Join(root, gone)) {
			t.Fatalf("%s should be pruned", gone)
		}
	}
	if Exists(filepath.Join(root, "people", "b")) {
		t.Fatal("empty directory should be removed")
	}
	for _, kept := range []string{"people/a.json", "people/a.json.gz", "races.json"} {
		if !Exists(filepath.Join(root, kept)) {
			t.Fatalf("%s should be kept", kept)
		}
	}
	stats := second.Stats()
	if stats.Files != 1 || stats.Written != 0 || stats.Removed != 4 || stats.Bytes != 1 {
		t.Fatalf("stats = %+v", stats)
	}
}
