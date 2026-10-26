package repercussion

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"strings"
	"time"

	"liveresults/internal/sources/fetch"
)

const (
	GDELTURL    = "https://api.gdeltproject.org/api/v2/doc/doc"
	GDELTName   = "GDELT Project (DOC 2.0)"
	GDELTSite   = "https://www.gdeltproject.org"
	NewsWindow  = "30d"
	NewsTTL     = 72 * time.Hour
	gdeltGap    = 6 * time.Second
	gdeltLimit  = 240
	maxQueryLen = 240
)

var ErrThrottled = errors.New("gdelt: rate limited")

type Getter interface {
	JSON(ctx context.Context, rawURL string, v any) error
}

type GDELT struct {
	Get   Getter
	Base  string
	Gap   time.Duration
	Limit int
	Sleep func(context.Context, time.Duration) error
	Now   func() time.Time

	calls int
	last  time.Time
}

type timeline struct {
	Timeline []struct {
		Series string `json:"series"`
		Data   []struct {
			Date  string  `json:"date"`
			Value float64 `json:"value"`
		} `json:"data"`
	} `json:"timeline"`
}

func (g *GDELT) now() time.Time {
	if g.Now != nil {
		return g.Now()
	}
	return time.Now()
}

func (g *GDELT) sleep(ctx context.Context, d time.Duration) error {
	if g.Sleep != nil {
		return g.Sleep(ctx, d)
	}
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}

func (g *GDELT) limit() int {
	if g.Limit > 0 {
		return g.Limit
	}
	return gdeltLimit
}

func (g *GDELT) Exhausted() bool {
	return g.calls >= g.limit()
}

func Phrase(s string) string {
	s = strings.Join(strings.Fields(strings.ReplaceAll(s, `"`, " ")), " ")
	if s == "" {
		return ""
	}
	q := `"` + s + `" sourcelang:portuguese`
	if len(q) > maxQueryLen {
		return ""
	}
	return q
}

func (g *GDELT) URL(query string) string {
	base := g.Base
	if base == "" {
		base = GDELTURL
	}
	v := url.Values{}
	v.Set("query", query)
	v.Set("mode", "timelinevolraw")
	v.Set("timespan", NewsWindow)
	v.Set("format", "json")
	return base + "?" + v.Encode()
}

func (g *GDELT) Count(ctx context.Context, query string) (int64, error) {
	if g.Exhausted() {
		return 0, ErrThrottled
	}
	gap := g.Gap
	if gap <= 0 {
		gap = gdeltGap
	}
	if !g.last.IsZero() {
		if d := gap - g.now().Sub(g.last); d > 0 {
			if err := g.sleep(ctx, d); err != nil {
				return 0, err
			}
		}
	}
	g.calls++
	var t timeline
	err := g.Get.JSON(ctx, g.URL(query), &t)
	g.last = g.now()
	if err != nil {
		var se *fetch.StatusError
		if errors.As(err, &se) && se.Status == http.StatusTooManyRequests {
			return 0, ErrThrottled
		}
		if strings.Contains(err.Error(), "decode ") {
			return 0, ErrThrottled
		}
		return 0, err
	}
	var sum float64
	for _, s := range t.Timeline {
		for _, d := range s.Data {
			sum += d.Value
		}
	}
	return int64(sum + 0.5), nil
}
