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

func (p plan) write(read reader, write writer) error {
	slugCity := map[string]string{}
	codes := make([]string, 0, len(p.cities))
	for code := range p.cities {
		codes = append(codes, code)
	}
	sort.Strings(codes)
	for _, code := range codes {
		data, err := read(p.cities[code])
		if err != nil {
			return err
		}
		var place struct {
			Groups []struct {
				People []struct {
					Slug *string `json:"slug"`
				} `json:"people"`
			} `json:"groups"`
		}
		if err := json.Unmarshal(data, &place); err != nil {
			return fmt.Errorf("%w: places/city/%s.json: %v", ErrValidation, code, err)
		}
		bundle := CityBundle{Place: data, People: map[string]json.RawMessage{}}
		for _, g := range place.Groups {
			for _, person := range g.People {
				if person.Slug == nil {
					continue
				}
				src, ok := p.cityPeople[*person.Slug]
				if !ok {
					continue
				}
				if _, done := bundle.People[*person.Slug]; done {
					continue
				}
				prof, err := read(src)
				if err != nil {
					return err
				}
				bundle.People[*person.Slug] = prof
				if _, seen := slugCity[*person.Slug]; !seen {
					slugCity[*person.Slug] = code
				}
			}
		}
		if err := write("places/city/"+code+".json", bundle); err != nil {
			return err
		}
	}
	index := map[string]map[string]string{}
	orphans := map[string][]string{}
	for slug, src := range p.cityPeople {
		code, ok := slugCity[slug]
		if !ok {
			orphans[slug] = []string{src}
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
	people := p.people
	for slug, srcs := range orphans {
		people[slug] = srcs
	}
	slugs := make([]string, 0, len(people))
	for slug := range people {
		slugs = append(slugs, slug)
	}
	sort.Strings(slugs)
	for _, slug := range slugs {
		pf := PersonFile{Profile: json.RawMessage("null"), Files: map[string]json.RawMessage{}}
		for _, src := range people[slug] {
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
		if err := write("people/"+slug+".json", pf); err != nil {
			return err
		}
	}
	for b, ids := range p.votes {
		items := map[string]json.RawMessage{}
		for id, src := range ids {
			data, err := read(src)
			if err != nil {
				return err
			}
			items[id] = data
		}
		if err := write(VoteBundles.Dir+"/"+b+".json", Items[json.RawMessage]{Items: items}); err != nil {
			return err
		}
	}
	return nil
}
