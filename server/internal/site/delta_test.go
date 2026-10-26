package site

import (
	"bytes"
	"fmt"
	"io/fs"
	"math/rand/v2"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"
)

type world struct {
	f       *fixture
	rng     *rand.Rand
	people  []string
	cities  map[string][]string
	votes   []string
	version int
}

func newWorld(t *testing.T, seed uint64) *world {
	w := &world{f: newFixture(t), rng: rand.New(rand.NewPCG(seed, seed*7+1)), cities: map[string][]string{}}
	for i := range 40 {
		w.people = append(w.people, fmt.Sprintf("dep-%02d", i))
	}
	for c := range 30 {
		code := fmt.Sprintf("12%05d", c)
		for k := range 1 + c%4 {
			w.cities[code] = append(w.cities[code], fmt.Sprintf("v-%s-%d", code, k))
		}
	}
	for i := range 60 {
		w.votes = append(w.votes, fmt.Sprintf("camara-%d", i))
	}
	w.writeAll()
	return w
}

func (w *world) bump() string {
	w.version++
	return fmt.Sprintf(`"v":%d`, w.version)
}

func (w *world) writeIndex() {
	var cards []string
	for _, slug := range w.people {
		cards = append(cards, `{"slug":"`+slug+`","name":"Pessoa `+slug+`"}`)
	}
	w.f.write("index/people.json", "["+strings.Join(cards, ",")+"]")
	w.f.write("meta.json", fmt.Sprintf(`{"generatedAt":"2026-10-26T06:30:00-03:00","counts":{"people":%d}}`, len(w.people)))
}

func (w *world) writePerson(slug string) {
	w.f.write("people/"+slug+".json", `{"slug":"`+slug+`",`+w.bump()+`}`)
	w.f.write("people/"+slug+"/votes-2026.json", `{"items":[],`+w.bump()+`}`)
}

func (w *world) writeCity(code string) {
	var refs []string
	for _, slug := range w.cities[code] {
		refs = append(refs, `{"slug":"`+slug+`"}`)
	}
	w.f.write("places/city/"+code+".json", `{"code":"`+code+`","groups":[{"people":[`+strings.Join(refs, ",")+`]}],`+w.bump()+`}`)
}

func (w *world) writeCityPerson(slug string) {
	w.f.write("people/"+slug+".json", `{"slug":"`+slug+`","office":"cityCouncilor",`+w.bump()+`}`)
}

func (w *world) writeAll() {
	w.writeIndex()
	w.f.write("today.json", `{"date":"2026-10-26","events":[]}`)
	w.f.write("votes/recent.json", `{"items":[]}`)
	for _, p := range w.people {
		w.writePerson(p)
	}
	for code, slugs := range w.cities {
		w.writeCity(code)
		for _, s := range slugs {
			w.writeCityPerson(s)
		}
	}
	for _, v := range w.votes {
		w.f.write("votes/"+v+".json", `{"id":"`+v+`",`+w.bump()+`}`)
	}
}

func (w *world) codes() []string {
	var out []string
	for c := range w.cities {
		out = append(out, c)
	}
	sort.Strings(out)
	return out
}

func (w *world) mutate() []string {
	before := map[string]string{}
	for p := range w.f.paths {
		data, _ := os.ReadFile(filepath.Join(w.f.stage.Staging, filepath.FromSlash(p)))
		before[p] = string(data)
	}
	for range 1 + w.rng.IntN(6) {
		codes := w.codes()
		switch w.rng.IntN(10) {
		case 0:
			w.writePerson(w.people[w.rng.IntN(len(w.people))])
		case 1:
			v := fmt.Sprintf("senado-%d", w.version)
			w.votes = append(w.votes, v)
			w.f.write("votes/"+v+".json", `{"id":"`+v+`",`+w.bump()+`}`)
			w.f.write("today.json", `{"date":"2026-10-26","events":[],`+w.bump()+`}`)
		case 2:
			i := w.rng.IntN(len(w.votes))
			w.f.remove("votes/" + w.votes[i] + ".json")
			w.votes = append(w.votes[:i], w.votes[i+1:]...)
		case 3:
			code := codes[w.rng.IntN(len(codes))]
			w.writeCity(code)
		case 4:
			code := codes[w.rng.IntN(len(codes))]
			slug := fmt.Sprintf("novo-%d", w.version)
			w.cities[code] = append(w.cities[code], slug)
			w.writeCityPerson(slug)
			w.writeCity(code)
		case 5:
			code := codes[w.rng.IntN(len(codes))]
			if len(w.cities[code]) < 2 {
				continue
			}
			gone := w.cities[code][0]
			w.cities[code] = w.cities[code][1:]
			w.f.remove("people/" + gone + ".json")
			w.writeCity(code)
		case 6:
			code := codes[w.rng.IntN(len(codes))]
			if len(w.cities[code]) == 0 {
				continue
			}
			w.writeCityPerson(w.cities[code][w.rng.IntN(len(w.cities[code]))])
		case 7:
			p := w.people[w.rng.IntN(len(w.people))]
			w.f.write("people/"+p+"/checks.json", `{"items":[],`+w.bump()+`}`)
		case 8:
			w.f.write("money/overview.json", `{`+w.bump()+`}`)
		case 9:
			if len(codes) < 5 {
				continue
			}
			code := codes[w.rng.IntN(len(codes))]
			for _, slug := range w.cities[code] {
				w.f.remove("people/" + slug + ".json")
			}
			w.f.remove("places/city/" + code + ".json")
			delete(w.cities, code)
		}
	}
	var changed []string
	for p := range w.f.paths {
		data, _ := os.ReadFile(filepath.Join(w.f.stage.Staging, filepath.FromSlash(p)))
		if before[p] != string(data) {
			changed = append(changed, p)
		}
		delete(before, p)
	}
	for p := range before {
		changed = append(changed, p)
	}
	return changed
}

