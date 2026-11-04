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

const ConsistencyFile = "consistency.json"

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
	rep, err := in.Full(ctx)
	if err != nil {
		return "reconstrução completa falhou", err
	}
	if hooks.AfterSources != nil {
		hooks.AfterSources(ctx, j)
	}
	var staging, refreshed []string
	for _, p := range rep.ChangedPaths {
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
	if len(staging)+len(siteDiff) > 0 {
		c.Held = heldPaths(staging, siteDiff)
	}
	if data, err := json.MarshalIndent(c, "", " "); err == nil {
		if err := writeAtomic(in.path(ConsistencyFile), data); err != nil {
			in.logger.Printf("verify: %v", err)
		}
	}
	line := fmt.Sprintf("reconstrução completa (%d arquivos, release %s); divergência do incremental: %d no preparo, %d no site", rep.Files, rep.Release, c.Staging, c.Site)
	if c.Staging+c.Site > 0 {
		in.logger.Printf("ALERT consistency: %s; amostra: %s", line, strings.Join(c.Sample, ", "))
		in.keepPublished(incremental.Release)
		return line, fmt.Errorf("%w: %d staging files and %d site files differ", ErrDivergence, c.Staging, c.Site)
	}
	return line, nil
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

func PublishStaging(dataDir string, st *site.Stager) (site.Release, error) {
	path := filepath.Join(dataDir, ManifestFile)
	m, err := publish.LoadManifest(path)
	if err != nil {
		return site.Release{}, err
	}
	if !m.Loaded() {
		return site.Release{}, fmt.Errorf("publish staging: no manifest at %s yet", path)
	}
	rel, err := st.Stage("memoria", m.Paths())
	if err != nil {
		return rel, err
	}
	m.Settle()
	if err := m.Save(); err != nil {
		return rel, err
	}
	c, ok, err := ReadConsistency(dataDir)
	if err != nil || !ok {
		return rel, err
	}
	c.Held, c.Released = nil, rel.Release
	data, err := json.MarshalIndent(c, "", " ")
	if err != nil {
		return rel, err
	}
	return rel, writeAtomic(filepath.Join(dataDir, ConsistencyFile), data)
}

func (in *Ingest) keepPublished(release string) {
	if in.site == nil || release == "" {
		return
	}
	if _, err := in.site.Rollback(release); err != nil {
		in.logger.Printf("ALERT consistency: could not keep %s published: %v", release, err)
		return
	}
	in.logger.Printf("consistency: kept %s published until the divergence is explained", release)
}
