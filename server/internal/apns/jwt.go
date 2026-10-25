package apns

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"os"
	"sync"
	"time"
)

const tokenTTL = 40 * time.Minute

func LoadKey(path string) (*ecdsa.PrivateKey, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read apns key: %w", err)
	}
	return ParseKey(data)
}

func ParseKey(data []byte) (*ecdsa.PrivateKey, error) {
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, errors.New("apns key: no PEM block")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("apns key: %w", err)
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok || key.Curve != elliptic.P256() {
		return nil, errors.New("apns key: not an ECDSA P-256 key")
	}
	return key, nil
}

type TokenProvider struct {
	key    *ecdsa.PrivateKey
	keyID  string
	teamID string
	now    func() time.Time
	mu     sync.Mutex
	token  string
	issued time.Time
}

func NewTokenProvider(key *ecdsa.PrivateKey, keyID, teamID string, now func() time.Time) *TokenProvider {
	if now == nil {
		now = time.Now
	}
	return &TokenProvider{key: key, keyID: keyID, teamID: teamID, now: now}
}

func (p *TokenProvider) Token() (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	now := p.now()
	if p.token != "" && now.Sub(p.issued) < tokenTTL && !now.Before(p.issued) {
		return p.token, nil
	}
	token, err := signJWT(p.key, p.keyID, p.teamID, now)
	if err != nil {
		return "", err
	}
	p.token = token
	p.issued = now
	return token, nil
}

func (p *TokenProvider) Invalidate() {
	p.mu.Lock()
	p.token = ""
	p.mu.Unlock()
}

func signJWT(key *ecdsa.PrivateKey, keyID, teamID string, now time.Time) (string, error) {
	header, err := json.Marshal(map[string]string{"alg": "ES256", "kid": keyID})
	if err != nil {
		return "", err
	}
	claims, err := json.Marshal(map[string]any{"iss": teamID, "iat": now.Unix()})
	if err != nil {
		return "", err
	}
	enc := base64.RawURLEncoding
	signing := enc.EncodeToString(header) + "." + enc.EncodeToString(claims)
	digest := sha256.Sum256([]byte(signing))
	r, s, err := ecdsa.Sign(rand.Reader, key, digest[:])
	if err != nil {
		return "", err
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	return signing + "." + enc.EncodeToString(sig), nil
}
