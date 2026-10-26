package ingest

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

const SyncStateFile = "sync-state.json"

type JobState struct {
	LastAttempt    time.Time `json:"lastAttempt"`
	LastOK         time.Time `json:"lastOk"`
	LastRun        time.Time `json:"lastRun"`
	Fingerprint    string    `json:"fingerprint,omitempty"`
	RunFingerprint string    `json:"runFingerprint,omitempty"`
	Pending        bool      `json:"pending,omitempty"`
	Result         string    `json:"result,omitempty"`
	Duration       string    `json:"duration,omitempty"`
	Changed        int       `json:"changed"`
	Release        string    `json:"release,omitempty"`
	Error          string    `json:"error,omitempty"`
}

type SyncState struct {
	Jobs map[string]JobState `json:"jobs"`
}

type Decision struct {
	Job   Job
	Due   bool
	Why   string
	State JobState
}

type SyncHooks struct {
	AfterSources func(ctx context.Context, job Job)
	BeforeHeavy  func(ctx context.Context, job Job) error
}

type Outcome struct {
	Job      string
	Ran      bool
	Result   string
	Changed  int
	Release  string
	Duration time.Duration
	Err      error
}

var ErrDivergence = errors.New("the incremental site diverged from the full rebuild")

func (in *Ingest) UseProbe(fn func(context.Context, Job) (string, error)) {
	in.probeFn = fn
}

func (in *Ingest) probe(ctx context.Context, j Job) (string, error) {
	if in.probeFn != nil {
		return in.probeFn(ctx, j)
	}
	return in.Probe(ctx, j)
}

func (in *Ingest) seedSyncState() error {
	if _, err := os.Stat(in.path(SyncStateFile)); !errors.Is(err, os.ErrNotExist) {
		return nil
	}
	now := in.now()
	st := SyncState{Jobs: map[string]JobState{}}
	for _, j := range Catalog {
		if j.Kind == JobHot || j.Kind == JobExternal || j.Kind == JobDerived {
			continue
		}
		st.Jobs[j.Name] = JobState{LastAttempt: now, LastOK: now, LastRun: now, Result: "assumido em dia na primeira execução do catálogo"}
	}
	return in.SaveSyncState(st)
}

func (in *Ingest) LoadSyncState() SyncState {
	st := SyncState{Jobs: map[string]JobState{}}
	if data, err := os.ReadFile(in.path(SyncStateFile)); err == nil {
		json.Unmarshal(data, &st)
	}
	if st.Jobs == nil {
		st.Jobs = map[string]JobState{}
	}
	return st
}

func (in *Ingest) SaveSyncState(st SyncState) error {
	data, err := json.MarshalIndent(st, "", " ")
	if err != nil {
		return err
	}
	return writeAtomic(in.path(SyncStateFile), data)
}

func (in *Ingest) Plan(now time.Time, st SyncState, force map[string]bool) []Decision {
	var out []Decision
	for _, j := range Catalog {
		js := st.Jobs[j.Name]
		due, why := j.Due(now, in.loc, js)
		if force[j.Name] && j.Kind != JobExternal {
			due, why = true, "forçado"
		}
		if j.Kind == JobExternal && IsElectionDay(now.In(in.loc)) {
			why = "dia de eleição: ligue o fiscal-pages.timer"
		}
		if j.Kind == JobSources && !in.jobEnabled(j) {
			due, why = false, "fonte desligada em INGEST_SOURCES"
		}
		out = append(out, Decision{Job: j, Due: due, Why: why, State: js})
	}
	return out
}

func (in *Ingest) jobEnabled(j Job) bool {
	for _, s := range j.Sources {
		if in.cfg.Enabled(s) {
			return true
		}
	}
	return false
}

func (in *Ingest) RunJob(ctx context.Context, name string, hooks SyncHooks) ([]Outcome, error) {
	j, ok := JobByName(name)
	if !ok || j.Kind == JobExternal {
		return nil, fmt.Errorf("unknown job %q", name)
	}
	if err := in.seedSyncState(); err != nil {
		return nil, err
	}
	return in.runJobs(ctx, []Job{j}, map[string]bool{name: true}, hooks)
}

func (in *Ingest) Sync(ctx context.Context, force map[string]bool, hooks SyncHooks) ([]Outcome, error) {
	if err := in.seedSyncState(); err != nil {
		return nil, err
	}
	var due []Job
	for _, d := range in.Plan(in.now(), in.LoadSyncState(), force) {
		if d.Due {
			due = append(due, d.Job)
		}
	}
	return in.runJobs(ctx, due, force, hooks)
}

func heavy(j Job) bool {
	return j.Kind == JobSources || j.Kind == JobRebuild || j.Kind == JobDerived
}

func (in *Ingest) runJobs(ctx context.Context, jobs []Job, force map[string]bool, hooks SyncHooks) ([]Outcome, error) {
	st := in.LoadSyncState()
	var outcomes []Outcome
	var divergence error
	for _, j := range jobs {
		if ctx.Err() != nil {
			break
		}
		if j.Kind == JobDerived && !force[j.Name] && !st.Jobs[j.Name].Pending {
			continue
		}
		if heavy(j) && hooks.BeforeHeavy != nil {
			if err := hooks.BeforeHeavy(ctx, j); err != nil {
				outcomes = append(outcomes, Outcome{Job: j.Name, Result: "adiado: " + err.Error()})
				continue
			}
		}
		o := in.runJob(ctx, j, force[j.Name], &st, hooks)
		outcomes = append(outcomes, o)
		if errors.Is(o.Err, ErrDivergence) {
			divergence = o.Err
		}
		if err := in.SaveSyncState(st); err != nil {
			return outcomes, err
		}
	}
	return outcomes, divergence
}

