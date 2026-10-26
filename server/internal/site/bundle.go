package site

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

type Family struct {
	Dir   string
	Count int
}

var (
	CityPeopleIndex = Family{Dir: "index/city-people", Count: 256}
	VoteBundles     = Family{Dir: "votes/by-id", Count: 512}
)

func (f Family) Bucket(key string) string {
	sum := sha256.Sum256([]byte(key))
	v := (int(sum[0])<<8 | int(sum[1])) % f.Count
	width := len(fmt.Sprintf("%x", f.Count-1))
	return fmt.Sprintf("%0*x", width, v)
}

func (f Family) Path(key string) string {
	return f.Dir + "/" + f.Bucket(key) + ".json"
}

type PersonFile struct {
	Profile json.RawMessage            `json:"profile"`
	Files   map[string]json.RawMessage `json:"files"`
}

type CityBundle struct {
	Place  json.RawMessage            `json:"place"`
	People map[string]json.RawMessage `json:"people"`
}

type Items[T any] struct {
	Items map[string]T `json:"items"`
}

type plan struct {
	direct     []string
	people     map[string][]string
	cityPeople map[string]string
	cities     map[string]string
	votes      map[string]map[string]string
}

func planLayout(paths []string, indexed map[string]bool) plan {
	p := plan{people: map[string][]string{}, cityPeople: map[string]string{}, cities: map[string]string{}, votes: map[string]map[string]string{}}
	nested := map[string]bool{}
	for _, path := range paths {
		if rest, ok := strings.CutPrefix(path, "people/"); ok {
			if slug, _, sub := strings.Cut(rest, "/"); sub {
				nested[slug] = true
			}
		}
	}
	for _, path := range paths {
		if rest, ok := strings.CutPrefix(path, "people/"); ok {
			slug, file, sub := strings.Cut(rest, "/")
			if sub && strings.Contains(file, "/") {
				p.direct = append(p.direct, path)
				continue
			}
			if !sub {
				slug = strings.TrimSuffix(rest, ".json")
				if !indexed[slug] && !nested[slug] {
					p.cityPeople[slug] = path
					continue
				}
			}
			p.people[slug] = append(p.people[slug], path)
			continue
		}
		if rest, ok := strings.CutPrefix(path, "places/city/"); ok && !strings.Contains(rest, "/") {
			p.cities[strings.TrimSuffix(rest, ".json")] = path
			continue
		}
		if rest, ok := strings.CutPrefix(path, "votes/"); ok && !strings.Contains(rest, "/") && rest != "recent.json" {
			id := strings.TrimSuffix(rest, ".json")
			b := VoteBundles.Bucket(id)
			if p.votes[b] == nil {
				p.votes[b] = map[string]string{}
			}
			p.votes[b][id] = path
			continue
		}
		p.direct = append(p.direct, path)
	}
	sort.Strings(p.direct)
	return p
}

type reader func(path string) (json.RawMessage, error)

type writer func(path string, v any) error

type cityRef struct {
	slug string
	src  string
}

func (p plan) cityRefs(code string, data json.RawMessage) ([]cityRef, error) {
	var place struct {
		Groups []struct {
			People []struct {
				Slug *string `json:"slug"`
			} `json:"people"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(data, &place); err != nil {
		return nil, fmt.Errorf("%w: places/city/%s.json: %v", ErrValidation, code, err)
	}
	var out []cityRef
	seen := map[string]bool{}
	for _, g := range place.Groups {
		for _, person := range g.People {
			if person.Slug == nil || seen[*person.Slug] {
				continue
			}
			src, ok := p.cityPeople[*person.Slug]
			if !ok {
				continue
			}
			seen[*person.Slug] = true
			out = append(out, cityRef{slug: *person.Slug, src: src})
		}
	}
	return out, nil
}

func (p plan) writeCity(code string, read reader, write writer) ([]cityRef, error) {
	data, err := read(p.cities[code])
	if err != nil {
		return nil, err
	}
	refs, err := p.cityRefs(code, data)
	if err != nil {
		return nil, err
	}
	bundle := CityBundle{Place: data, People: map[string]json.RawMessage{}}
	for _, r := range refs {
		prof, err := read(r.src)
		if err != nil {
			return nil, err
		}
		bundle.People[r.slug] = prof
	}
	return refs, write("places/city/"+code+".json", bundle)
}

func writePerson(slug string, srcs []string, read reader, write writer) error {
	pf := PersonFile{Profile: json.RawMessage("null"), Files: map[string]json.RawMessage{}}
	for _, src := range srcs {
		data, err := read(src)
		if err != nil {
			return err
		}
		if src == "people/"+slug+".json" {
			pf.Profile = data
		} else {
			pf.Files[strings.TrimPrefix(src, "people/"+slug+"/")] = data
		}
	}
	return write("people/"+slug+".json", pf)
}

func (p plan) writeVotes(bucket string, read reader, write writer) error {
	items := map[string]json.RawMessage{}
	for id, src := range p.votes[bucket] {
		data, err := read(src)
		if err != nil {
			return err
		}
		items[id] = data
	}
	return write(VoteBundles.Dir+"/"+bucket+".json", Items[json.RawMessage]{Items: items})
}

func sortedKeys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func (p plan) write(read reader, write writer) error {
	slugCity := map[string]string{}
	for _, code := range sortedKeys(p.cities) {
		refs, err := p.writeCity(code, read, write)
		if err != nil {
			return err
		}
		for _, r := range refs {
			if _, seen := slugCity[r.slug]; !seen {
				slugCity[r.slug] = code
			}
		}
	}
	index := map[string]map[string]string{}
	people := map[string][]string{}
	for slug, srcs := range p.people {
		people[slug] = srcs
	}
	for slug, src := range p.cityPeople {
		code, ok := slugCity[slug]
		if !ok {
			people[slug] = []string{src}
			continue
		}
		b := CityPeopleIndex.Bucket(slug)
		if index[b] == nil {
			index[b] = map[string]string{}
		}
		index[b][slug] = code
	}
	for b, items := range index {
		if err := write(CityPeopleIndex.Dir+"/"+b+".json", Items[string]{Items: items}); err != nil {
			return err
		}
	}
	for _, slug := range sortedKeys(people) {
		if err := writePerson(slug, people[slug], read, write); err != nil {
			return err
		}
	}
	for b := range p.votes {
		if err := p.writeVotes(b, read, write); err != nil {
			return err
		}
	}
	return nil
}
