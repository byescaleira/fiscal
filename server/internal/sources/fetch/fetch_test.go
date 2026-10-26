package fetch

import (
	"archive/zip"
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func noSleep(context.Context, time.Duration) error { return nil }

func TestJSONRetriesOnTooManyRequests(t *testing.T) {
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("User-Agent") != UserAgent {
			t.Errorf("user agent = %q", r.Header.Get("User-Agent"))
		}
		if calls.Add(1) == 1 {
			w.Header().Set("Retry-After", "30")
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}
		w.Write([]byte(`{"ok":true}`))
	}))
	defer srv.Close()
	c := New("", 5*time.Second)
	c.Gap = 0
	var waited []time.Duration
	c.Sleep = func(_ context.Context, d time.Duration) error {
		waited = append(waited, d)
		return nil
	}
	var body struct{ OK bool }
	if err := c.JSON(context.Background(), srv.URL, &body); err != nil || !body.OK {
		t.Fatalf("err=%v body=%+v", err, body)
	}
	if calls.Load() != 2 || len(waited) != 1 || waited[0] != 30*time.Second {
		t.Fatalf("calls=%d waited=%v", calls.Load(), waited)
	}
}

func TestJSONReportsNotFound(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	defer srv.Close()
	c := New("", 5*time.Second)
	c.Gap = 0
	var v any
	if err := c.JSON(context.Background(), srv.URL, &v); !IsNotFound(err) {
		t.Fatalf("err = %v", err)
	}
}

func TestJSONHeaderReturnsTheResponseHeaders(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-WP-TotalPages", "12")
		w.Write([]byte(`[1,2]`))
	}))
	defer srv.Close()
	c := New("", 5*time.Second)
	c.Gap = 0
	var v []int
	h, err := c.JSONHeader(context.Background(), srv.URL, &v)
	if err != nil || len(v) != 2 || h.Get("X-Wp-Totalpages") != "12" {
		t.Fatalf("err=%v v=%v header=%v", err, v, h)
	}
}

func TestBytesEnforcesLimit(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(bytes.Repeat([]byte("x"), 100))
	}))
	defer srv.Close()
	c := New("", 5*time.Second)
	c.Gap = 0
	if _, err := c.Bytes(context.Background(), srv.URL, "", 10); err == nil {
		t.Fatal("oversized response accepted")
	}
}

func TestCacheUsesConditionalRequests(t *testing.T) {
	var full atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("If-None-Match") == `"v1"` {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		full.Add(1)
		w.Header().Set("ETag", `"v1"`)
		w.Write([]byte("hello"))
	}))
	defer srv.Close()
	dir := t.TempDir()
	c := New(dir, 5*time.Second)
	c.Gap = 0
	first, err := c.Cache(context.Background(), srv.URL+"/a.csv", 1<<20)
	if err != nil || !first.Changed {
		t.Fatalf("first: %+v %v", first, err)
	}
	second, err := c.Cache(context.Background(), srv.URL+"/a.csv", 1<<20)
	if err != nil || second.Changed || second.Path != first.Path {
		t.Fatalf("second: %+v %v", second, err)
	}
	data, _ := os.ReadFile(second.Path)
	if string(data) != "hello" || full.Load() != 1 {
		t.Fatalf("data=%q full=%d", data, full.Load())
	}
	info, _ := os.Stat(second.Path)
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("cache mode = %v", info.Mode().Perm())
	}
}

func TestRemoteZipReadsOnlyTheRequestedEntry(t *testing.T) {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	big := strings.Repeat("ignored line with filler content 0123456789\n", 400000)
	for _, e := range []struct{ name, body string }{{"a_BRASIL.csv", big}, {"a_AC.csv", "\"X\"\n\"1\"\n"}} {
		w, _ := zw.CreateHeader(&zip.FileHeader{Name: e.name, Method: zip.Store})
		w.Write([]byte(e.body))
	}
	zw.Close()
	payload := buf.Bytes()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("ETag", `"z1"`)
		http.ServeContent(w, r, "a.zip", time.Time{}, bytes.NewReader(payload))
	}))
	defer srv.Close()
	c := New("", 5*time.Second)
	c.Gap = 0
	remote, err := c.Open(context.Background(), srv.URL+"/a.zip")
	if err != nil {
		t.Fatal(err)
	}
	if remote.Version() != `"z1"` || remote.Size() != int64(len(payload)) {
		t.Fatalf("version=%q size=%d", remote.Version(), remote.Size())
	}
	zr, err := remote.Zip()
	if err != nil {
		t.Fatal(err)
	}
	var body []byte
	for _, f := range zr.File {
		if f.Name == "a_AC.csv" {
			rc, _ := f.Open()
			body, _ = io.ReadAll(rc)
			rc.Close()
		}
	}
	if string(body) != "\"X\"\n\"1\"\n" {
		t.Fatalf("entry = %q", body)
	}
	if remote.BytesRead() >= int64(len(payload)) {
		t.Fatalf("read %d of %d bytes: range reading did not skip the large entry", remote.BytesRead(), len(payload))
	}
}
