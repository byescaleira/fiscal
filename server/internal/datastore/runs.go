package datastore

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"
)

const (
	StatusRunning  = "running"
	StatusOK       = "ok"
	StatusFailed   = "failed"
	StatusFallback = "fallback"
	StatusSkipped  = "skipped"
)

type Run struct {
	s    *Store
	ID   int64
	Kind string
}

func (s *Store) BeginRun(ctx context.Context, kind string) (*Run, error) {
	res, err := s.db.ExecContext(ctx, `INSERT INTO sources_runs (kind, source, started_at, status) VALUES (?, 'all', ?, ?)`, kind, s.stamp(), StatusRunning)
	if err != nil {
		return nil, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return nil, err
	}
	if _, err := s.db.ExecContext(ctx, `UPDATE sources_runs SET run_id = id WHERE id = ?`, id); err != nil {
		return nil, err
	}
	return &Run{s: s, ID: id, Kind: kind}, nil
}

func encodeCounts(counts map[string]int) string {
	if len(counts) == 0 {
		return "{}"
	}
	data, err := json.Marshal(counts)
	if err != nil {
		return "{}"
	}
	return string(data)
}

func errText(err error) any {
	if err == nil {
		return nil
	}
	msg := err.Error()
	if len(msg) > 2000 {
		msg = msg[:2000]
	}
	return msg
}

func (r *Run) Finish(ctx context.Context, status string, counts map[string]int, err error) error {
	_, e := r.s.db.ExecContext(ctx, `UPDATE sources_runs SET finished_at = ?, status = ?, counts = ?, error = ? WHERE id = ?`, r.s.stamp(), status, encodeCounts(counts), errText(err), r.ID)
	return e
}

type SourceRun struct {
	run *Run
	ID  int64
}

func (r *Run) Source(ctx context.Context, source string) (*SourceRun, error) {
	res, err := r.s.db.ExecContext(ctx, `INSERT INTO sources_runs (run_id, kind, source, started_at, status) VALUES (?, ?, ?, ?, ?)`, r.ID, r.Kind, source, r.s.stamp(), StatusRunning)
	if err != nil {
		return nil, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return nil, err
	}
	return &SourceRun{run: r, ID: id}, nil
}

func (sr *SourceRun) Finish(ctx context.Context, status string, counts map[string]int, err error) error {
	_, e := sr.run.s.db.ExecContext(ctx, `UPDATE sources_runs SET finished_at = ?, status = ?, counts = ?, error = ? WHERE id = ?`, sr.run.s.stamp(), status, encodeCounts(counts), errText(err), sr.ID)
	return e
}

func (s *Store) Record(ctx context.Context, kind, source, status string, started time.Time, counts map[string]int, err error) error {
	_, e := s.db.ExecContext(ctx, `INSERT INTO sources_runs (kind, source, started_at, finished_at, status, counts, error) VALUES (?, ?, ?, ?, ?, ?, ?)`, kind, source, started.UTC().Format(time.RFC3339), s.stamp(), status, encodeCounts(counts), errText(err))
	return e
}

type RunStatus struct {
	StartedAt  string         `json:"startedAt"`
	FinishedAt *string        `json:"finishedAt"`
	Status     string         `json:"status"`
	Counts     map[string]int `json:"counts"`
}

type SourceStatus struct {
	ID     string    `json:"id"`
	Last   RunStatus `json:"last"`
	LastOK *string   `json:"lastOk"`
}

type StatusFile struct {
	GeneratedAt string         `json:"generatedAt"`
	Schema      int            `json:"schema"`
	Full        *RunStatus     `json:"full"`
	LastFullOK  *string        `json:"lastFullOk"`
	Live        *RunStatus     `json:"live"`
	Backup      *RunStatus     `json:"backup"`
	Sources     []SourceStatus `json:"sources"`
}

func scanRun(row interface{ Scan(...any) error }) (*RunStatus, error) {
	var r RunStatus
	var finished sql.NullString
	var counts string
	if err := row.Scan(&r.StartedAt, &finished, &r.Status, &counts); err != nil {
		return nil, err
	}
	if finished.Valid {
		r.FinishedAt = &finished.String
	}
	r.Counts = map[string]int{}
	json.Unmarshal([]byte(counts), &r.Counts)
	return &r, nil
}

func (s *Store) lastRun(ctx context.Context, kind, source string) (*RunStatus, error) {
	r, err := scanRun(s.db.QueryRowContext(ctx, `SELECT started_at, finished_at, status, counts FROM sources_runs WHERE kind = ? AND source = ? ORDER BY id DESC LIMIT 1`, kind, source))
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return r, err
}

func (s *Store) lastOK(ctx context.Context, kind, source string) (*string, error) {
	var at sql.NullString
	err := s.db.QueryRowContext(ctx, `SELECT finished_at FROM sources_runs WHERE kind = ? AND source = ? AND status = ? ORDER BY id DESC LIMIT 1`, kind, source, StatusOK).Scan(&at)
	if err == sql.ErrNoRows || !at.Valid {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &at.String, nil
}

func (s *Store) Status(ctx context.Context) (StatusFile, error) {
	out := StatusFile{GeneratedAt: s.stamp(), Schema: len(migrations()), Sources: []SourceStatus{}}
	var err error
	if out.Full, err = s.lastRun(ctx, "full", "all"); err != nil {
		return out, err
	}
	if out.LastFullOK, err = s.lastOK(ctx, "full", "all"); err != nil {
		return out, err
	}
	if out.Live, err = s.lastRun(ctx, "live", "all"); err != nil {
		return out, err
	}
	if out.Backup, err = s.lastRun(ctx, "backup", "backup"); err != nil {
		return out, err
	}
	rows, err := s.db.QueryContext(ctx, `SELECT DISTINCT source FROM sources_runs WHERE kind = 'full' AND source <> 'all' ORDER BY source`)
	if err != nil {
		return out, err
	}
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return out, err
		}
		ids = append(ids, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return out, err
	}
	for _, id := range ids {
		last, err := s.lastRun(ctx, "full", id)
		if err != nil {
			return out, err
		}
		if last == nil {
			continue
		}
		ok, err := s.lastOK(ctx, "full", id)
		if err != nil {
			return out, err
		}
		out.Sources = append(out.Sources, SourceStatus{ID: id, Last: *last, LastOK: ok})
	}
	return out, nil
}
