package ingest

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/gob"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/publish"
	"liveresults/internal/site"
)

const (
	HotBaseFile  = "hot-base.gob"
	HotStateFile = "hot-today.json"
	ManifestFile = "v1-manifest.json"
	CityPaths    = "city-paths.json"
)

var ErrNoHotBase = errors.New("no national build yet for the hot update")

type HotState struct {
	Date        string                      `json:"date"`
	Fingerprint string                      `json:"fingerprint"`
	Agenda      []publicdata.RawAgendaHouse `json:"agenda"`
	Votes       []*publicdata.HouseVote     `json:"votes"`
	VoteHashes  map[string]string           `json:"voteHashes"`
	Carry       []*publicdata.HouseVote     `json:"carry"`
}

const carryDays = 7

func (st HotState) merge(ds *publicdata.Dataset) {
	ds.Votes = upsertVotes(ds.Votes, st.Carry)
	if st.Date == ds.Today {
		ds.Agenda = st.Agenda
		ds.Votes = upsertVotes(ds.Votes, st.Votes)
	}
}

func (in *Ingest) carry(prev HotState, today string) []*publicdata.HouseVote {
	all := prev.Carry
	if prev.Date != today {
		all = upsertVotes(append([]*publicdata.HouseVote(nil), all...), prev.Votes)
	}
	t, err := time.ParseInLocation("2006-01-02", today, in.loc)
	if err != nil {
		return all
	}
	since := t.AddDate(0, 0, -carryDays).Format("2006-01-02")
	var out []*publicdata.HouseVote
	for _, v := range all {
		if v.Date >= since && v.Date < today {
			out = append(out, v)
		}
	}
	return out
}

type HotReport struct {
	Changed      bool
	VotesChanged bool
	Votes        int
	Written      int
	Release      string
	Warnings     []string
}

func (in *Ingest) path(name string) string {
	return filepath.Join(in.cfg.DataDir, name)
}

func writeAtomic(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (in *Ingest) saveHotBase(base publicdata.HotBase) error {
	f, err := os.CreateTemp(in.cfg.DataDir, ".hot-base-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	w := bufio.NewWriter(f)
	if err := gob.NewEncoder(w).Encode(base); err != nil {
		f.Close()
		return err
	}
	if err := w.Flush(); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), in.path(HotBaseFile))
}

func (in *Ingest) loadHotBase() (publicdata.HotBase, error) {
	var base publicdata.HotBase
	f, err := os.Open(in.path(HotBaseFile))
	if errors.Is(err, os.ErrNotExist) {
		return base, ErrNoHotBase
	}
	if err != nil {
		return base, err
	}
	defer f.Close()
	if err := gob.NewDecoder(bufio.NewReader(f)).Decode(&base); err != nil || base.Version != publicdata.HotBaseVersion {
		return base, ErrNoHotBase
	}
	return base, nil
}

func (in *Ingest) loadHotState() HotState {
	var st HotState
	if data, err := os.ReadFile(in.path(HotStateFile)); err == nil {
		json.Unmarshal(data, &st)
	}
	return st
}

func (in *Ingest) saveHotState(st HotState) error {
	data, err := json.Marshal(st)
	if err != nil {
		return err
	}
	return writeAtomic(in.path(HotStateFile), data)
}

func hashJSON(v any) string {
	sum := sha256.New()
	json.NewEncoder(sum).Encode(v)
	return hex.EncodeToString(sum.Sum(nil))
}

func (in *Ingest) manifest() (*publish.Manifest, error) {
	if in.man != nil {
		return in.man, nil
	}
	m, err := publish.LoadManifest(in.path(ManifestFile))
	if err != nil {
		return nil, err
	}
	if !m.Loaded() {
		dirs := append(append([]string{}, publicdata.ManagedDirs...), "history")
		top := func(name string) bool { return name != "races.json" && name != "status.json" }
		if err := m.Seed(filepath.Join(in.cfg.PublicDir, "v1"), dirs, top); err != nil {
			return nil, fmt.Errorf("manifest: %w", err)
		}
	}
	in.man = m
	return m, nil
}

func (in *Ingest) loadCityPaths() ([]string, bool) {
	data, err := os.ReadFile(in.path(CityPaths))
	if err != nil {
		return nil, false
	}
	var out []string
	if json.Unmarshal(data, &out) != nil || len(out) == 0 {
		return nil, false
	}
	return out, true
}

func (in *Ingest) saveCityPaths(paths []string) error {
	data, err := json.Marshal(paths)
	if err != nil {
		return err
	}
	return writeAtomic(in.path(CityPaths), data)
}

