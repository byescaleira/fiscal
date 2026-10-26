//go:build unix

package jobctl

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"
)

func TestLockIsExclusiveAndReleasable(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ingest.lock")
	first, err := Acquire(context.Background(), path, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := Acquire(context.Background(), path, 0); !errors.Is(err, ErrBusy) {
		t.Fatalf("second lock = %v", err)
	}
	first.Release()
	again, err := Acquire(context.Background(), path, time.Second)
	if err != nil {
		t.Fatalf("after release = %v", err)
	}
	again.Release()
}
