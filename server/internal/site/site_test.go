package site

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type fixture struct {
	t     *testing.T
	stage *Stager
	clock time.Time
	paths map[string]bool
}

func newFixture(t *testing.T) *fixture {
	root := t.TempDir()
	f := &fixture{t: t, clock: time.Date(2026, 10, 26, 9, 30, 0, 0, time.UTC), paths: map[string]bool{}}
	f.stage = &Stager{Staging: filepath.Join(root, "v1"), Root: filepath.Join(root, "site"), Keep: 3, Rules: Rules{MinPeople: 1}, Now: func() time.Time { return f.clock }}
	return f
}

func (f *fixture) write(path, body string) {
	f.t.Helper()
	full := filepath.Join(f.stage.Staging, filepath.FromSlash(path))
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		f.t.Fatal(err)
	}
	if err := os.WriteFile(full, []byte(body), 0o644); err != nil {
		f.t.Fatal(err)
	}
	f.paths[path] = true
}

func (f *fixture) remove(path string) {
	os.Remove(filepath.Join(f.stage.Staging, filepath.FromSlash(path)))
	delete(f.paths, path)
}

func (f *fixture) seed(people int) {
	var cards []string
	for i := range people {
		slug := fmt.Sprintf("p%03d", i)
		cards = append(cards, `{"slug":"`+slug+`","name":"Pessoa `+slug+`"}`)
		f.write("people/"+slug+".json", `{"slug":"`+slug+`"}`)
		f.write("people/"+slug+"/votes-2026.json", `{"items":[],"total":0}`)
	}
	f.write("index/people.json", "["+strings.Join(cards, ",")+"]")
	f.write("meta.json", fmt.Sprintf(`{"generatedAt":"2026-10-26T06:30:00-03:00","counts":{"people":%d}}`, people))
	f.write("today.json", `{"date":"2026-10-26","events":[]}`)
	f.write("places/city/1200013.json", `{"code":"1200013","groups":[{"office":"mayor","people":[{"slug":"prefeita-a"},{"slug":null}]},{"office":"cityCouncilor","people":[{"slug":"vereador-b"}]}]}`)
	f.write("places/city/1200054.json", `{"code":"1200054","groups":[]}`)
	f.write("people/prefeita-a.json", `{"slug":"prefeita-a","office":"mayor"}`)
	f.write("people/vereador-b.json", `{"slug":"vereador-b","office":"cityCouncilor"}`)
	f.write("people/sem-cidade.json", `{"slug":"sem-cidade"}`)
	f.write("votes/camara-1.json", `{"id":"camara-1"}`)
	f.write("votes/senado-2.json", `{"id":"senado-2"}`)
	f.write("votes/recent.json", `{"items":[]}`)
}

func (f *fixture) list() []string {
	var out []string
	for p := range f.paths {
		out = append(out, p)
	}
	return out
}

func (f *fixture) run(kind string) (Release, error) {
	f.clock = f.clock.Add(10 * time.Minute)
	return f.stage.Stage(kind, f.list())
}

func (f *fixture) ready(path string, v any) {
	f.t.Helper()
	data, err := os.ReadFile(filepath.Join(f.stage.Root, ReadyLink, Layout, filepath.FromSlash(path)))
	if err != nil {
		f.t.Fatal(err)
	}
	if err := json.Unmarshal(data, v); err != nil {
		f.t.Fatalf("%s: %v", path, err)
	}
}

func TestStageBuildsTheGroupedLayout(t *testing.T) {
	f := newFixture(t)
	f.seed(3)
	rel, err := f.run("full")
	if err != nil {
		t.Fatal(err)
	}
	var person PersonFile
	f.ready("people/p001.json", &person)
	if string(person.Profile) != `{"slug":"p001"}` || string(person.Files["votes-2026.json"]) != `{"items":[],"total":0}` {
		t.Fatalf("person = %s %v", person.Profile, person.Files)
	}
	var city CityBundle
	f.ready("places/city/1200013.json", &city)
	if len(city.People) != 2 || string(city.People["vereador-b"]) != `{"slug":"vereador-b","office":"cityCouncilor"}` {
		t.Fatalf("city = %v", city.People)
	}
	var index Items[string]
	f.ready(CityPeopleIndex.Path("prefeita-a"), &index)
	if index.Items["prefeita-a"] != "1200013" {
		t.Fatalf("index = %v", index.Items)
	}
	var orphan PersonFile
	f.ready("people/sem-cidade.json", &orphan)
	if string(orphan.Profile) != `{"slug":"sem-cidade"}` {
		t.Fatalf("orphan = %s", orphan.Profile)
	}
	var votes Items[json.RawMessage]
	f.ready(VoteBundles.Path("senado-2"), &votes)
	if string(votes.Items["senado-2"]) != `{"id":"senado-2"}` {
		t.Fatalf("votes = %v", votes.Items)
	}
	for _, gone := range []string{"people/p001/votes-2026.json", "people/prefeita-a.json", "votes/camara-1.json"} {
		if _, err := os.Stat(filepath.Join(f.stage.Root, ReadyLink, Layout, gone)); !os.IsNotExist(err) {
			t.Fatalf("%s must not be published on its own", gone)
		}
	}
	var recent map[string]any
	f.ready("votes/recent.json", &recent)
	if _, err := os.Stat(filepath.Join(f.stage.Root, ReadyLink, "_headers")); err != nil {
		t.Fatal("missing _headers")
	}
	if _, err := os.Stat(filepath.Join(f.stage.Root, ReadyLink, "404.html")); err != nil {
		t.Fatal("missing 404.html")
	}
	if rel.Logical != len(f.paths) || rel.People != 3 || rel.Layout != Layout {
		t.Fatalf("release = %+v", rel)
	}
	var onDisk Release
	f.ready(ReleaseFile, &onDisk)
	if onDisk.Release != rel.Release || onDisk.Files != rel.Files {
		t.Fatalf("release.json = %+v", onDisk)
	}
	if strings.Contains(Headers, ".gz") || !strings.Contains(Headers, "/v2/races.json") {
		t.Fatal("headers")
	}
}