func (in *Ingest) withJob(j Job, fn func()) {
	saved := in.cfg
	defer func() { in.cfg = saved }()
	in.cfg.ReleaseKind = j.Name
	in.cfg.Rebuild = j.Kind == JobRebuild
	switch j.Kind {
	case JobSources:
		in.cfg.Refresh = map[string]bool{"none": true}
		for _, s := range j.Sources {
			in.cfg.Refresh[s] = true
		}
	case JobRebuild, JobDerived:
		in.cfg.Refresh = map[string]bool{"none": true}
	default:
		in.cfg.Refresh = nil
	}
	fn()
}

func (in *Ingest) runJob(ctx context.Context, j Job, forced bool, st *SyncState, hooks SyncHooks) Outcome {
	start := in.now()
	js := st.Jobs[j.Name]
	js.LastAttempt = start
	o := Outcome{Job: j.Name}
	finish := func() Outcome {
		o.Duration = in.now().Sub(start)
		js.Duration = o.Duration.Round(time.Second).String()
		js.Result, js.Changed, js.Release, js.Error = o.Result, o.Changed, o.Release, ""
		if o.Err != nil && !errors.Is(o.Err, ErrDivergence) {
			js.Error = o.Err.Error()
		} else {
			js.LastOK = in.now()
			if o.Ran {
				js.LastRun = in.now()
			}
		}
		st.Jobs[j.Name] = js
		return o
	}
	switch j.Kind {
	case JobHot:
		var rep HotReport
		var err error
		in.withJob(j, func() { rep, err = in.Hot(ctx) })
		if errors.Is(err, ErrNoHotBase) {
			o.Result = "sem base nacional ainda; espera a primeira fase"
			return finish()
		}
		o.Ran, o.Err, o.Changed, o.Release = rep.Changed, err, rep.Written, rep.Release
		switch {
		case err != nil:
			o.Result = "falhou"
		case !rep.Changed:
			o.Result = fmt.Sprintf("pauta e %d votações de hoje sem mudança", rep.Votes)
		default:
			o.Result = fmt.Sprintf("%d votações de hoje, %d arquivos regravados", rep.Votes, rep.Written)
		}
		if err == nil && rep.VotesChanged {
			d := st.Jobs["destaques"]
			d.Pending = true
			st.Jobs["destaques"] = d
		}
		return finish()
	case JobDerived:
		var rep Report
		var err error
		in.withJob(j, func() { rep, err = in.Derived(ctx) })
		o.Ran, o.Err, o.Changed, o.Release = true, err, rep.Changed, rep.Release
		o.Result = reportLine(rep, err)
		if err == nil || errors.Is(err, ErrNoSnapshot) {
			js.Pending = false
		}
		return finish()
	case JobRebuild:
		var err error
		var line string
		in.withJob(j, func() { line, err = in.Verify(ctx, hooks, j) })
		o.Ran, o.Err, o.Result = true, err, line
		in.clearPending(st)
		return finish()
	}
	fp := ""
	if j.Probe != ProbeNone && !forced {
		p, err := in.probe(ctx, j)
		switch {
		case err != nil:
			in.logger.Printf("sync %s: probe failed, running anyway: %v", j.Name, err)
		case p == js.RunFingerprint && !js.LastRun.IsZero() && (j.MaxAge == 0 || start.Sub(js.LastRun) < j.MaxAge):
			js.Fingerprint = p
			o.Result = "fonte sem mudança (sonda)"
			return finish()
		default:
			fp = p
			js.Fingerprint = p
		}
	}
	var rep Report
	var err error
	in.withJob(j, func() {
		if j.Overlay {
			rep, err = in.Overlay(ctx)
		}
		if !j.Overlay || errors.Is(err, ErrNoSnapshot) {
			rep, err = in.Full(ctx)
		}
		if err == nil && hooks.AfterSources != nil {
			hooks.AfterSources(ctx, j)
		}
	})
	o.Ran, o.Err, o.Changed, o.Release = true, err, rep.Changed, rep.Release
	o.Result = reportLine(rep, err)
	if err == nil {
		if fp != "" {
			js.RunFingerprint = fp
		}
		in.clearPending(st)
	}
	return finish()
}

func (in *Ingest) clearPending(st *SyncState) {
	d := st.Jobs["destaques"]
	d.Pending = false
	st.Jobs["destaques"] = d
}

func reportLine(rep Report, err error) string {
	if err != nil {
		return "falhou"
	}
	if rep.Unchanged || rep.Changed == 0 {
		return fmt.Sprintf("nada mudou (%d arquivos conferidos)", rep.Files)
	}
	return fmt.Sprintf("%d arquivos mudaram de %d, release %s", rep.Changed, rep.Files, rep.Release)
}

func (d Decision) String() string {
	mark := "-"
	if d.Due {
		mark = "▶"
	}
	last := "nunca"
	if !d.State.LastOK.IsZero() {
		last = d.State.LastOK.Format(time.RFC3339)
	}
	parts := []string{fmt.Sprintf("%s %-12s %s", mark, d.Job.Name, d.Why), "cadência: " + d.Job.Cadence(), "última ok: " + last}
	if d.State.Result != "" {
		parts = append(parts, "resultado: "+d.State.Result)
	}
	if d.State.Error != "" {
		parts = append(parts, "erro: "+d.State.Error)
	}
	if d.State.Pending {
		parts = append(parts, "votação nova na fila")
	}
	return strings.Join(parts, " | ")
}
