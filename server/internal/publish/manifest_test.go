package publish

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestManifestSkipsUnchangedFilesAndListsWhatChanged(t *testing.T) {
	root := t.TempDir()
	mpath := filepath.Join(t.TempDir(), "manifest.json")
	m, err := LoadManifest(mpath)
	if err != nil || m.Loaded() {
		t.Fatalf("new manifest: %v loaded=%v", err, m.Loaded())
	}
	tree := NewTree(root)
	tree.UseManifest(m)
	for _, rel := range []string{"people/a.json", "people/b.json", "votes/1.json"} {
		if err := tree.WriteJSON(rel, map[string]string{"x": rel}); err != nil {
			t.Fatal(err)
		}
	}
	if !reflect.DeepEqual(m.Changed(), []string{"people/a.json", "people/b.json", "votes/1.json"}) {
		t.Fatalf("changed = %v", m.Changed())
	}
	m.Settle()
	if err := m.Save(); err != nil {
		t.Fatal(err)
	}
	m2, err := LoadManifest(mpath)
	if err != nil || !m2.Loaded() || len(m2.Paths()) != 3 || len(m2.Changed()) != 0 {
		t.Fatalf("reloaded: %v %v %v", err, m2.Paths(), m2.Changed())
	}
	gz := filepath.Join(root, "people", "a.json.gz")
	before, _ := os.Stat(gz)
	next := NewTree(root)
	next.UseManifest(m2)
	if err := next.WriteJSON("people/a.json", map[string]string{"x": "people/a.json"}); err != nil {
		t.Fatal(err)
	}
	if err := next.WriteJSON("people/b.json", map[string]string{"x": "changed"}); err != nil {
		t.Fatal(err)
	}
	if err := next.Prune("people", "votes"); err != nil {
		t.Fatal(err)
	}
	after, _ := os.Stat(gz)
	if !after.ModTime().Equal(before.ModTime()) || next.Stats().Written != 1 {
		t.Fatalf("an unchanged file must not be rewritten (written=%d)", next.Stats().Written)
	}
	if !reflect.DeepEqual(m2.Changed(), []string{"people/b.json", "votes/1.json"}) || !reflect.DeepEqual(m2.Paths(), []string{"people/a.json", "people/b.json"}) {
		t.Fatalf("changed=%v paths=%v", m2.Changed(), m2.Paths())
	}
	if err := m2.Save(); err != nil {
		t.Fatal(err)
	}
	m3, _ := LoadManifest(mpath)
	if !reflect.DeepEqual(m3.Changed(), []string{"people/b.json", "votes/1.json"}) {
		t.Fatalf("changes not yet staged must survive a restart: %v", m3.Changed())
	}
}

func TestOnlyTheGenerationStampChangingKeepsTheFile(t *testing.T) {
	root := t.TempDir()
	m, _ := LoadManifest(filepath.Join(t.TempDir(), "m.json"))
	tree := NewTree(root)
	tree.UseManifest(m)
	tree.Write("meta.json", []byte(`{"generatedAt":"2026-10-26T10:00:00-03:00","counts":{"people":1}}`))
	m.Settle()
	again := NewTree(root)
	again.UseManifest(m)
	again.Write("meta.json", []byte(`{"generatedAt":"2026-10-26T10:05:00-03:00","counts":{"people":1}}`))
	data, _ := os.ReadFile(filepath.Join(root, "meta.json"))
	if string(data) != `{"generatedAt":"2026-10-26T10:00:00-03:00","counts":{"people":1}}` || len(m.Changed()) != 0 {
		t.Fatalf("a new stamp alone must not rewrite the file: %s %v", data, m.Changed())
	}
	again.Write("meta.json", []byte(`{"generatedAt":"2026-10-26T10:10:00-03:00","counts":{"people":2}}`))
	data, _ = os.ReadFile(filepath.Join(root, "meta.json"))
	if string(data) != `{"generatedAt":"2026-10-26T10:10:00-03:00","counts":{"people":2}}` || len(m.Changed()) != 1 {
		t.Fatalf("new content with a new stamp is written: %s", data)
	}
	if ContentHash([]byte(`{"a":1}`)) != Hash([]byte(`{"a":1}`)) {
		t.Fatal("files without a stamp hash as they are")
	}
}

func TestManifestRewritesAFileThatVanishedFromDisk(t *testing.T) {
	root := t.TempDir()
	m, _ := LoadManifest(filepath.Join(t.TempDir(), "m.json"))
	tree := NewTree(root)
	tree.UseManifest(m)
	tree.WriteJSON("a.json", 1)
	m.Settle()
	os.Remove(filepath.Join(root, "a.json"))
	again := NewTree(root)
	again.UseManifest(m)
	if err := again.WriteJSON("a.json", 1); err != nil {
		t.Fatal(err)
	}
	if !Exists(filepath.Join(root, "a.json")) {
		t.Fatal("a file missing on disk must be written even when the hash matches")
	}
}

func TestManifestSeedListsWhatIsOnDisk(t *testing.T) {
	root := t.TempDir()
	for _, rel := range []string{"people/a.json", "history/x.json", "races.json", "meta.json", "people/a.json.gz", "other/z.json"} {
		p := filepath.Join(root, filepath.FromSlash(rel))
		os.MkdirAll(filepath.Dir(p), 0o755)
		os.WriteFile(p, []byte("{}"), 0o644)
	}
	m, _ := LoadManifest(filepath.Join(t.TempDir(), "m.json"))
	if err := m.Seed(root, []string{"people", "history", "votes"}, func(n string) bool { return n != "races.json" }); err != nil {
		t.Fatal(err)
	}
	if !m.Seeded() || !reflect.DeepEqual(m.Paths(), []string{"history/x.json", "meta.json", "people/a.json"}) {
		t.Fatalf("seeded=%v paths=%v", m.Seeded(), m.Paths())
	}
}
