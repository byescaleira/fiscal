package fetch

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"time"
)

const (
	UserAgent      = "fiscal-ingest/1.0 (+https://fiscal.byescaleira.com)"
	maxJSONBytes   = 64 << 20
	maxRetryWait   = 60 * time.Second
	defaultRetries = 3

	defaultStall         = 90 * time.Second
	defaultCacheAttempts = 10
)

type StatusError struct {
	URL    string
	Status int
}

func (e *StatusError) Error() string {
	return fmt.Sprintf("GET %s: status %d", e.URL, e.Status)
}

func IsNotFound(err error) bool {
	var se *StatusError
	return errors.As(err, &se) && se.Status == http.StatusNotFound
}

type Client struct {
	HTTP     *http.Client
	CacheDir string
	Gap      time.Duration
	Retries  int
	Sleep    func(context.Context, time.Duration) error

	Stall         time.Duration
	CacheAttempts int

	mu    sync.Mutex
	gates map[string]*gate
}

type gate struct {
	mu   sync.Mutex
	next time.Time
}

func New(cacheDir string, timeout time.Duration) *Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.ForceAttemptHTTP2 = false
	transport.TLSNextProto = map[string]func(string, *tls.Conn) http.RoundTripper{}
	transport.TLSClientConfig = &tls.Config{MinVersion: tls.VersionTLS12, NextProtos: []string{"http/1.1"}}
	transport.MaxIdleConnsPerHost = 8
	transport.ResponseHeaderTimeout = timeout
	return &Client{
		HTTP:          &http.Client{Timeout: timeout, Transport: transport},
		CacheDir:      cacheDir,
		Gap:           120 * time.Millisecond,
		Retries:       defaultRetries,
		Stall:         defaultStall,
		CacheAttempts: defaultCacheAttempts,
	}
}

func (c *Client) sleep(ctx context.Context, d time.Duration) error {
	if c.Sleep != nil {
		return c.Sleep(ctx, d)
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

func (c *Client) wait(ctx context.Context, host string) error {
	if c.Gap <= 0 {
		return nil
	}
	c.mu.Lock()
	if c.gates == nil {
		c.gates = map[string]*gate{}
	}
	g := c.gates[host]
	if g == nil {
		g = &gate{}
		c.gates[host] = g
	}
	c.mu.Unlock()
	g.mu.Lock()
	now := time.Now()
	start := g.next
	if start.Before(now) {
		start = now
	}
	g.next = start.Add(c.Gap)
	g.mu.Unlock()
	if d := time.Until(start); d > 0 {
		return c.sleep(ctx, d)
	}
	return nil
}

func (c *Client) Do(ctx context.Context, method, rawURL string, header http.Header) (*http.Response, error) {
	return c.do(ctx, c.HTTP, method, rawURL, header)
}

func (c *Client) do(ctx context.Context, hc *http.Client, method, rawURL string, header http.Header) (*http.Response, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return nil, err
	}
	if u.Scheme != "https" && u.Scheme != "http" {
		return nil, fmt.Errorf("fetch: unsupported scheme in %s", rawURL)
	}
	retries := c.Retries
	if retries <= 0 {
		retries = 1
	}
	var last error
	for attempt := 0; attempt < retries; attempt++ {
		if err := c.wait(ctx, u.Host); err != nil {
			return nil, err
		}
		req, err := http.NewRequestWithContext(ctx, method, rawURL, nil)
		if err != nil {
			return nil, err
		}
		for k, vs := range header {
			for _, v := range vs {
				req.Header.Add(k, v)
			}
		}
		req.Header.Set("User-Agent", UserAgent)
		resp, err := hc.Do(req)
		if err != nil {
			last = err
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			if err := c.sleep(ctx, backoff(attempt)); err != nil {
				return nil, err
			}
			continue
		}
		if resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500 {
			wait := retryAfter(resp.Header.Get("Retry-After"), backoff(attempt))
			io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
			resp.Body.Close()
			last = &StatusError{URL: rawURL, Status: resp.StatusCode}
			if attempt+1 < retries {
				if err := c.sleep(ctx, wait); err != nil {
					return nil, err
				}
			}
			continue
		}
		return resp, nil
	}
	return nil, last
}

func backoff(attempt int) time.Duration {
	return time.Duration(1<<attempt) * time.Second
}

func retryAfter(v string, fallback time.Duration) time.Duration {
	if n, err := strconv.Atoi(v); err == nil && n >= 0 {
		d := time.Duration(n) * time.Second
		if d > maxRetryWait {
			return maxRetryWait
		}
		return d
	}
	return fallback
}

func (c *Client) Bytes(ctx context.Context, rawURL string, accept string, limit int64) ([]byte, error) {
	data, _, err := c.bytesWithHeader(ctx, rawURL, accept, limit)
	return data, err
}

func (c *Client) bytesWithHeader(ctx context.Context, rawURL string, accept string, limit int64) ([]byte, http.Header, error) {
	h := http.Header{}
	if accept != "" {
		h.Set("Accept", accept)
	}
	resp, err := c.Do(ctx, http.MethodGet, rawURL, h)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return nil, nil, &StatusError{URL: rawURL, Status: resp.StatusCode}
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, nil, fmt.Errorf("GET %s: %w", rawURL, err)
	}
	if int64(len(data)) > limit {
		return nil, nil, fmt.Errorf("GET %s: response larger than %d bytes", rawURL, limit)
	}
	return data, resp.Header, nil
}

func (c *Client) JSON(ctx context.Context, rawURL string, v any) error {
	_, err := c.JSONHeader(ctx, rawURL, v)
	return err
}

func (c *Client) JSONHeader(ctx context.Context, rawURL string, v any) (http.Header, error) {
	data, header, err := c.bytesWithHeader(ctx, rawURL, "application/json", maxJSONBytes)
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(data, v); err != nil {
		return nil, fmt.Errorf("decode %s: %w", rawURL, err)
	}
	return header, nil
}
