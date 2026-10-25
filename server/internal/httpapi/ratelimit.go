package httpapi

import (
	"container/list"
	"net/http"
	"net/netip"
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
	key   string
	start time.Time
	count int
}

type RateLimiter struct {
	mu      sync.Mutex
	now     func() time.Time
	window  time.Duration
	limits  map[string]int
	max     int
	buckets map[string]*list.Element
	order   *list.List
}

func NewRateLimiter(now func() time.Time, readPerMinute, writePerMinute int) *RateLimiter {
	if now == nil {
		now = time.Now
	}
	return &RateLimiter{
		now:     now,
		window:  time.Minute,
		limits:  map[string]int{ClassRead: readPerMinute, ClassWrite: writePerMinute},
		max:     maxBuckets,
		buckets: map[string]*list.Element{},
		order:   list.New(),
	}
}

func (l *RateLimiter) drop(e *list.Element) {
	l.order.Remove(e)
	delete(l.buckets, e.Value.(*bucket).key)
}

func (l *RateLimiter) Allow(ip, class string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	for e := l.order.Front(); e != nil && now.Sub(e.Value.(*bucket).start) >= l.window; e = l.order.Front() {
		l.drop(e)
	}
	key := class + "|" + ip
	e, ok := l.buckets[key]
	if !ok {
		for l.order.Len() >= l.max {
			l.drop(l.order.Front())
		}
		e = l.order.PushBack(&bucket{key: key, start: now})
		l.buckets[key] = e
	}
	b := e.Value.(*bucket)
	if b.count >= l.limits[class] {
		return false
	}
	b.count++
	return true
}

func parseAddr(s string) netip.Addr {
	s = strings.TrimSpace(s)
	if ap, err := netip.ParseAddrPort(s); err == nil {
		return ap.Addr().Unmap().WithZone("")
	}
	if a, err := netip.ParseAddr(strings.TrimSuffix(strings.TrimPrefix(s, "["), "]")); err == nil {
		return a.Unmap().WithZone("")
	}
	return netip.Addr{}
}

func trustedProxy(a netip.Addr) bool {
	return a.IsLoopback() || a.IsPrivate()
}

func lastForwarded(r *http.Request) netip.Addr {
	parts := strings.Split(strings.Join(r.Header.Values("X-Forwarded-For"), ","), ",")
	for i := len(parts) - 1; i >= 0; i-- {
		if p := strings.TrimSpace(parts[i]); p != "" {
			return parseAddr(p)
		}
	}
	return netip.Addr{}
}

func clientKey(a netip.Addr) string {
	if a.Is6() {
		p, err := a.Prefix(64)
		if err == nil {
			return p.String()
		}
	}
	return a.String()
}

func ClientIP(r *http.Request) string {
	addr := parseAddr(r.RemoteAddr)
	if !addr.IsValid() {
		return r.RemoteAddr
	}
	if trustedProxy(addr) {
		if fwd := lastForwarded(r); fwd.IsValid() {
			addr = fwd
		}
	}
	return clientKey(addr)
}