func snapshotTree(t *testing.T, dir string) map[string][]byte {
	t.Helper()
	out := map[string][]byte{}
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, _ := filepath.Rel(dir, p)
		if filepath.Base(rel) == ReleaseFile {
			return nil
		}
		data, err := os.ReadFile(p)
		out[filepath.ToSlash(rel)] = data
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func compareTrees(t *testing.T, got, want map[string][]byte) {
	t.Helper()
	for p, w := range want {
		g, ok := got[p]
		if !ok {
			t.Fatalf("delta release is missing %s", p)
		}
		if !bytes.Equal(g, w) {
			t.Fatalf("%s differs:\n delta: %s\n full:  %s", p, g, w)
		}
	}
	for p := range got {
		if _, ok := want[p]; !ok {
			t.Fatalf("delta release has an extra %s", p)
		}
	}
}

func TestStageDeltaMatchesAFullStage(t *testing.T) {
	for seed := range uint64(3) {
		w := newWorld(t, seed+1)
		if _, err := w.f.run("full"); err != nil {
			t.Fatal(err)
		}
		for round := range 12 {
			changed := w.mutate()
			w.f.clock = w.f.clock.Add(time.Minute)
			rel, err := w.f.stage.StageDelta("live", w.f.list(), changed)
			if err != nil {
				t.Fatalf("seed %d round %d: %v", seed, round, err)
			}
			full := &Stager{Staging: w.f.stage.Staging, Root: filepath.Join(t.TempDir(), "site"), Keep: 3, Rules: Rules{MinPeople: 1}, Now: w.f.stage.Now}
			want, err := full.Stage("full", w.f.list())
			if err != nil {
				t.Fatal(err)
			}
			compareTrees(t, snapshotTree(t, filepath.Join(w.f.stage.Root, SitesDir, rel.Release)), snapshotTree(t, filepath.Join(full.Root, SitesDir, want.Release)))
			if rel.Files != want.Files || rel.Logical != want.Logical || rel.People != want.People {
				t.Fatalf("release counts differ: %+v vs %+v", rel, want)
			}
		}
	}
}

func TestStageDeltaRewritesOnlyWhatChanged(t *testing.T) {
	w := newWorld(t, 99)
	first, err := w.f.run("full")
	if err != nil {
		t.Fatal(err)
	}
	w.writePerson(w.people[3])
	rel, err := w.f.stage.StageDelta("live", w.f.list(), []string{"people/" + w.people[3] + ".json", "people/" + w.people[3] + "/votes-2026.json"})
	if err != nil {
		t.Fatal(err)
	}
	if rel.Base != first.Release || rel.Rebuilt != 1 {
		t.Fatalf("base=%s rebuilt=%d, want %s and 1", rel.Base, rel.Rebuilt, first.Release)
	}
	a, _ := os.Stat(filepath.Join(w.f.stage.Root, SitesDir, first.Release, Layout, "people", w.people[4]+".json"))
	b, _ := os.Stat(filepath.Join(w.f.stage.Root, SitesDir, rel.Release, Layout, "people", w.people[4]+".json"))
	if !os.SameFile(a, b) {
		t.Fatal("an unchanged bundle must be a hard link to the previous release")
	}
}

func TestStageDeltaFallsBackWithoutAPreviousRelease(t *testing.T) {
	w := newWorld(t, 5)
	rel, err := w.f.stage.StageDelta("live", w.f.list(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if rel.Base != "" || rel.Rebuilt == 0 {
		t.Fatalf("a first release is a full stage: %+v", rel)
	}
}

func TestStageDeltaStillValidates(t *testing.T) {
	w := newWorld(t, 7)
	if _, err := w.f.run("full"); err != nil {
		t.Fatal(err)
	}
	w.f.write("people/"+w.people[0]+".json", `{broken`)
	_, err := w.f.stage.StageDelta("live", w.f.list(), []string{"people/" + w.people[0] + ".json"})
	if err == nil {
		t.Fatal("a broken file must fail the delta release")
	}
}
