package jobctl

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

var ErrNoCapacity = errors.New("the machine is busy")

type Capacity struct {
	MaxLoad      float64
	MinAvailable int64
	Wait         time.Duration
	Every        time.Duration
	LoadFile     string
	MemFile      string
}

type Reading struct {
	Load      float64
	Available int64
	Known     bool
}

func (c Capacity) files() (string, string) {
	load, mem := c.LoadFile, c.MemFile
	if load == "" {
		load = "/proc/loadavg"
	}
	if mem == "" {
		mem = "/proc/meminfo"
	}
	return load, mem
}

func (c Capacity) Read() Reading {
	loadFile, memFile := c.files()
	var r Reading
	if data, err := os.ReadFile(loadFile); err == nil {
		if f := strings.Fields(string(data)); len(f) > 0 {
			if v, err := strconv.ParseFloat(f[0], 64); err == nil {
				r.Load = v
				r.Known = true
			}
		}
	}
	f, err := os.Open(memFile)
	if err != nil {
		return r
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		name, rest, ok := strings.Cut(sc.Text(), ":")
		if !ok || name != "MemAvailable" {
			continue
		}
		fields := strings.Fields(rest)
		if len(fields) > 0 {
			if kb, err := strconv.ParseInt(fields[0], 10, 64); err == nil {
				r.Available = kb << 10
			}
		}
	}
	return r
}

func (c Capacity) ok(r Reading) bool {
	if !r.Known {
		return true
	}
	if c.MaxLoad > 0 && r.Load > c.MaxLoad {
		return false
	}
	return c.MinAvailable <= 0 || r.Available == 0 || r.Available >= c.MinAvailable
}

func (r Reading) String() string {
	return fmt.Sprintf("load=%.2f available=%dMiB", r.Load, r.Available>>20)
}

func (c Capacity) WaitFor(ctx context.Context) (Reading, error) {
	every := c.Every
	if every <= 0 {
		every = 30 * time.Second
	}
	deadline := time.Now().Add(c.Wait)
	for {
		r := c.Read()
		if c.ok(r) {
			return r, nil
		}
		if !time.Now().Before(deadline) {
			return r, fmt.Errorf("%w (%s)", ErrNoCapacity, r)
		}
		select {
		case <-ctx.Done():
			return r, ctx.Err()
		case <-time.After(every):
		}
	}
}
