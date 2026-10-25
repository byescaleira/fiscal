package apns

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"liveresults/internal/tse"
)

func testKey(t *testing.T) (*ecdsa.PrivateKey, string) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "key.p8")
	if err := os.WriteFile(path, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), 0o600); err != nil {
		t.Fatal(err)
	}
	return key, path
}

func TestLoadKey(t *testing.T) {
	key, path := testKey(t)
	loaded, err := LoadKey(path)
	if err != nil {
		t.Fatal(err)
	}
	if !loaded.Equal(key) {
		t.Fatal("loaded key differs")
	}
	if _, err := ParseKey([]byte("not a key")); err == nil {
		t.Fatal("expected error")
	}
	rsaLike := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: []byte{1, 2, 3}})
	if _, err := ParseKey(rsaLike); err == nil {
		t.Fatal("expected error for garbage DER")
	}
	if _, err := LoadKey(filepath.Join(t.TempDir(), "missing.p8")); err == nil {
		t.Fatal("expected error for missing file")
	}
}

func TestJWTSignatureVerifies(t *testing.T) {
	key, _ := testKey(t)
	now := time.Unix(1792960000, 0)
	p := NewTokenProvider(key, "KEY123", "TEAM456", func() time.Time { return now })
	token, err := p.Token()
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token parts %d", len(parts))
	}
	enc := base64.RawURLEncoding
	var header map[string]string
	hb, _ := enc.DecodeString(parts[0])
	json.Unmarshal(hb, &header)
	if header["alg"] != "ES256" || header["kid"] != "KEY123" {
		t.Fatalf("header %v", header)
	}
	var claims map[string]any
	cb, _ := enc.DecodeString(parts[1])
	json.Unmarshal(cb, &claims)
	if claims["iss"] != "TEAM456" || claims["iat"] != float64(1792960000) {
		t.Fatalf("claims %v", claims)
	}
	sig, err := enc.DecodeString(parts[2])
	if err != nil || len(sig) != 64 {
		t.Fatalf("signature %v %d", err, len(sig))
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	r := new(big.Int).SetBytes(sig[:32])
	s := new(big.Int).SetBytes(sig[32:])
	if !ecdsa.Verify(&key.PublicKey, digest[:], r, s) {
		t.Fatal("signature does not verify")
	}
	other, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if ecdsa.Verify(&other.PublicKey, digest[:], r, s) {
		t.Fatal("signature verified with another key")
	}
}

func TestJWTReuseAndRefresh(t *testing.T) {
	key, _ := testKey(t)
	now := time.Unix(1792960000, 0)
	p := NewTokenProvider(key, "K", "T", func() time.Time { return now })
	first, _ := p.Token()
	now = now.Add(39 * time.Minute)
	if second, _ := p.Token(); second != first {
		t.Fatal("token must be reused within 40 minutes")
	}
	now = now.Add(2 * time.Minute)
	third, _ := p.Token()
	if third == first {
		t.Fatal("token must refresh after 40 minutes")
	}
	p.Invalidate()
	if fourth, _ := p.Token(); fourth == third {
		t.Fatal("token must refresh after invalidate")
	}
}

func race(final bool) tse.Race {
	r := tse.Race{
		ID:                "presidente-br",
		Sections:          tse.Sections{Total: 100, Counted: 12, Percent: 12.34},
		SourceGeneratedAt: "2026-10-25T17:30:00-03:00",
		Candidates: []tse.Candidate{
			{Number: "13", Name: "Lula", Party: "PT", Votes: 1234, Percent: 50.1},
			{Number: "22", Name: "Flavio Bolsonaro", Party: "PL", Votes: 1229, Percent: 49.9},
		},
	}
	if final {
		r.Final = true
		r.Candidates[0].Elected = true
	}
	return r
}

func TestBuildUpdatePayloadExact(t *testing.T) {
	now := time.Unix(1792960000, 0)
	msg, err := BuildMessage(race(false), now)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"aps":{"timestamp":1792960000,"event":"update","content-state":{"sectionsPercent":12.34,"candidates":[{"number":"13","votes":1234,"percent":50.1,"elected":false},{"number":"22","votes":1229,"percent":49.9,"elected":false}],"final":false,"updatedAt":1792960200},"stale-date":1792960600}}`
	if string(msg.Payload) != want {
		t.Fatalf("payload\n got %s\nwant %s", msg.Payload, want)
	}
	if msg.Priority != 5 || msg.End {
		t.Fatalf("priority %d end %v", msg.Priority, msg.End)
	}
	var decoded map[string]map[string]any
	json.Unmarshal(msg.Payload, &decoded)
	cs := decoded["aps"]["content-state"].(map[string]any)
	if _, ok := cs["updatedAt"].(float64); !ok {
		t.Fatal("updatedAt must be a JSON number")
	}
}

func TestBuildEndPayloadExact(t *testing.T) {
	now := time.Unix(1792960000, 0)
	msg, err := BuildMessage(race(true), now)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"aps":{"timestamp":1792960000,"event":"end","content-state":{"sectionsPercent":12.34,"candidates":[{"number":"13","votes":1234,"percent":50.1,"elected":true},{"number":"22","votes":1229,"percent":49.9,"elected":false}],"final":true,"updatedAt":1792960200},"dismissal-date":1792974400,"alert":{"title":"Resultado","body":"Lula foi eleito(a)"}}}`
	if string(msg.Payload) != want {
		t.Fatalf("payload\n got %s\nwant %s", msg.Payload, want)
	}
	if msg.Priority != 10 || !msg.End {
		t.Fatalf("priority %d end %v", msg.Priority, msg.End)
	}
}

