package fetch

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type cacheMeta struct {
	URL          string `json:"url"`
	ETag         string `json:"etag,omitempty"`
	LastModified string `json:"lastModified,omitempty"`
	FetchedAt    string `json:"fetchedAt,omitempty"`
	Size         int64  `json:"size,omitempty"`
}

type Cached struct {
	Path    string
	Changed bool
	ETag    string
}

type cacheFiles struct {
	path     string
	meta     string
	part     string
	partMeta string
}

type attempt struct {
	result Cached
	final  bool
	err    error
}

func (c *Client) Cache(ctx context.Context, rawURL string, limit int64) (Cached, error) {
	if c.CacheDir == "" {
		return Cached{}, errors.New("fetch: no cache directory")
	}
	if err := os.MkdirAll(c.CacheDir, 0o700); err != nil {
		return Cached{}, err
	}
	sum := sha256.Sum256([]byte(rawURL))
	key := hex.EncodeToString(sum[:12])
	files := cacheFiles{
		path:     filepath.Join(c.CacheDir, key+".bin"),
		meta:     filepath.Join(c.CacheDir, key+".meta.json"),
		part:     filepath.Join(c.CacheDir, key+".part"),
		partMeta: filepath.Join(c.CacheDir, key+".part.json"),
	}
	attempts := c.CacheAttempts
	if attempts <= 0 {
		attempts = 1
	}
	var last error
	for i := range attempts {
		if i > 0 {
			if err := c.sleep(ctx, min(backoff(i+1), maxRetryWait)); err != nil {
				return Cached{}, err
			}
		}
		a := c.cacheAttempt(ctx, rawURL, limit, files)
		if a.final {
			return a.result, a.err
		}
		last = a.err
		if ctx.Err() != nil {
			return Cached{}, ctx.Err()
		}
	}
	return Cached{}, fmt.Errorf("GET %s: gave up after %d attempts: %w", rawURL, attempts, last)
}

func readMeta(path string) cacheMeta {
	var m cacheMeta
	if data, err := os.ReadFile(path); err == nil {
		json.Unmarshal(data, &m)
	}
	return m
}

func writeMeta(path string, m cacheMeta) error {
	data, err := json.Marshal(m)
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o600)
}

func validator(m cacheMeta) string {
	if strings.HasPrefix(m.ETag, "\"") {
		return m.ETag
	}
	return m.LastModified
}

func (c *Client) streamClient() *http.Client {
	hc := *c.HTTP
	hc.Timeout = 0
	return &hc
}

