package ingest

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"liveresults/internal/publish"
	"liveresults/internal/site"
)

const (
	ConsistencyFile = "consistency.json"
	CheckDir        = "check"
	CheckBase       = "base-manifest.json"
	CheckManifest   = "manifest.json"
)

type Consistency struct {
	CheckedAt   string   `json:"checkedAt"`
	Incremental string   `json:"incremental,omitempty"`
	Full        string   `json:"full"`
	Staging     int      `json:"staging"`
	Site        int      `json:"site"`
	Sample      []string `json:"sample"`
	Refreshed   int      `json:"refreshed"`
	Held        []string `json:"held,omitempty"`
	Released    string   `json:"released,omitempty"`
	Skipped     int      `json:"skipped,omitempty"`
}

func volatile(rel string) bool {
	rel = strings.TrimPrefix(rel, site.Layout+"/")
	return rel == "meta.json" || rel == site.ReleaseFile || strings.HasPrefix(rel, "history/")
}

func sample(paths []string, n int) []string {
	if len(paths) > n {
		return append([]string(nil), paths[:n]...)
	}
	return paths
}

func (in *Ingest) Verify(ctx context.Context, hooks SyncHooks, j Job) (string, error) {
	var incremental Report
	if _, err := os.Stat(in.SnapshotPath()); err == nil {
		saved := in.cfg
		in.cfg.Rebuild = false
		in.cfg.ReleaseKind = "incremental"
		r, err := in.Derived(ctx)
		in.cfg = saved
		if err != nil {
			in.logger.Printf("verify: the incremental pass failed, comparing only the staging area: %v", err)
		} else {
			incremental = r
		}
	}
	in.mu.Lock()
	in.dataset = nil
	in.mu.Unlock()
	chk, err := in.openCheck()
	if err != nil {
		return "conferência não montou a cópia do preparo", err
	}
	kept := keepFiles(in.path(HotBaseFile), in.path(CityPaths))
	saved, savedSite, savedMan := in.cfg, in.site, in.man
	in.cfg.PublicDir, in.man, in.site = chk.root, chk.manifest, chk.stager(savedSite)
	rep, err := in.Full(ctx)
	in.cfg, in.site, in.man = saved, savedSite, savedMan
	if err != nil {
		os.RemoveAll(chk.root)
		kept.restore()
		return "reconstrução completa falhou", err
	}
	changed := chk.changed()
	var staging, refreshed []string
	for _, p := range changed {
		if volatile(p) {
			if strings.HasPrefix(p, "history/") {
				refreshed = append(refreshed, p)
			}
			continue
		}
		staging = append(staging, p)
	}
	var siteDiff []string
	if in.site != nil && incremental.Release != "" && rep.Release != "" && incremental.Release != rep.Release {
		siteDiff, err = site.Diff(in.site.Dir(incremental.Release), in.site.Dir(rep.Release), volatile)
		if err != nil {
			in.logger.Printf("verify: compare releases: %v", err)
		}
	}
	c := Consistency{CheckedAt: in.stamp(), Incremental: incremental.Release, Full: rep.Release, Staging: len(staging), Site: len(siteDiff), Sample: sample(append(append([]string(nil), staging...), siteDiff...), 30), Refreshed: len(refreshed)}
	line := fmt.Sprintf("reconstrução completa (%d arquivos, release %s); divergência do incremental: %d no preparo, %d no site", rep.Files, rep.Release, c.Staging, c.Site)
	if c.Staging+c.Site > 0 {
		c.Held = heldPaths(staging, siteDiff)
		kept.restore()
		in.mu.Lock()
		in.dataset = nil
		in.mu.Unlock()
		in.writeConsistency(c)
		in.logger.Printf("ALERT consistency: %s; amostra: %s", line, strings.Join(c.Sample, ", "))
		in.logger.Printf("consistency: the staging area and the ready site stay as they were; -site publish-held publishes the check")
		return line, fmt.Errorf("%w: %d staging files and %d site files differ", ErrDivergence, c.Staging, c.Site)
	}
	if err := in.adoptCheck(chk, rep.Release); err != nil {
		return "a conferência bateu, mas a troca do preparo falhou", err
	}
	in.writeConsistency(c)
	if hooks.AfterSources != nil {
		hooks.AfterSources(ctx, j)
	}
	return line, nil
}

func (in *Ingest) writeConsistency(c Consistency) {
	data, err := json.MarshalIndent(c, "", " ")
	if err == nil {
		err = writeAtomic(in.path(ConsistencyFile), data)
	}
	if err != nil {
		in.logger.Printf("ALERT consistency: could not record the check: %v", err)
	}
}

type savedFiles map[string][]byte

func keepFiles(paths ...string) savedFiles {
	kept := savedFiles{}
	for _, p := range paths {
		if data, err := os.ReadFile(p); err == nil {
			kept[p] = data
		}
	}
	return kept
}

func (k savedFiles) restore() {
	for p, data := range k {
		writeAtomic(p, data)
	}
}

type check struct {
	root     string
	base     *publish.Manifest
	manifest *publish.Manifest
}

func checkRoot(publicDir string) string {
	return filepath.Join(publicDir, CheckDir)
}

