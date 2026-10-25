package datastore

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

const (
	FileName      = "fiscal.db"
	BackupPrefix  = "fiscal-"
	DefaultBackup = 14
)

type Store struct {
	db   *sql.DB
	path string
	now  func() time.Time
}

func dsn(path string) string {
	q := url.Values{}
	for _, p := range []string{"journal_mode(WAL)", "busy_timeout(10000)", "synchronous(NORMAL)", "foreign_keys(ON)", "temp_store(MEMORY)", "cache_size(-16000)"} {
		q.Add("_pragma", p)
	}
	return "file:" + path + "?" + q.Encode()
}

func Open(path string, now func() time.Time) (*Store, error) {
	if now == nil {
		now = time.Now
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, fmt.Errorf("store dir: %w", err)
	}
	db, err := sql.Open("sqlite", dsn(path))
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	db.SetConnMaxIdleTime(0)
	s := &Store{db: db, path: path, now: now}
	if err := s.migrate(context.Background()); err != nil {
		db.Close()
		return nil, err
	}
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		if _, err := os.Stat(p); err == nil {
			os.Chmod(p, 0o600)
		}
	}
	return s, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}

func (s *Store) Path() string {
	return s.path
}

func (s *Store) stamp() string {
	return s.now().UTC().Format(time.RFC3339)
}

func (s *Store) migrate(ctx context.Context) error {
	if _, err := s.db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)`); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	var current int
	if err := s.db.QueryRowContext(ctx, `SELECT COALESCE(MAX(version), 0) FROM schema_migrations`).Scan(&current); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	all := migrations()
	if current > len(all) {
		return fmt.Errorf("migrate: database schema %d is newer than this binary (%d)", current, len(all))
	}
	for i := current; i < len(all); i++ {
		err := s.tx(ctx, func(tx *sql.Tx) error {
			if _, err := tx.ExecContext(ctx, all[i]); err != nil {
				return err
			}
			_, err := tx.ExecContext(ctx, `INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)`, i+1, s.stamp())
			return err
		})
		if err != nil {
			return fmt.Errorf("migrate %d: %w", i+1, err)
		}
	}
	return nil
}

func (s *Store) tx(ctx context.Context, fn func(*sql.Tx) error) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		tx.Rollback()
		return err
	}
	return tx.Commit()
}

func (s *Store) Backup(ctx context.Context, dir, day string, keep int) (string, int64, error) {
	if keep <= 0 {
		keep = DefaultBackup
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", 0, err
	}
	target := filepath.Join(dir, BackupPrefix+day+".db")
	if info, err := os.Stat(target); err == nil {
		return target, info.Size(), pruneBackups(dir, keep)
	}
	tmp := filepath.Join(dir, "."+BackupPrefix+day+".db.tmp")
	os.Remove(tmp)
	if _, err := s.db.ExecContext(ctx, `VACUUM INTO ?`, tmp); err != nil {
		os.Remove(tmp)
		return "", 0, fmt.Errorf("backup: %w", err)
	}
	if err := os.Chmod(tmp, 0o600); err != nil {
		os.Remove(tmp)
		return "", 0, err
	}
	if err := os.Rename(tmp, target); err != nil {
		os.Remove(tmp)
		return "", 0, err
	}
	info, err := os.Stat(target)
	if err != nil {
		return "", 0, err
	}
	return target, info.Size(), pruneBackups(dir, keep)
}

func Backups(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var out []string
	for _, e := range entries {
		n := e.Name()
		if !e.IsDir() && strings.HasPrefix(n, BackupPrefix) && strings.HasSuffix(n, ".db") {
			out = append(out, n)
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(out)))
	return out, nil
}

func pruneBackups(dir string, keep int) error {
	names, err := Backups(dir)
	if err != nil {
		return err
	}
	for i, n := range names {
		if i < keep {
			continue
		}
		if err := os.Remove(filepath.Join(dir, n)); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	return nil
}

func Restore(ctx context.Context, backup, target string) error {
	db, err := sql.Open("sqlite", "file:"+backup+"?mode=ro")
	if err != nil {
		return err
	}
	var result string
	err = db.QueryRowContext(ctx, `PRAGMA integrity_check`).Scan(&result)
	db.Close()
	if err != nil {
		return fmt.Errorf("restore: %w", err)
	}
	if result != "ok" {
		return fmt.Errorf("restore: integrity check failed: %s", result)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
		return err
	}
	src, err := os.Open(backup)
	if err != nil {
		return err
	}
	defer src.Close()
	tmp, err := os.CreateTemp(filepath.Dir(target), ".restore-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name)
	if _, err := io.Copy(tmp, src); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	for _, p := range []string{target + "-wal", target + "-shm"} {
		if err := os.Remove(p); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	return os.Rename(name, target)
}