func TestBuildPayloadFallsBackToNow(t *testing.T) {
	r := race(false)
	r.SourceGeneratedAt = ""
	msg, _ := BuildMessage(r, time.Unix(1792960000, 0))
	if !strings.Contains(string(msg.Payload), `"updatedAt":1792960000`) {
		t.Fatalf("payload %s", msg.Payload)
	}
}

func h2Server(t *testing.T, handler http.HandlerFunc) (*httptest.Server, *http.Client) {
	t.Helper()
	srv := httptest.NewUnstartedServer(handler)
	srv.EnableHTTP2 = true
	srv.StartTLS()
	t.Cleanup(srv.Close)
	pool := x509.NewCertPool()
	pool.AddCert(srv.Certificate())
	return srv, &http.Client{Transport: NewTransport(&tls.Config{RootCAs: pool}), Timeout: 5 * time.Second}
}

func TestClientSendsOverHTTP2WithHeaders(t *testing.T) {
	key, _ := testKey(t)
	now := time.Unix(1792960000, 0)
	var seen atomic.Int32
	token := strings.Repeat("ab", 32)
	srv, httpClient := h2Server(t, func(w http.ResponseWriter, r *http.Request) {
		seen.Add(1)
		if r.ProtoMajor != 2 {
			t.Errorf("proto %s", r.Proto)
		}
		if r.Method != http.MethodPost || r.URL.Path != "/3/device/"+token {
			t.Errorf("request %s %s", r.Method, r.URL.Path)
		}
		checks := map[string]string{
			"apns-push-type":  "liveactivity",
			"apns-topic":      "com.example.app.push-type.liveactivity",
			"apns-priority":   "10",
			"apns-expiration": strconv.FormatInt(now.Add(5*time.Minute).Unix(), 10),
		}
		for k, v := range checks {
			if got := r.Header.Get(k); got != v {
				t.Errorf("%s = %q, want %q", k, got, v)
			}
		}
		if !strings.HasPrefix(r.Header.Get("authorization"), "bearer ") {
			t.Errorf("authorization %q", r.Header.Get("authorization"))
		}
		body, _ := io.ReadAll(r.Body)
		if string(body) != `{"x":1}` {
			t.Errorf("body %s", body)
		}
	})
	c := NewClient(NewTokenProvider(key, "K", "T", func() time.Time { return now }), "com.example.app.push-type.liveactivity")
	c.HTTP = httpClient
	c.now = func() time.Time { return now }
	c.Hosts = map[string]string{EnvDevelopment: srv.URL, EnvProduction: srv.URL}
	res := c.Send(context.Background(), Notification{Token: token, Environment: EnvDevelopment, Priority: 10, Payload: []byte(`{"x":1}`)})
	if !res.OK() || seen.Load() != 1 {
		t.Fatalf("result %+v seen %d", res, seen.Load())
	}
	if res := c.Send(context.Background(), Notification{Token: token, Environment: "staging"}); res.Err == nil {
		t.Fatal("unknown environment must fail")
	}
}

func TestClientReadsReasons(t *testing.T) {
	key, _ := testKey(t)
	cases := []struct {
		status  int
		reason  string
		invalid bool
	}{
		{410, "Unregistered", true},
		{410, "", true},
		{400, "BadDeviceToken", true},
		{400, "ExpiredToken", true},
		{400, "BadTopic", false},
		{429, "TooManyRequests", false},
		{500, "InternalServerError", false},
	}
	for _, tc := range cases {
		srv, httpClient := h2Server(t, func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(tc.status)
			if tc.reason != "" {
				json.NewEncoder(w).Encode(map[string]string{"reason": tc.reason})
			}
		})
		c := NewClient(NewTokenProvider(key, "K", "T", nil), "t.push-type.liveactivity")
		c.HTTP = httpClient
		c.Hosts = map[string]string{EnvProduction: srv.URL}
		res := c.Send(context.Background(), Notification{Token: "aa", Environment: EnvProduction, Priority: 5, Payload: []byte("{}")})
		if res.Status != tc.status || res.Reason != tc.reason || res.TokenInvalid() != tc.invalid || res.OK() {
			t.Errorf("%d %s: %+v invalid=%v", tc.status, tc.reason, res, res.TokenInvalid())
		}
	}
}

func TestClientInvalidatesExpiredProviderToken(t *testing.T) {
	key, _ := testKey(t)
	var auths []string
	srv, httpClient := h2Server(t, func(w http.ResponseWriter, r *http.Request) {
		auths = append(auths, r.Header.Get("authorization"))
		w.WriteHeader(http.StatusForbidden)
		w.Write([]byte(`{"reason":"ExpiredProviderToken"}`))
	})
	now := time.Unix(1792960000, 0)
	c := NewClient(NewTokenProvider(key, "K", "T", func() time.Time { now = now.Add(time.Second); return now }), "t")
	c.HTTP = httpClient
	c.Hosts = map[string]string{EnvProduction: srv.URL}
	c.Send(context.Background(), Notification{Token: "aa", Environment: EnvProduction, Payload: []byte("{}")})
	c.Send(context.Background(), Notification{Token: "aa", Environment: EnvProduction, Payload: []byte("{}")})
	if len(auths) != 2 || auths[0] == auths[1] {
		t.Fatal("expired provider token must be regenerated")
	}
}
