package publicdata

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"sync/atomic"
)

const (
	PseudonymKeyBytes = 32
	cpfPrefix         = "cpf:"
	cpfDomain         = "fiscal-person:"
	cpfBytes          = 16
	legacyCPFBytes    = 10
)

var (
	ErrNoPseudonymKey = errors.New("pseudonym key not loaded: set PSEUDONYM_KEY_FILE")
	pseudonymKey      atomic.Pointer[[]byte]
)

func ParsePseudonymKey(data []byte) ([]byte, error) {
	text := strings.TrimSpace(string(data))
	key, err := hex.DecodeString(text)
	if err != nil || len(key) != PseudonymKeyBytes {
		return nil, fmt.Errorf("the pseudonym key must be %d hexadecimal characters (openssl rand -hex %d)", 2*PseudonymKeyBytes, PseudonymKeyBytes)
	}
	return key, nil
}

func ReadPseudonymKey(path string) ([]byte, error) {
	if strings.TrimSpace(path) == "" {
		return nil, ErrNoPseudonymKey
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("pseudonym key %s: %w (create it once with openssl rand -hex %d, see docs/server-runbook.md)", path, err, PseudonymKeyBytes)
	}
	key, err := ParsePseudonymKey(data)
	if err != nil {
		return nil, fmt.Errorf("pseudonym key %s: %w", path, err)
	}
	return key, nil
}

func SetPseudonymKey(key []byte) error {
	if len(key) != PseudonymKeyBytes {
		return fmt.Errorf("the pseudonym key must have %d bytes", PseudonymKeyBytes)
	}
	k := append([]byte(nil), key...)
	pseudonymKey.Store(&k)
	return nil
}

func CPFKey(cpf string) string {
	if strings.HasPrefix(cpf, cpfPrefix) {
		return cpf
	}
	key := pseudonymKey.Load()
	if key == nil {
		panic(ErrNoPseudonymKey)
	}
	mac := hmac.New(sha256.New, *key)
	mac.Write([]byte(cpfDomain + cpf))
	return cpfPrefix + hex.EncodeToString(mac.Sum(nil)[:cpfBytes])
}

func legacyCPFKey(cpf string) string {
	sum := sha256.Sum256([]byte(cpfDomain + cpf))
	return cpfPrefix + hex.EncodeToString(sum[:legacyCPFBytes])
}

func IsLegacyCPFKey(k string) bool {
	return strings.HasPrefix(k, cpfPrefix) && len(k) == len(cpfPrefix)+2*legacyCPFBytes
}

type Pseudonyms struct {
	mu     sync.Mutex
	legacy map[string]string
}

func NewPseudonyms() *Pseudonyms {
	return &Pseudonyms{legacy: map[string]string{}}
}

func (m *Pseudonyms) CPF(cpf string) string {
	if cpf == "" {
		return ""
	}
	if strings.HasPrefix(cpf, cpfPrefix) {
		return m.Current(cpf)
	}
	current := CPFKey(cpf)
	m.mu.Lock()
	m.legacy[legacyCPFKey(cpf)] = current
	m.mu.Unlock()
	return current
}

func (m *Pseudonyms) Current(k string) string {
	if !IsLegacyCPFKey(k) {
		return k
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if v, ok := m.legacy[k]; ok {
		return v
	}
	return k
}

func (m *Pseudonyms) Len() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.legacy)
}

func (m *Pseudonyms) Person(p *Person) {
	p.CPF = m.CPF(p.CPF)
	for i := range p.Candidacies {
		p.Candidacies[i].CPF = m.CPF(p.Candidacies[i].CPF)
	}
	seen := map[string]bool{}
	keys := p.Keys[:0]
	for _, k := range p.Keys {
		k = m.Current(k)
		if seen[k] {
			continue
		}
		seen[k] = true
		keys = append(keys, k)
	}
	p.Keys = keys
}

func (s *Slugs) Migrate(m *Pseudonyms) int {
	moved := 0
	for k, slug := range s.byKey {
		current := m.Current(k)
		if current == k {
			continue
		}
		if _, ok := s.byKey[current]; !ok {
			s.byKey[current] = slug
		}
		delete(s.byKey, k)
		moved++
	}
	return moved
}
