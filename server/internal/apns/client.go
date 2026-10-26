package apns

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

const (
	EnvDevelopment = "development"
	EnvProduction  = "production"
	expiration     = 5 * time.Minute
)

var DefaultHosts = map[string]string{
	EnvDevelopment: "https://api.sandbox.push.apple.com",
	EnvProduction:  "https://api.push.apple.com",
}

type Notification struct {
	Token       string
	Environment string
	Priority    int
	Payload     []byte
}

type Result struct {
	Status int
	Reason string
	Err    error
}

func (r Result) OK() bool {
	return r.Err == nil && r.Status == http.StatusOK
}

func (r Result) TokenInvalid() bool {
	if r.Err != nil {
		return false
	}
	if r.Status == http.StatusGone {
		return true
	}
	switch r.Reason {
	case "BadDeviceToken", "Unregistered", "ExpiredToken":
		return true
	}
	return false
}

type Sender interface {
	Send(ctx context.Context, n Notification) Result
}

func NewTransport(tlsConfig *tls.Config) *http.Transport {
	if tlsConfig == nil {
		tlsConfig = &tls.Config{}
	}
	tlsConfig.MinVersion = tls.VersionTLS12
	return &http.Transport{
		Proxy:               nil,
		DialContext:         (&net.Dialer{Timeout: 10 * time.Second, KeepAlive: 30 * time.Second}).DialContext,
		ForceAttemptHTTP2:   true,
		TLSClientConfig:     tlsConfig,
		TLSHandshakeTimeout: 10 * time.Second,
		MaxIdleConns:        10,
		IdleConnTimeout:     5 * time.Minute,
	}
}

type Client struct {
	HTTP   *http.Client
	Hosts  map[string]string
	tokens *TokenProvider
	topic  string
	now    func() time.Time
}

func NewClient(tokens *TokenProvider, topic string) *Client {
	return &Client{
		HTTP:   &http.Client{Transport: NewTransport(nil), Timeout: 15 * time.Second},
		Hosts:  DefaultHosts,
		tokens: tokens,
		topic:  topic,
		now:    time.Now,
	}
}

func (c *Client) Send(ctx context.Context, n Notification) Result {
	host, ok := c.Hosts[n.Environment]
	if !ok {
		return Result{Err: fmt.Errorf("unknown environment %q", n.Environment)}
	}
	jwt, err := c.tokens.Token()
	if err != nil {
		return Result{Err: err}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, host+"/3/device/"+n.Token, bytes.NewReader(n.Payload))
	if err != nil {
		return Result{Err: err}
	}
	req.Header.Set("authorization", "bearer "+jwt)
	req.Header.Set("apns-push-type", "liveactivity")
	req.Header.Set("apns-topic", c.topic)
	req.Header.Set("apns-priority", strconv.Itoa(n.Priority))
	req.Header.Set("apns-expiration", strconv.FormatInt(c.now().Add(expiration).Unix(), 10))
	req.Header.Set("content-type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		var urlErr *url.Error
		if errors.As(err, &urlErr) {
			err = urlErr.Err
		}
		return Result{Err: fmt.Errorf("apns request: %w", err)}
	}
	defer resp.Body.Close()
	res := Result{Status: resp.StatusCode}
	if resp.StatusCode != http.StatusOK {
		var body struct {
			Reason string `json:"reason"`
		}
		data, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		json.Unmarshal(data, &body)
		res.Reason = body.Reason
		if resp.StatusCode == http.StatusForbidden && (body.Reason == "ExpiredProviderToken" || body.Reason == "InvalidProviderToken") {
			c.tokens.Invalidate()
		}
	} else {
		io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	}
	return res
}

type DisabledSender struct {
	Logger *log.Logger
}

func (d DisabledSender) Send(_ context.Context, n Notification) Result {
	var body struct {
		Aps struct {
			Event        string `json:"event"`
			ContentState struct {
				SectionsPercent float64 `json:"sectionsPercent"`
			} `json:"content-state"`
		} `json:"aps"`
	}
	json.Unmarshal(n.Payload, &body)
	logger := d.Logger
	if logger == nil {
		logger = log.Default()
	}
	logger.Printf("apns disabled: would send event=%s env=%s priority=%d sections=%.2f bytes=%d", body.Aps.Event, n.Environment, n.Priority, body.Aps.ContentState.SectionsPercent, len(n.Payload))
	return Result{Status: http.StatusOK}
}
