package site

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

var errFull = errors.New("site: delta needs a full stage")

type delta struct {
	prev    string
	out     string
	plan    plan
	changed map[string]bool
	read    reader
	write   writer
	written map[string]bool
	buckets map[string]map[string]string
}

func (s *Stager) StageDelta(kind string, paths, changed []string) (Release, error) {
	if !validKind(kind) {
		return Release{}, errors.New("site: kind must be full, live or a phase name")
	}
	prevName, err := s.CurrentName()
	if err != nil {
		return Release{}, err
	}
	if prevName == "" {
		return s.Stage(kind, paths)
	}
	prevDir := filepath.Join(s.sites(), prevName)
	if _, err := ReadRelease(prevDir); err != nil {
		return s.Stage(kind, paths)
	}
	if err := os.MkdirAll(s.sites(), 0o755); err != nil {
		return Release{}, err
	}
	s.clearTemp()
	indexed, people, err := s.indexed()
	if err != nil {
		return Release{}, err
	}
	for _, p := range paths {
		if !validPath(p) {
			return Release{}, fmt.Errorf("site: invalid path %q", p)
		}
	}
	name, err := s.newName(kind)
	if err != nil {
		return Release{}, err
	}
	tmp := filepath.Join(s.sites(), ".tmp-"+name)
	rel, err := s.buildDelta(tmp, filepath.Join(prevDir, Layout), name, kind, paths, changed, indexed, people)
	if errors.Is(err, errFull) {
		os.RemoveAll(tmp)
		s.logf("site: %v, staging everything", err)
		return s.Stage(kind, paths)
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
	s.logf("site %s ready from %s: files=%d logical=%d people=%d rebuilt=%d", name, prevName, rel.Files, rel.Logical, rel.People, rel.Rebuilt)
	return rel, nil
}

func sameIndexed(prevV2 string, indexed map[string]bool) bool {
	data, err := os.ReadFile(filepath.Join(prevV2, "index", "people.json"))
	if err != nil {
		return false
	}
	var cards []struct {
		Slug string `json:"slug"`
	}
	if json.Unmarshal(data, &cards) != nil || len(cards) != len(indexed) {
		return false
	}
	for _, c := range cards {
		if !indexed[c.Slug] {
			return false
		}
	}
	return true
}

func (s *Stager) buildDelta(tmp, prevV2, name, kind string, paths, changed []string, indexed map[string]bool, people int) (Release, error) {
	rel := s.newRelease(name, kind, len(paths), people)
	rel.Base = filepath.Base(filepath.Dir(prevV2))
	if !sameIndexed(prevV2, indexed) {
		return rel, fmt.Errorf("%w: the people index changed its members", errFull)
	}
	out := filepath.Join(tmp, Layout)
	d := &delta{prev: prevV2, out: out, plan: planLayout(paths, indexed), changed: map[string]bool{}, written: map[string]bool{}, buckets: map[string]map[string]string{}}
	for _, c := range changed {
		d.changed[c] = true
	}
	d.read = func(p string) (json.RawMessage, error) {
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
	d.write = func(p string, v any) error {
		data, err := json.Marshal(v)
		if err != nil {
			return err
		}
		if len(data) > MaxFileBytes {
			return fmt.Errorf("%w: %s would be larger than 25 MiB", ErrValidation, p)
		}
		d.written[p] = true
		return writeFile(filepath.Join(out, filepath.FromSlash(p)), data)
	}
	if err := d.direct(); err != nil {
		return rel, err
	}
	people2, err := d.cities()
	if err != nil {
		return rel, err
	}
	if err := d.people(people2); err != nil {
		return rel, err
	}
	if err := d.votes(); err != nil {
		return rel, err
	}
	rel, err = s.finish(tmp, rel, len(d.written))
	if err != nil {
		return rel, err
	}
	d.written[ReleaseFile] = true
	return rel, s.validate(tmp, rel, d.written)
}

func (d *delta) link(p string) (bool, error) {
	src := filepath.Join(d.prev, filepath.FromSlash(p))
	dst := filepath.Join(d.out, filepath.FromSlash(p))
	if _, err := os.Stat(src); err != nil {
		return false, nil
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return false, err
	}
	if err := os.Link(src, dst); err == nil {
		return true, nil
	}
	return true, copyFile(src, dst)
}

func (d *delta) direct() error {
	for _, p := range d.plan.direct {
		if !d.changed[p] {
			ok, err := d.link(p)
			if err != nil {
				return err
			}
			if ok {
				continue
			}
		}
		data, err := d.read(p)
		if err != nil {
			return err
		}
		d.written[p] = true
		if err := writeFile(filepath.Join(d.out, filepath.FromSlash(p)), data); err != nil {
			return err
		}
	}
	return nil
}

func (d *delta) prevBucket(bucket string) (map[string]string, error) {
	if items, ok := d.buckets[bucket]; ok {
		return items, nil
	}
	items := map[string]string{}
	data, err := os.ReadFile(filepath.Join(d.prev, CityPeopleIndex.Dir, bucket+".json"))
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	if err == nil {
		var f Items[string]
		if err := json.Unmarshal(data, &f); err != nil {
			return nil, fmt.Errorf("%w: previous %s/%s.json: %v", ErrValidation, CityPeopleIndex.Dir, bucket, err)
		}
		if f.Items != nil {
			items = f.Items
		}
	}
	d.buckets[bucket] = items
	return items, nil
}

func (d *delta) prevCity(slug string) (string, bool, error) {
	items, err := d.prevBucket(CityPeopleIndex.Bucket(slug))
	if err != nil {
		return "", false, err
	}
	code, ok := items[slug]
	return code, ok, nil
}

func (d *delta) prevCityPeople(code string) ([]string, error) {
	data, err := os.ReadFile(filepath.Join(d.prev, "places", "city", code+".json"))
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var bundle struct {
		People map[string]json.RawMessage `json:"people"`
	}
	if err := json.Unmarshal(data, &bundle); err != nil {
		return nil, fmt.Errorf("%w: previous places/city/%s.json: %v", ErrValidation, code, err)
	}
	return sortedKeys(bundle.People), nil
}

func (d *delta) cities() (map[string]bool, error) {
	dirty := map[string]bool{}
	for code, p := range d.plan.cities {
		if d.changed[p] {
			dirty[code] = true
		}
	}
	for c := range d.changed {
		rest, ok := strings.CutPrefix(c, "people/")
		if !ok || strings.Contains(rest, "/") {
			continue
		}
		slug := strings.TrimSuffix(rest, ".json")
		if _, national := d.plan.people[slug]; national {
			continue
		}
		code, found, err := d.prevCity(slug)
		if err != nil {
			return nil, err
		}
		if found {
			if _, exists := d.plan.cities[code]; exists {
				dirty[code] = true
			}
		}
	}
	refs := map[string]map[string]bool{}
	for code := range dirty {
		r, err := d.plan.writeCity(code, d.read, d.write)
		if err != nil {
			return nil, err
		}
		refs[code] = map[string]bool{}
		for _, x := range r {
			refs[code][x.slug] = true
		}
	}
	for code, p := range d.plan.cities {
		if dirty[code] {
			continue
		}
		ok, err := d.link("places/city/" + code + ".json")
		if err != nil {
			return nil, err
		}
		if !ok {
			return nil, fmt.Errorf("%w: %s is missing in the previous release", errFull, p)
		}
	}
	next := map[string]map[string]string{}
	touched := map[string]bool{}
	for code := range dirty {
		prev, err := d.prevCityPeople(code)
		if err != nil {
			return nil, err
		}
		for _, slug := range prev {
			touched[CityPeopleIndex.Bucket(slug)] = true
			if _, live := d.plan.cityPeople[slug]; !live {
				continue
			}
			was, found, err := d.prevCity(slug)
			if err != nil {
				return nil, err
			}
			if !found || was != code || refs[code][slug] {
				continue
			}
			moved := false
			for _, slugs := range refs {
				moved = moved || slugs[slug]
			}
			if !moved {
				return nil, fmt.Errorf("%w: %s left city %s", errFull, slug, code)
			}
		}
		for slug := range refs[code] {
			touched[CityPeopleIndex.Bucket(slug)] = true
		}
	}
	for bucket := range touched {
		prev, err := d.prevBucket(bucket)
		if err != nil {
			return nil, err
		}
		items := map[string]string{}
		for slug, code := range prev {
			if _, live := d.plan.cityPeople[slug]; live && !dirty[code] {
				if _, exists := d.plan.cities[code]; exists {
					items[slug] = code
				}
			}
		}
		next[bucket] = items
	}
	for code, slugs := range refs {
		for slug := range slugs {
			b := CityPeopleIndex.Bucket(slug)
			if cur, ok := next[b][slug]; !ok || code < cur {
				next[b][slug] = code
			}
		}
	}
	referenced := map[string]bool{}
	for slug := range d.plan.cityPeople {
		b := CityPeopleIndex.Bucket(slug)
		if items, ok := next[b]; ok {
			if _, in := items[slug]; in {
				referenced[slug] = true
			}
			continue
		}
		if _, found, err := d.prevCity(slug); err != nil {
			return nil, err
		} else if found {
			referenced[slug] = true
		}
	}
	entries, err := os.ReadDir(filepath.Join(d.prev, CityPeopleIndex.Dir))
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	for _, e := range entries {
		bucket := strings.TrimSuffix(e.Name(), ".json")
		if e.IsDir() || touched[bucket] || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		if _, err := d.link(CityPeopleIndex.Dir + "/" + e.Name()); err != nil {
			return nil, err
		}
	}
	for bucket, items := range next {
		if len(items) == 0 {
			continue
		}
		if err := d.write(CityPeopleIndex.Dir+"/"+bucket+".json", Items[string]{Items: items}); err != nil {
			return nil, err
		}
	}
	return referenced, nil
}

func (d *delta) people(referenced map[string]bool) error {
	bundles := map[string][]string{}
	for slug, srcs := range d.plan.people {
		bundles[slug] = srcs
	}
	for slug, src := range d.plan.cityPeople {
		if !referenced[slug] {
			bundles[slug] = []string{src}
		}
	}
	dirty := map[string]bool{}
	for c := range d.changed {
		rest, ok := strings.CutPrefix(c, "people/")
		if !ok {
			continue
		}
		slug, _, _ := strings.Cut(rest, "/")
		dirty[strings.TrimSuffix(slug, ".json")] = true
	}
	for _, slug := range sortedKeys(bundles) {
		p := "people/" + slug + ".json"
		if !dirty[slug] {
			ok, err := d.link(p)
			if err != nil {
				return err
			}
			if ok {
				continue
			}
		}
		if err := writePerson(slug, bundles[slug], d.read, d.write); err != nil {
			return err
		}
	}
	return nil
}

func (d *delta) votes() error {
	dirty := map[string]bool{}
	for c := range d.changed {
		rest, ok := strings.CutPrefix(c, "votes/")
		if !ok || strings.Contains(rest, "/") || rest == "recent.json" {
			continue
		}
		dirty[VoteBundles.Bucket(strings.TrimSuffix(rest, ".json"))] = true
	}
	for _, bucket := range sortedKeys(d.plan.votes) {
		p := VoteBundles.Dir + "/" + bucket + ".json"
		if !dirty[bucket] {
			ok, err := d.link(p)
			if err != nil {
				return err
			}
			if ok {
				continue
			}
		}
		if err := d.plan.writeVotes(bucket, d.read, d.write); err != nil {
			return err
		}
	}
	return nil
}