func TestStageRejectsBrokenReleasesAndKeepsTheReadyOne(t *testing.T) {
	cases := map[string]func(f *fixture){
		"required": func(f *fixture) { f.remove("today.json") },
		"index":    func(f *fixture) { f.write("index/people.json", `{"items":[]}`) },
		"profile":  func(f *fixture) { f.remove("people/p001.json") },
		"meta": func(f *fixture) {
			f.write("meta.json", `{"generatedAt":"2026-10-26T06:30:00-03:00","counts":{"people":9}}`)
		},
		"generatedAt": func(f *fixture) { f.write("meta.json", `{"counts":{"people":5}}`) },
		"minimum":     func(f *fixture) { f.stage.Rules.MinPeople = 50 },
		"json":        func(f *fixture) { f.write("votes/camara-1.json", `{"id":`) },
		"direct json": func(f *fixture) { f.write("money/overview.json", `[`) },
		"today":       func(f *fixture) { f.write("today.json", `{}`) },
		"city":        func(f *fixture) { f.write("places/city/1200054.json", `[]`) },
		"too many":    func(f *fixture) { f.stage.Rules.MaxFiles = 10 },
		"drop": func(f *fixture) {
			for i := 1; i < 5; i++ {
				f.remove(fmt.Sprintf("people/p%03d.json", i))
				f.remove(fmt.Sprintf("people/p%03d/votes-2026.json", i))
			}
			f.write("index/people.json", `[{"slug":"p000","name":"Pessoa"}]`)
			f.write("meta.json", `{"generatedAt":"2026-10-26T06:30:00-03:00","counts":{"people":1}}`)
		},
	}
	for name, breakIt := range cases {
		t.Run(name, func(t *testing.T) {
			f := newFixture(t)
			f.seed(5)
			first, err := f.run("full")
			if err != nil {
				t.Fatal(err)
			}
			breakIt(f)
			if _, err := f.run("live"); !errors.Is(err, ErrValidation) {
				t.Fatalf("err = %v", err)
			}
			cur, ok, err := f.stage.Current()
			if err != nil || !ok || cur.Release != first.Release {
				t.Fatalf("ready moved: %+v %v", cur, err)
			}
			names, _ := f.stage.Names()
			if len(names) != 1 {
				t.Fatalf("a rejected site must be removed: %v", names)
			}
		})
	}
}

func TestAllowDropAcceptsASmallerRelease(t *testing.T) {
	f := newFixture(t)
	f.seed(10)
	if _, err := f.run("full"); err != nil {
		t.Fatal(err)
	}
	for i := 1; i < 10; i++ {
		f.remove(fmt.Sprintf("people/p%03d.json", i))
		f.remove(fmt.Sprintf("people/p%03d/votes-2026.json", i))
	}
	f.write("index/people.json", `[{"slug":"p000","name":"Pessoa"}]`)
	f.write("meta.json", `{"generatedAt":"2026-10-26T06:30:00-03:00","counts":{"people":1}}`)
	f.stage.Rules.AllowDrop = true
	if _, err := f.run("full"); err != nil {
		t.Fatal(err)
	}
}

func TestRollbackAndPrune(t *testing.T) {
	f := newFixture(t)
	f.seed(2)
	var names []string
	for i := range 5 {
		f.write("today.json", fmt.Sprintf(`{"date":"2026-10-%02d"}`, 20+i))
		rel, err := f.run("live")
		if err != nil {
			t.Fatal(err)
		}
		names = append(names, rel.Release)
	}
	kept, _ := f.stage.Names()
	if len(kept) != 3 || kept[2] != names[4] {
		t.Fatalf("kept = %v", kept)
	}
	got, err := f.stage.Rollback("")
	if err != nil || got != names[3] {
		t.Fatalf("rollback = %s %v", got, err)
	}
	var today struct {
		Date string `json:"date"`
	}
	f.ready("today.json", &today)
	if today.Date != "2026-10-23" {
		t.Fatalf("today = %s", today.Date)
	}
	if _, err := f.stage.Rollback(names[0]); err == nil {
		t.Fatal("rollback to a pruned site must fail")
	}
}

func TestStagedFilesAreImmutableWhenTheStagingChanges(t *testing.T) {
	f := newFixture(t)
	f.seed(1)
	if _, err := f.run("full"); err != nil {
		t.Fatal(err)
	}
	tmp := filepath.Join(f.stage.Staging, ".swap")
	os.WriteFile(tmp, []byte(`{"items":["new"]}`), 0o644)
	os.Rename(tmp, filepath.Join(f.stage.Staging, "votes", "recent.json"))
	var recent struct {
		Items []string `json:"items"`
	}
	f.ready("votes/recent.json", &recent)
	if len(recent.Items) != 0 {
		t.Fatal("the staged site must keep its own copy")
	}
}

func TestFamilyBucketIsStable(t *testing.T) {
	if got := VoteBundles.Bucket("camara-1"); len(got) != 3 {
		t.Fatalf("bucket = %s", got)
	}
	if got := CityPeopleIndex.Bucket("vereador-b"); len(got) != 2 || got != CityPeopleIndex.Bucket("vereador-b") {
		t.Fatalf("bucket = %s", got)
	}
	if ValidName("../x") || !ValidName("20261026T093000Z-live-2") {
		t.Fatal("ValidName")
	}
}