func (in *Ingest) stage(kind string, m *publish.Manifest, rep *Report) error {
	if in.site == nil {
		return nil
	}
	changed := m.Changed()
	cur, ok, err := in.site.Current()
	if err != nil {
		return fmt.Errorf("site: %w", err)
	}
	if ok && len(changed) == 0 && !m.Seeded() {
		rep.Release, rep.Unchanged = cur.Release, true
		return nil
	}
	var r site.Release
	if in.cfg.Rebuild || !ok || m.Seeded() {
		r, err = in.site.Stage(kind, m.Paths())
	} else {
		r, err = in.site.StageDelta(kind, m.Paths(), changed)
	}
	if err != nil {
		return fmt.Errorf("site: %w", err)
	}
	rep.Release = r.Release
	m.Settle()
	return m.Save()
}

func voteHashes(votes []*publicdata.HouseVote) map[string]string {
	out := make(map[string]string, len(votes))
	for _, v := range votes {
		out[v.ID] = hashJSON(v)
	}
	return out
}

func (in *Ingest) Hot(ctx context.Context) (HotReport, error) {
	var out HotReport
	base, err := in.loadHotBase()
	if err != nil {
		return out, err
	}
	prev := in.loadHotState()
	today := in.today()
	ds := &publicdata.Dataset{GeneratedAt: in.now(), Today: today}
	if prev.Date == today {
		ds.Agenda = prev.Agenda
	}
	var rep Report
	in.refreshLive(ctx, ds, &rep)
	out.Warnings = rep.Warnings
	sort.SliceStable(ds.Votes, func(i, j int) bool { return ds.Votes[i].ID < ds.Votes[j].ID })
	if prev.Date == today && len(ds.Votes) == 0 && len(prev.Votes) > 0 && len(rep.Warnings) > 0 {
		ds.Votes = prev.Votes
	}
	hashes := voteHashes(ds.Votes)
	fp := hashJSON([]any{today, ds.Agenda, hashes, ds.Races})
	out.Votes = len(ds.Votes)
	if prev.Date == today && prev.Fingerprint == fp {
		return out, nil
	}
	out.Changed = true
	for id, h := range hashes {
		if prev.Date != today || prev.VoteHashes[id] != h {
			out.VotesChanged = true
		}
	}
	files := publicdata.BuildHot(publicdata.HotInput{Base: base, GeneratedAt: ds.GeneratedAt, Today: today, Agenda: ds.Agenda, Votes: ds.Votes, Races: ds.Races})
	m, err := in.manifest()
	if err != nil {
		return out, err
	}
	tree := publish.NewTree(filepath.Join(in.cfg.PublicDir, "v1"))
	tree.UseManifest(m)
	if err := publicdata.Publish(publicdata.Output{Files: files}, tree, false); err != nil {
		return out, err
	}
	out.Written = tree.Stats().Written
	if err := m.Save(); err != nil {
		return out, err
	}
	in.begin(ctx, "live")
	in.storeLive(ctx, &rep, ds)
	err = in.stage("hot", m, &rep)
	in.end(ctx, Report{Votes: len(ds.Votes), Written: out.Written, Warnings: rep.Warnings}, err)
	if err != nil {
		return out, err
	}
	out.Release = rep.Release
	if err := in.saveHotState(HotState{Date: today, Fingerprint: fp, Agenda: ds.Agenda, Votes: ds.Votes, VoteHashes: hashes, Carry: in.carry(prev, today)}); err != nil {
		return out, err
	}
	return out, nil
}

func (in *Ingest) Derived(ctx context.Context) (Report, error) {
	in.begin(ctx, "live")
	rep, err := in.derived(ctx)
	in.end(ctx, rep, err)
	return rep, err
}

func (in *Ingest) derived(ctx context.Context) (Report, error) {
	start := in.now()
	var rep Report
	in.mu.Lock()
	loaded := in.dataset != nil
	in.mu.Unlock()
	if !loaded {
		if err := in.LoadSnapshot(); err != nil {
			return rep, err
		}
	}
	in.mu.Lock()
	ds := in.dataset
	cities := in.cities
	in.mu.Unlock()
	ds.GeneratedAt = in.now()
	ds.Today = in.today()
	ds.Agenda = in.storedAgenda(ctx, ds.Today)
	in.loadHotState().merge(ds)
	ds.Races = in.races()
	if paths, ok := in.loadCityPaths(); ok {
		cities = paths
	}
	kind := in.cfg.ReleaseKind
	if kind == "" {
		kind = "destaques"
	}
	_, _, err := in.publish(ctx, kind, ds, &rep, cities)
	rep.Duration = in.now().Sub(start)
	return rep, err
}
