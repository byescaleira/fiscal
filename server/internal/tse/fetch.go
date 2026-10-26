package tse

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	UserAgent    = "liveresults-server/1.0 (+results poller)"
	maxFileBytes = 4 << 20
)

type HTTPSource struct {
	base   string
	client *http.Client
	mu     sync.Mutex
	etags  map[string]string
}

func NewHTTPSource(base string, client *http.Client) *HTTPSource {
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	return &HTTPSource{base: strings.TrimRight(base, "/"), client: client, etags: map[string]string{}}
}

func (s *HTTPSource) Fetch(ctx context.Context, d Definition) (Race, bool, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.base+"/"+d.Path, nil)
	if err != nil {
		return Race{}, false, err
	}
	req.Header.Set("User-Agent", UserAgent)
	req.Header.Set("Accept", "application/json")
	s.mu.Lock()
	etag := s.etags[d.ID]
	s.mu.Unlock()
	if etag != "" {
		req.Header.Set("If-None-Match", etag)
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return Race{}, false, err
	}
	defer resp.Body.Close()
	switch resp.StatusCode {
	case http.StatusNotModified:
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return Race{}, false, nil
	case http.StatusOK:
	default:
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return Race{}, false, fmt.Errorf("fetch %s: status %d", d.ID, resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxFileBytes+1))
	if err != nil {
		return Race{}, false, fmt.Errorf("fetch %s: %w", d.ID, err)
	}
	if len(data) > maxFileBytes {
		return Race{}, false, fmt.Errorf("fetch %s: file too large", d.ID)
	}
	race, err := Parse(d, data)
	if err != nil {
		return Race{}, false, err
	}
	s.mu.Lock()
	if tag := resp.Header.Get("ETag"); tag != "" {
		s.etags[d.ID] = tag
	} else {
		delete(s.etags, d.ID)
	}
	s.mu.Unlock()
	return race, true, nil
}
