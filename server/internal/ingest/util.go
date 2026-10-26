package ingest

import (
	"strconv"
	"strings"
	"sync"
)

func (in *Ingest) forEach(ids []int64, fn func(int64)) {
	forEachJob(in.cfg.Workers, len(ids), func(i int) { fn(ids[i]) })
}

func forEachJob(workers, n int, fn func(int)) {
	if workers <= 0 {
		workers = 1
	}
	jobs := make(chan int)
	var wg sync.WaitGroup
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				fn(i)
			}
		}()
	}
	for i := 0; i < n; i++ {
		jobs <- i
	}
	close(jobs)
	wg.Wait()
}

func yearRange(year int, today string) (string, string) {
	y := strconv.Itoa(year)
	to := y + "-12-31"
	if today < to {
		to = today
	}
	return y + "-01-01", to
}

func dateOnlyStr(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 10 {
		return s[:10]
	}
	return s
}

func dateOnly(s string) *string {
	d := dateOnlyStr(s)
	if d == "" {
		return nil
	}
	return &d
}

func clock(s string) string {
	i := strings.IndexByte(s, 'T')
	if i < 0 || len(s) < i+6 {
		return ""
	}
	return s[i+1 : i+6]
}

func digits(s string) string {
	return strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, s)
}

func cnpj(s string) *string {
	d := digits(s)
	if len(d) != 14 {
		return nil
	}
	return &d
}

func nilIfEmpty(s string) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	return &s
}

func ptrInt(v int) *int {
	return &v
}
