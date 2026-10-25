package httpapi

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	ClassRead  = "read"
	ClassWrite = "write"
	maxBuckets = 100000
)

type bucket struct {
	start time.Time
	count int
}

type RateLimiter struct {
	mu        sync.Mutex
	now       func() time.Time
	window    time.Duration
	limits    map[string]int
	buckets   map[string]*bucket
	lastSweep time.Time
}

func NewRateLimiter(now func() time.Time, readPerMinute, writePerMinute int) *RateLimiter {
	if now == nil {
		now = time.Now
	}
	return &RateLimiter{
		now:     now,
		window:  time.Minute,
		limits:  map[string]int{ClassRead: readPerMinute, ClassWrite: writePerMinute},
		buckets: map[string]*bucket{},
	}
}

func (l *RateLimiter) Allow(ip, class string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	if now.Sub(l.lastSweep) >= l.window {
		for k, b := range l.buckets {
			if now.Sub(b.start) >= l.window {
				delete(l.buckets, k)
			}
		}
		l.lastSweep = now
	}
	key := class + "|" + ip
	b, ok := l.buckets[key]
	if !ok || now.Sub(b.start) >= l.window {
		if !ok && len(l.buckets) >= maxBuckets {
			return false
		}
		b = &bucket{start: now}
		l.buckets[key] = b
	}
	if b.count >= l.limits[class] {
		return false
	}
	b.count++
	return true
}

func ClientIP(r *http.Request) string {
	if xff := r.Header.Values("X-Forwarded-For"); len(xff) > 0 {
		parts := strings.Split(strings.Join(xff, ","), ",")
		for i := len(parts) - 1; i >= 0; i-- {
			if p := strings.TrimSpace(parts[i]); p != "" {
				return p
			}
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