func (c *Client) cacheAttempt(ctx context.Context, rawURL string, limit int64, f cacheFiles) attempt {
	meta := readMeta(f.meta)
	part := readMeta(f.partMeta)
	var have int64
	if info, err := os.Stat(f.part); err == nil && part.URL == rawURL && validator(part) != "" {
		have = info.Size()
	}
	h := http.Header{}
	if have > 0 {
		h.Set("Range", "bytes="+strconv.FormatInt(have, 10)+"-")
		h.Set("If-Range", validator(part))
	} else if _, err := os.Stat(f.path); err == nil {
		if meta.ETag != "" {
			h.Set("If-None-Match", meta.ETag)
		}
		if meta.LastModified != "" {
			h.Set("If-Modified-Since", meta.LastModified)
		}
	}
	actx, cancel := context.WithCancel(ctx)
	defer cancel()
	stall := c.Stall
	if stall <= 0 {
		stall = defaultStall
	}
	watchdog := time.AfterFunc(stall, cancel)
	defer watchdog.Stop()
	resp, err := c.do(actx, c.streamClient(), http.MethodGet, rawURL, h)
	if err != nil {
		if ctx.Err() != nil {
			return attempt{final: true, err: ctx.Err()}
		}
		return attempt{err: err}
	}
	defer resp.Body.Close()
	watchdog.Reset(stall)
	var file *os.File
	switch resp.StatusCode {
	case http.StatusNotModified:
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return attempt{final: true, result: Cached{Path: f.path, ETag: meta.ETag}}
	case http.StatusRequestedRangeNotSatisfiable:
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		if part.Size > 0 && have == part.Size {
			return finishPart(f, part)
		}
		os.Remove(f.part)
		return attempt{err: fmt.Errorf("GET %s: range %d- not satisfiable", rawURL, have)}
	case http.StatusPartialContent:
		start, total, ok := contentRange(resp.Header.Get("Content-Range"))
		if !ok || start != have {
			io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
			os.Remove(f.part)
			return attempt{err: fmt.Errorf("GET %s: unexpected content range %q", rawURL, resp.Header.Get("Content-Range"))}
		}
		if total > 0 {
			part.Size = total
		}
		file, err = os.OpenFile(f.part, os.O_WRONLY|os.O_APPEND, 0o600)
	case http.StatusOK:
		have = 0
		part = cacheMeta{URL: rawURL, ETag: resp.Header.Get("ETag"), LastModified: resp.Header.Get("Last-Modified")}
		if resp.ContentLength > 0 {
			part.Size = resp.ContentLength
		}
		if err := writeMeta(f.partMeta, part); err != nil {
			return attempt{final: true, err: err}
		}
		file, err = os.OpenFile(f.part, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	default:
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return attempt{final: true, err: &StatusError{URL: rawURL, Status: resp.StatusCode}}
	}
	if err != nil {
		return attempt{final: true, err: err}
	}
	if part.Size > limit {
		file.Close()
		os.Remove(f.part)
		return attempt{final: true, err: fmt.Errorf("GET %s: file larger than %d bytes", rawURL, limit)}
	}
	body := &progressReader{r: io.LimitReader(resp.Body, limit+1-have), tick: func() { watchdog.Reset(stall) }}
	n, cerr := io.Copy(file, body)
	if err := file.Close(); cerr == nil {
		cerr = err
	}
	got := have + n
	if got > limit {
		os.Remove(f.part)
		return attempt{final: true, err: fmt.Errorf("GET %s: file larger than %d bytes", rawURL, limit)}
	}
	if cerr != nil {
		if ctx.Err() != nil {
			return attempt{final: true, err: ctx.Err()}
		}
		return attempt{err: fmt.Errorf("GET %s: interrupted at %d bytes: %w", rawURL, got, cerr)}
	}
	if part.Size > 0 && got < part.Size {
		return attempt{err: fmt.Errorf("GET %s: stopped at %d of %d bytes", rawURL, got, part.Size)}
	}
	part.Size = got
	return finishPart(f, part)
}

func finishPart(f cacheFiles, part cacheMeta) attempt {
	if err := os.Chmod(f.part, 0o600); err != nil {
		return attempt{final: true, err: err}
	}
	if err := os.Rename(f.part, f.path); err != nil {
		return attempt{final: true, err: err}
	}
	os.Remove(f.partMeta)
	part.FetchedAt = time.Now().UTC().Format(time.RFC3339)
	if err := writeMeta(f.meta, part); err != nil {
		return attempt{final: true, err: err}
	}
	return attempt{final: true, result: Cached{Path: f.path, Changed: true, ETag: part.ETag}}
}

func contentRange(v string) (int64, int64, bool) {
	v, ok := strings.CutPrefix(strings.TrimSpace(v), "bytes ")
	if !ok {
		return 0, 0, false
	}
	span, size, ok := strings.Cut(v, "/")
	if !ok {
		return 0, 0, false
	}
	first, _, ok := strings.Cut(span, "-")
	if !ok {
		return 0, 0, false
	}
	start, err := strconv.ParseInt(first, 10, 64)
	if err != nil {
		return 0, 0, false
	}
	total, err := strconv.ParseInt(size, 10, 64)
	if err != nil {
		total = 0
	}
	return start, total, true
}

type progressReader struct {
	r    io.Reader
	tick func()
}

func (p *progressReader) Read(b []byte) (int, error) {
	n, err := p.r.Read(b)
	if n > 0 {
		p.tick()
	}
	return n, err
}
