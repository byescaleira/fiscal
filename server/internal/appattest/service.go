package appattest

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const (
	KeysFile       = "attest-keys.json"
	challengeTTL   = 5 * time.Minute
	maxChallenges  = 100000
	keyIdle        = 400 * 24 * time.Hour
	challengeBytes = 32
)

var (
	ErrChallenge  = errors.New("appattest: unknown or expired challenge")
	ErrUnknownKey = errors.New("appattest: unknown key")
	ErrCapacity   = errors.New("appattest: key capacity reached")
)

type record struct {
	PublicKey   []byte `json:"pk"`
	Counter     uint32 `json:"counter"`
	Development bool   `json:"dev,omitempty"`
	Created     string `json:"created"`
	Used        string `json:"used"`
}

type Service struct {
	verifier *Verifier
	path     string
	max      int
	now      func() time.Time

	mu         sync.Mutex
	keys       map[string]*record
	dirty      bool
	challenges map[string]time.Time
}

func Open(dataDir string, v *Verifier, max int) (*Service, error) {
	s := &Service{verifier: v, path: filepath.Join(dataDir, KeysFile), max: max, now: v.now, keys: map[string]*record{}, challenges: map[string]time.Time{}}
	data, err := os.ReadFile(s.path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	if err == nil {
		if err := json.Unmarshal(data, &s.keys); err != nil {
			return nil, fmt.Errorf("attest keys: %w", err)
		}
	}
	now := s.now()
	for id, r := range s.keys {
		used, err := time.Parse(time.RFC3339, r.Used)
		if err != nil || now.Sub(used) > keyIdle {
			delete(s.keys, id)
			s.dirty = true
		}
	}
	return s, nil
}

func (s *Service) Count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.keys)
}

func (s *Service) Challenge() (string, error) {
	b := make([]byte, challengeBytes)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	c := base64.RawURLEncoding.EncodeToString(b)
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	if len(s.challenges) >= maxChallenges {
		for k, exp := range s.challenges {
			if now.After(exp) {
				delete(s.challenges, k)
			}
		}
		if len(s.challenges) >= maxChallenges {
			return "", ErrCapacity
		}
	}
	s.challenges[c] = now.Add(challengeTTL)
	return c, nil
}

func (s *Service) consume(c string) bool {
	exp, ok := s.challenges[c]
	if !ok {
		return false
	}
	delete(s.challenges, c)
	return !s.now().After(exp)
}

func (s *Service) Register(keyID, attestation []byte, challenge string) error {
	raw, err := base64.RawURLEncoding.DecodeString(challenge)
	if err != nil || len(raw) != challengeBytes {
		return ErrChallenge
	}
	s.mu.Lock()
	ok := s.consume(challenge)
	s.mu.Unlock()
	if !ok {
		return ErrChallenge
	}
	sum := sha256.Sum256(raw)
	key, err := s.verifier.VerifyAttestation(keyID, attestation, sum[:])
	if err != nil {
		return err
	}
	der, err := x509.MarshalPKIXPublicKey(key.PublicKey)
	if err != nil {
		return err
	}
	id := base64.StdEncoding.EncodeToString(keyID)
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.keys[id]; !exists && len(s.keys) >= s.max {
		return ErrCapacity
	}
	stamp := s.now().UTC().Format(time.RFC3339)
	s.keys[id] = &record{PublicKey: der, Development: key.Development, Created: stamp, Used: stamp}
	s.dirty = true
	return nil
}

func (s *Service) Check(keyID []byte, assertion []byte, body []byte) error {
	var fields struct {
		Challenge string `json:"challenge"`
	}
	if json.Unmarshal(body, &fields) != nil || fields.Challenge == "" {
		return ErrChallenge
	}
	id := base64.StdEncoding.EncodeToString(keyID)
	s.mu.Lock()
	defer s.mu.Unlock()
	r, ok := s.keys[id]
	if !ok {
		return ErrUnknownKey
	}
	parsed, err := x509.ParsePKIXPublicKey(r.PublicKey)
	if err != nil {
		return ErrUnknownKey
	}
	pub, ok := parsed.(*ecdsa.PublicKey)
	if !ok {
		return ErrUnknownKey
	}
	counter, err := s.verifier.VerifyAssertion(pub, r.Counter, assertion, body)
	if err != nil {
		return err
	}
	if !s.consume(fields.Challenge) {
		return ErrChallenge
	}
	r.Counter = counter
	r.Used = s.now().UTC().Format(time.RFC3339)
	s.dirty = true
	return nil
}

func (s *Service) Flush() error {
	s.mu.Lock()
	if !s.dirty {
		s.mu.Unlock()
		return nil
	}
	data, err := json.Marshal(s.keys)
	s.dirty = false
	s.mu.Unlock()
	if err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		s.markDirty()
		return err
	}
	if err := os.Rename(tmp, s.path); err != nil {
		s.markDirty()
		return err
	}
	return nil
}

func (s *Service) markDirty() {
	s.mu.Lock()
	s.dirty = true
	s.mu.Unlock()
}

func (s *Service) sweep() {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	for k, exp := range s.challenges {
		if now.After(exp) {
			delete(s.challenges, k)
		}
	}
}

func (s *Service) Run(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.sweep()
			s.Flush()
		}
	}
}
