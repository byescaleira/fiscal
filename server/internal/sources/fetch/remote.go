package fetch

import (
	"archive/zip"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
)

const (
	blockSize  = 2 << 20
	keepBlocks = 4
)

type Remote struct {
	ctx    context.Context
	client *Client
	url    string
	size   int64
	etag   string

	mu     sync.Mutex
	blocks map[int64][]byte
	order  []int64
	read   int64
}

func (c *Client) Open(ctx context.Context, rawURL string) (*Remote, error) {
	resp, err := c.Do(ctx, http.MethodHead, rawURL, nil)
	if err != nil {
		return nil, err
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, &StatusError{URL: rawURL, Status: resp.StatusCode}
	}
	if !strings.Contains(resp.Header.Get("Accept-Ranges"), "bytes") {
		return nil, fmt.Errorf("HEAD %s: server does not accept byte ranges", rawURL)
	}
	if resp.ContentLength <= 0 {
		return nil, fmt.Errorf("HEAD %s: unknown size", rawURL)
	}
	tag := resp.Header.Get("ETag")
	if tag == "" {
		tag = resp.Header.Get("Last-Modified")
	}
	return &Remote{ctx: ctx, client: c, url: rawURL, size: resp.ContentLength, etag: tag, blocks: map[int64][]byte{}}, nil
}

func (r *Remote) Size() int64 {
	return r.size
}

func (r *Remote) Version() string {
	return r.etag
}

func (r *Remote) BytesRead() int64 {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.read
}

func (r *Remote) ReadAt(p []byte, off int64) (int, error) {
	if off < 0 {
		return 0, errors.New("remote: negative offset")
	}
	if off >= r.size {
		return 0, io.EOF
	}
	n := 0
	for n < len(p) && off+int64(n) < r.size {
		pos := off + int64(n)
		idx := pos / blockSize
		block, err := r.block(idx)
		if err != nil {
			return n, err
		}
		n += copy(p[n:], block[pos-idx*blockSize:])
	}
	if n < len(p) {
		return n, io.EOF
	}
	return n, nil
}

func (r *Remote) block(idx int64) ([]byte, error) {
	r.mu.Lock()
	if b, ok := r.blocks[idx]; ok {
		r.mu.Unlock()
		return b, nil
	}
	r.mu.Unlock()
	start := idx * blockSize
	end := start + blockSize - 1
	if end >= r.size {
		end = r.size - 1
	}
	h := http.Header{}
	h.Set("Range", "bytes="+strconv.FormatInt(start, 10)+"-"+strconv.FormatInt(end, 10))
	if r.etag != "" && strings.HasPrefix(r.etag, "\"") {
		h.Set("If-Range", r.etag)
	}
	resp, err := r.client.Do(r.ctx, http.MethodGet, r.url, h)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusPartialContent {
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("range %s: status %d (file changed or ranges unsupported)", r.url, resp.StatusCode)
	}
	want := end - start + 1
	data, err := io.ReadAll(io.LimitReader(resp.Body, want+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) != want {
		return nil, fmt.Errorf("range %s: got %d bytes, want %d", r.url, len(data), want)
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.read += int64(len(data))
	r.blocks[idx] = data
	r.order = append(r.order, idx)
	for len(r.order) > keepBlocks {
		delete(r.blocks, r.order[0])
		r.order = r.order[1:]
	}
	return data, nil
}

func (r *Remote) Zip() (*zip.Reader, error) {
	return zip.NewReader(r, r.size)
}
