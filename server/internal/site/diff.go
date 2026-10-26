package site

import (
	"bytes"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

func (s *Stager) Dir(name string) string {
	return filepath.Join(s.sites(), name)
}

func Diff(a, b string, skip func(rel string) bool) ([]string, error) {
	list := func(root string) (map[string]string, error) {
		out := map[string]string{}
		err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return err
			}
			rel, err := filepath.Rel(root, p)
			if err != nil {
				return err
			}
			rel = filepath.ToSlash(rel)
			if skip == nil || !skip(rel) {
				out[rel] = p
			}
			return nil
		})
		return out, err
	}
	left, err := list(a)
	if err != nil {
		return nil, err
	}
	right, err := list(b)
	if err != nil {
		return nil, err
	}
	var out []string
	for rel, pa := range left {
		pb, ok := right[rel]
		if !ok {
			out = append(out, rel)
			continue
		}
		ia, errA := os.Stat(pa)
		ib, errB := os.Stat(pb)
		if errA == nil && errB == nil && os.SameFile(ia, ib) {
			continue
		}
		da, err := os.ReadFile(pa)
		if err != nil {
			return nil, err
		}
		db, err := os.ReadFile(pb)
		if err != nil {
			return nil, err
		}
		if !bytes.Equal(da, db) {
			out = append(out, rel)
		}
	}
	for rel := range right {
		if _, ok := left[rel]; !ok {
			out = append(out, rel)
		}
	}
	sort.Strings(out)
	return out, nil
}
