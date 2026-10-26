package jobctl

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCapacityWaitsThenGivesUp(t *testing.T) {
	dir := t.TempDir()
	load, mem := filepath.Join(dir, "loadavg"), filepath.Join(dir, "meminfo")
	os.WriteFile(load, []byte("3.50 2.10 1.00 3/900 12345\n"), 0o644)
	os.WriteFile(mem, []byte("MemTotal:        8130000 kB\nMemAvailable:    2097152 kB\n"), 0o644)
	c := Capacity{MaxLoad: 2, MinAvailable: 1536 << 20, Wait: 30 * time.Millisecond, Every: 10 * time.Millisecond, LoadFile: load, MemFile: mem}
	r, err := c.WaitFor(context.Background())
	if !errors.Is(err, ErrNoCapacity) || r.Load != 3.5 || r.Available != 2<<30 {
		t.Fatalf("busy = %+v %v", r, err)
	}
	os.WriteFile(load, []byte("0.80 1.00 1.00 1/900 12345\n"), 0o644)
	if _, err := c.WaitFor(context.Background()); err != nil {
		t.Fatalf("idle = %v", err)
	}
	os.WriteFile(mem, []byte("MemAvailable:    1048576 kB\n"), 0o644)
	if _, err := c.WaitFor(context.Background()); !errors.Is(err, ErrNoCapacity) {
		t.Fatalf("low memory = %v", err)
	}
	unknown := Capacity{MaxLoad: 0.1, LoadFile: filepath.Join(dir, "missing"), MemFile: filepath.Join(dir, "missing")}
	if _, err := unknown.WaitFor(context.Background()); err != nil {
		t.Fatalf("without /proc the job runs: %v", err)
	}
}