func (in *Ingest) openCheck() (*check, error) {
	root := checkRoot(in.cfg.PublicDir)
	if err := os.RemoveAll(root); err != nil {
		return nil, err
	}
	main, err := in.manifest()
	if err != nil {
		return nil, err
	}
	if err := main.Save(); err != nil {
		return nil, err
	}
	data, err := os.ReadFile(in.path(ManifestFile))
	if err != nil {
		return nil, err
	}
	for _, name := range []string{CheckBase, CheckManifest} {
		if err := writeAtomic(filepath.Join(root, name), data); err != nil {
			return nil, err
		}
	}
	if err := linkTree(filepath.Join(in.cfg.PublicDir, "v1"), filepath.Join(root, "v1")); err != nil {
		return nil, err
	}
	chk := &check{root: root}
	if chk.base, err = publish.LoadManifest(filepath.Join(root, CheckBase)); err != nil {
		return nil, err
	}
	if chk.manifest, err = publish.LoadManifest(filepath.Join(root, CheckManifest)); err != nil {
		return nil, err
	}
	return chk, nil
}

func (c *check) stager(live *site.Stager) *site.Stager {
	if live == nil {
		return nil
	}
	st := *live
	st.Staging = filepath.Join(c.root, "v1")
	st.Detached = true
	return &st
}

func (c *check) changed() []string {
	return manifestDiff(c.base, c.manifest)
}

func manifestDiff(a, b *publish.Manifest) []string {
	var out []string
	for _, p := range slices.Compact(slices.Sorted(slices.Values(slices.Concat(a.Paths(), b.Paths())))) {
		ha, oka := a.Get(p)
		hb, okb := b.Get(p)
		if oka != okb || ha != hb {
			out = append(out, p)
		}
	}
	return out
}

func (in *Ingest) adoptCheck(chk *check, release string) error {
	main, err := in.manifest()
	if err != nil {
		return err
	}
	if _, err := moveChecked(chk.root, in.cfg.PublicDir, chk.base, chk.manifest, main); err != nil {
		return err
	}
	if err := main.Save(); err != nil {
		return err
	}
	if in.site != nil && release != "" {
		if err := in.site.Promote(release); err != nil {
			return err
		}
		main.Settle()
		if err := main.Save(); err != nil {
			return err
		}
	}
	return os.RemoveAll(chk.root)
}

func moveChecked(root, publicDir string, base, checked, main *publish.Manifest) (int, error) {
	skipped := 0
	for _, p := range manifestDiff(base, checked) {
		was, inBase := base.Get(p)
		now, inMain := main.Get(p)
		if inBase != inMain || was != now {
			skipped++
			continue
		}
		target := filepath.Join(publicDir, "v1", filepath.FromSlash(p))
		hash, inCheck := checked.Get(p)
		if !inCheck {
			os.Remove(target)
			os.Remove(target + ".gz")
			main.Forget(p)
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return skipped, err
		}
		from := filepath.Join(root, "v1", filepath.FromSlash(p))
		if err := os.Rename(from+".gz", target+".gz"); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return skipped, err
		}
		if err := os.Rename(from, target); err != nil {
			return skipped, err
		}
		main.Adopt(p, hash)
	}
	return skipped, nil
}

func linkTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if err := os.Link(path, target); err == nil {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(target, data, 0o644)
	})
}

func heldPaths(staging, siteDiff []string) []string {
	held := slices.Concat(staging, siteDiff)
	slices.Sort(held)
	return slices.Compact(held)
}

func ReadConsistency(dataDir string) (Consistency, bool, error) {
	var c Consistency
	data, err := os.ReadFile(filepath.Join(dataDir, ConsistencyFile))
	if errors.Is(err, fs.ErrNotExist) {
		return c, false, nil
	}
	if err != nil {
		return c, false, err
	}
	if err := json.Unmarshal(data, &c); err != nil {
		return c, false, fmt.Errorf("%s: %w", ConsistencyFile, err)
	}
	return c, true, nil
}

func PublishHeld(dataDir, publicDir string, st *site.Stager) (site.Release, int, error) {
	c, ok, err := ReadConsistency(dataDir)
	if err != nil {
		return site.Release{}, 0, err
	}
	if !ok || len(c.Held) == 0 {
		return site.Release{}, 0, errors.New("publish held: the last check held nothing")
	}
	root := checkRoot(publicDir)
	base, err := publish.LoadManifest(filepath.Join(root, CheckBase))
	if err != nil {
		return site.Release{}, 0, err
	}
	checked, err := publish.LoadManifest(filepath.Join(root, CheckManifest))
	if err != nil {
		return site.Release{}, 0, err
	}
	if !base.Loaded() || !checked.Loaded() {
		return site.Release{}, 0, fmt.Errorf("publish held: no check at %s", root)
	}
	main, err := publish.LoadManifest(filepath.Join(dataDir, ManifestFile))
	if err != nil {
		return site.Release{}, 0, err
	}
	skipped, err := moveChecked(root, publicDir, base, checked, main)
	if err != nil {
		return site.Release{}, skipped, err
	}
	if err := main.Save(); err != nil {
		return site.Release{}, skipped, err
	}
	rel, err := st.Stage("memoria", main.Paths())
	if err != nil {
		return rel, skipped, err
	}
	main.Settle()
	if err := main.Save(); err != nil {
		return rel, skipped, fmt.Errorf("ready already points to %s, but the manifest was not saved: %w", rel.Release, err)
	}
	c.Held, c.Released, c.Skipped = nil, rel.Release, skipped
	data, err := json.MarshalIndent(c, "", " ")
	if err == nil {
		err = writeAtomic(filepath.Join(dataDir, ConsistencyFile), data)
	}
	if err != nil {
		return rel, skipped, fmt.Errorf("ready already points to %s, but the check record was not updated: %w", rel.Release, err)
	}
	return rel, skipped, os.RemoveAll(root)
}
