package datastore

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
)

type Counts struct {
	Inserted  int `json:"inserted"`
	Changed   int `json:"changed"`
	Unchanged int `json:"unchanged"`
	Closed    int `json:"closed"`
}

func (c Counts) Add(o Counts) Counts {
	return Counts{Inserted: c.Inserted + o.Inserted, Changed: c.Changed + o.Changed, Unchanged: c.Unchanged + o.Unchanged, Closed: c.Closed + o.Closed}
}

func (c Counts) Map() map[string]int {
	return map[string]int{"inserted": c.Inserted, "changed": c.Changed, "unchanged": c.Unchanged, "closed": c.Closed}
}

type writer struct {
	ctx    context.Context
	tx     *sql.Tx
	t      table
	source string
	run    int64
	at     string
	touch  *sql.Stmt
	end    *sql.Stmt
	ins    *sql.Stmt
	counts Counts
}

func newWriter(ctx context.Context, tx *sql.Tx, t table, source string, run int64, at string) (*writer, error) {
	w := &writer{ctx: ctx, tx: tx, t: t, source: source, run: run, at: at}
	var err error
	set := "seen_run = ?"
	if t.stamp != "" {
		set += ", " + t.stamp + " = ?"
	}
	if w.touch, err = tx.PrepareContext(ctx, fmt.Sprintf(`UPDATE %s SET %s WHERE source = ? AND "key" = ? AND valid_to IS NULL AND hash = ?`, t.name, set)); err != nil {
		return nil, err
	}
	if w.end, err = tx.PrepareContext(ctx, fmt.Sprintf(`UPDATE %s SET valid_to = ? WHERE source = ? AND "key" = ? AND valid_to IS NULL`, t.name)); err != nil {
		return nil, err
	}
	cols := append([]string{"source", `"key"`}, t.columns...)
	cols = append(cols, "hash", "payload", "valid_from", "first_run", "seen_run")
	marks := strings.TrimSuffix(strings.Repeat("?, ", len(cols)), ", ")
	if w.ins, err = tx.PrepareContext(ctx, fmt.Sprintf(`INSERT INTO %s (%s) VALUES (%s)`, t.name, strings.Join(cols, ", "), marks)); err != nil {
		return nil, err
	}
	return w, nil
}

func (w *writer) close() {
	for _, st := range []*sql.Stmt{w.touch, w.end, w.ins} {
		if st != nil {
			st.Close()
		}
	}
}

func digest(payload []byte, cols []any) string {
	h := sha256.New()
	h.Write(payload)
	for _, c := range cols {
		fmt.Fprintf(h, "\x00%v", c)
	}
	return hex.EncodeToString(h.Sum(nil)[:16])
}

func (w *writer) put(key string, cols []any, value any) error {
	if len(cols) != len(w.t.columns) {
		return fmt.Errorf("%s: %d columns, want %d", w.t.name, len(cols), len(w.t.columns))
	}
	payload, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("%s %s: %w", w.t.name, key, err)
	}
	hashed := cols
	touch := []any{w.run}
	if w.t.stamp != "" {
		hashed = nil
		for i, c := range w.t.columns {
			if c != w.t.stamp {
				hashed = append(hashed, cols[i])
			}
		}
		touch = append(touch, w.at)
	}
	hash := digest(payload, hashed)
	res, err := w.touch.ExecContext(w.ctx, append(touch, w.source, key, hash)...)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n > 0 {
		w.counts.Unchanged++
		return nil
	}
	res, err = w.end.ExecContext(w.ctx, w.at, w.source, key)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n > 0 {
		w.counts.Changed++
	} else {
		w.counts.Inserted++
	}
	args := append([]any{w.source, key}, cols...)
	args = append(args, hash, string(payload), w.at, w.run, w.run)
	_, err = w.ins.ExecContext(w.ctx, args...)
	return err
}

func (w *writer) closeMissing(prefix string) error {
	q := fmt.Sprintf(`UPDATE %s SET valid_to = ? WHERE source = ? AND valid_to IS NULL AND seen_run <> ?`, w.t.name)
	args := []any{w.at, w.source, w.run}
	if prefix != "" {
		q += ` AND substr("key", 1, ?) = ?`
		args = append(args, len(prefix), prefix)
	}
	res, err := w.tx.ExecContext(w.ctx, q, args...)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	w.counts.Closed += int(n)
	return nil
}

type batch struct {
	s       *Store
	ctx     context.Context
	tx      *sql.Tx
	run     int64
	at      string
	writers map[string]*writer
}

func (s *Store) batch(ctx context.Context, run int64, fn func(b *batch) error) (Counts, error) {
	var total Counts
	err := s.tx(ctx, func(tx *sql.Tx) error {
		b := &batch{s: s, ctx: ctx, tx: tx, run: run, at: s.stamp(), writers: map[string]*writer{}}
		defer func() {
			for _, w := range b.writers {
				w.close()
			}
		}()
		if err := fn(b); err != nil {
			return err
		}
		for _, w := range b.writers {
			total = total.Add(w.counts)
		}
		return nil
	})
	return total, err
}

func (b *batch) w(t table, source string) (*writer, error) {
	id := t.name + "\x00" + source
	if w, ok := b.writers[id]; ok {
		return w, nil
	}
	w, err := newWriter(b.ctx, b.tx, t, source, b.run, b.at)
	if err != nil {
		return nil, err
	}
	b.writers[id] = w
	return w, nil
}

func (b *batch) put(t table, source, key string, cols []any, value any) error {
	w, err := b.w(t, source)
	if err != nil {
		return err
	}
	return w.put(key, cols, value)
}

func (b *batch) closeMissing(t table, source, prefix string) error {
	w, err := b.w(t, source)
	if err != nil {
		return err
	}
	return w.closeMissing(prefix)
}

func (s *Store) current(ctx context.Context, t table, source, prefix string, fn func(key string, payload []byte) error) error {
	q := fmt.Sprintf(`SELECT "key", payload FROM %s WHERE source = ? AND valid_to IS NULL`, t.name)
	args := []any{source}
	if prefix != "" {
		q += ` AND substr("key", 1, ?) = ?`
		args = append(args, len(prefix), prefix)
	}
	q += ` ORDER BY id`
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var key string
		var payload []byte
		if err := rows.Scan(&key, &payload); err != nil {
			return err
		}
		if err := fn(key, payload); err != nil {
			return err
		}
	}
	return rows.Err()
}

func (s *Store) has(ctx context.Context, t table, source, prefix string) (bool, error) {
	q := fmt.Sprintf(`SELECT 1 FROM %s WHERE source = ? AND valid_to IS NULL`, t.name)
	args := []any{source}
	if prefix != "" {
		q += ` AND substr("key", 1, ?) = ?`
		args = append(args, len(prefix), prefix)
	}
	var one int
	err := s.db.QueryRowContext(ctx, q+` LIMIT 1`, args...).Scan(&one)
	if err == sql.ErrNoRows {
		return false, nil
	}
	return err == nil, err
}
