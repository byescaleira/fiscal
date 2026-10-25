package publicdata

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

func CPFKey(cpf string) string {
	sum := sha256.Sum256([]byte("fiscal-person:" + cpf))
	return "cpf:" + hex.EncodeToString(sum[:10])
}

type Slugs struct {
	path  string
	byKey map[string]string
}

type slugFile struct {
	Version int               `json:"version"`
	Slugs   map[string]string `json:"slugs"`
}

func LoadSlugs(path string) (*Slugs, error) {
	s := &Slugs{path: path, byKey: map[string]string{}}
	if path == "" {
		return s, nil
	}
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	var f slugFile
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("slugs: %w", err)
	}
	for k, v := range f.Slugs {
		s.byKey[k] = v
	}
	return s, nil
}

func (s *Slugs) Save() error {
	if s.path == "" {
		return nil
	}
	data, err := json.Marshal(slugFile{Version: 1, Slugs: s.byKey})
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(s.path), ".slugs-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(name, s.path)
}

func (s *Slugs) owners() map[string]map[string]bool {
	out := map[string]map[string]bool{}
	for k, v := range s.byKey {
		if out[v] == nil {
			out[v] = map[string]bool{}
		}
		out[v][k] = true
	}
	return out
}

func (s *Slugs) Assign(people []*Person) map[*Person]string {
	sorted := append([]*Person(nil), people...)
	sort.SliceStable(sorted, func(i, j int) bool {
		a, b := Fold(sorted[i].Name), Fold(sorted[j].Name)
		if a != b {
			return a < b
		}
		return firstKey(sorted[i]) < firstKey(sorted[j])
	})
	owners := s.owners()
	out := map[*Person]string{}
	used := map[string]*Person{}
	for _, p := range sorted {
		for _, k := range p.Keys {
			slug, ok := s.byKey[k]
			if !ok {
				continue
			}
			if _, taken := used[slug]; taken {
				continue
			}
			out[p] = slug
			used[slug] = p
			break
		}
	}
	bases := map[string]map[string]bool{}
	for _, p := range sorted {
		b := Slugify(p.Name)
		if bases[b] == nil {
			bases[b] = map[string]bool{}
		}
		bases[b][p.Primary().UF] = true
	}
	free := func(slug string, p *Person) bool {
		if _, taken := used[slug]; taken {
			return false
		}
		for k := range owners[slug] {
			if !hasKey(p, k) {
				return false
			}
		}
		return true
	}
	for _, p := range sorted {
		if _, ok := out[p]; ok {
			continue
		}
		base := Slugify(p.Name)
		if base == "" {
			base = "pessoa"
		}
		uf := p.Primary().UF
		var slug string
		if len(bases[base]) <= 1 && free(base, p) {
			slug = base
		} else {
			cand := base + "-" + uf
			for n := 2; !free(cand, p); n++ {
				cand = fmt.Sprintf("%s-%s-%d", base, uf, n)
			}
			slug = cand
		}
		out[p] = slug
		used[slug] = p
	}
	for p, slug := range out {
		for _, k := range p.Keys {
			s.byKey[k] = slug
		}
	}
	return out
}

func (s *Slugs) AssignScoped(people []*Person, base func(*Person) string, taken map[string]bool) map[*Person]string {
	bases := map[*Person]string{}
	for _, p := range people {
		b := base(p)
		if b == "" {
			b = "pessoa"
		}
		bases[p] = b
	}
	sorted := append([]*Person(nil), people...)
	sort.SliceStable(sorted, func(i, j int) bool {
		if bases[sorted[i]] != bases[sorted[j]] {
			return bases[sorted[i]] < bases[sorted[j]]
		}
		return firstKey(sorted[i]) < firstKey(sorted[j])
	})
	owners := s.owners()
	used := map[string]bool{}
	for slug := range taken {
		used[slug] = true
	}
	out := map[*Person]string{}
	for _, p := range sorted {
		for _, k := range p.Keys {
			slug, ok := s.byKey[k]
			if !ok || used[slug] {
				continue
			}
			out[p] = slug
			used[slug] = true
			break
		}
	}
	free := func(slug string, p *Person) bool {
		if used[slug] {
			return false
		}
		for k := range owners[slug] {
			if !hasKey(p, k) {
				return false
			}
		}
		return true
	}
	for _, p := range sorted {
		if _, ok := out[p]; ok {
			continue
		}
		slug := bases[p]
		for n := 2; !free(slug, p); n++ {
			slug = fmt.Sprintf("%s-%d", bases[p], n)
		}
		out[p] = slug
		used[slug] = true
	}
	for p, slug := range out {
		for _, k := range p.Keys {
			s.byKey[k] = slug
		}
	}
	return out
}

func firstKey(p *Person) string {
	if len(p.Keys) == 0 {
		return ""
	}
	return p.Keys[0]
}

func hasKey(p *Person, k string) bool {
	for _, x := range p.Keys {
		if x == k {
			return true
		}
	}
	return false
}
