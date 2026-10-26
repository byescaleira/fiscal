package appattest

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	_ "embed"
	"encoding/asn1"
	"encoding/binary"
	"errors"
	"fmt"
	"time"
)

//go:embed apple-root-ca.der
var appleRootDER []byte

var (
	nonceOID           = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 2}
	aaguidProduction   = append([]byte("appattest"), make([]byte, 7)...)
	aaguidDevelopment  = []byte("appattestdevelop")
	ErrInvalid         = errors.New("appattest: verification failed")
	maxAttestationSize = 16 << 10
	maxAssertionSize   = 1 << 10
)

func AppleRoot() (*x509.Certificate, error) {
	return x509.ParseCertificate(appleRootDER)
}

type Verifier struct {
	AppID            string
	AllowDevelopment bool
	Roots            *x509.CertPool
	Now              func() time.Time
}

func NewVerifier(appID string, allowDevelopment bool) (*Verifier, error) {
	root, err := AppleRoot()
	if err != nil {
		return nil, err
	}
	pool := x509.NewCertPool()
	pool.AddCert(root)
	return &Verifier{AppID: appID, AllowDevelopment: allowDevelopment, Roots: pool, Now: time.Now}, nil
}

type Key struct {
	ID          []byte
	PublicKey   *ecdsa.PublicKey
	Development bool
}

type authData struct {
	rpIDHash []byte
	flags    byte
	counter  uint32
	aaguid   []byte
	credID   []byte
}

func parseAuthData(b []byte, attested bool) (authData, error) {
	var a authData
	if len(b) < 37 {
		return a, fmt.Errorf("%w: short authenticator data", ErrInvalid)
	}
	a.rpIDHash, a.flags, a.counter = b[:32], b[32], binary.BigEndian.Uint32(b[33:37])
	if !attested {
		return a, nil
	}
	if len(b) < 55 {
		return a, fmt.Errorf("%w: missing attested credential data", ErrInvalid)
	}
	a.aaguid = b[37:53]
	n := int(binary.BigEndian.Uint16(b[53:55]))
	if len(b) < 55+n {
		return a, fmt.Errorf("%w: truncated credential id", ErrInvalid)
	}
	a.credID = b[55 : 55+n]
	return a, nil
}

func (v *Verifier) now() time.Time {
	if v.Now == nil {
		return time.Now()
	}
	return v.Now()
}

func (v *Verifier) rpIDHash() []byte {
	sum := sha256.Sum256([]byte(v.AppID))
	return sum[:]
}

func publicKeyBytes(pub *ecdsa.PublicKey) ([]byte, error) {
	k, err := pub.ECDH()
	if err != nil {
		return nil, err
	}
	return k.Bytes(), nil
}

func (v *Verifier) VerifyAttestation(keyID []byte, attestation []byte, clientDataHash []byte) (Key, error) {
	fail := func(format string, args ...any) (Key, error) {
		return Key{}, fmt.Errorf("%w: %s", ErrInvalid, fmt.Sprintf(format, args...))
	}
	if len(attestation) == 0 || len(attestation) > maxAttestationSize {
		return fail("attestation size")
	}
	if len(keyID) != sha256.Size || len(clientDataHash) != sha256.Size {
		return fail("key id or client data hash size")
	}
	raw, err := decodeCBOR(attestation)
	if err != nil {
		return Key{}, fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	obj, ok := raw.(map[string]any)
	if !ok || obj["fmt"] != "apple-appattest" {
		return fail("format")
	}
	stmt, ok := obj["attStmt"].(map[string]any)
	if !ok {
		return fail("statement")
	}
	ad, ok := obj["authData"].([]byte)
	if !ok {
		return fail("authenticator data")
	}
	x5c, ok := stmt["x5c"].([]any)
	if !ok || len(x5c) < 2 {
		return fail("certificate chain")
	}
	var certs []*x509.Certificate
	for _, c := range x5c {
		der, ok := c.([]byte)
		if !ok {
			return fail("certificate type")
		}
		cert, err := x509.ParseCertificate(der)
		if err != nil {
			return fail("certificate: %v", err)
		}
		certs = append(certs, cert)
	}
	inter := x509.NewCertPool()
	for _, c := range certs[1:] {
		inter.AddCert(c)
	}
	if _, err := certs[0].Verify(x509.VerifyOptions{Roots: v.Roots, Intermediates: inter, CurrentTime: v.now(), KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		return fail("chain: %v", err)
	}
	nonce := sha256.Sum256(append(append([]byte(nil), ad...), clientDataHash...))
	var found []byte
	for _, ext := range certs[0].Extensions {
		if !ext.Id.Equal(nonceOID) {
			continue
		}
		var seq struct {
			Nonce []byte `asn1:"tag:1,explicit"`
		}
		if _, err := asn1.Unmarshal(ext.Value, &seq); err != nil {
			return fail("nonce extension: %v", err)
		}
		found = seq.Nonce
	}
	if !bytes.Equal(found, nonce[:]) {
		return fail("nonce")
	}
	pub, ok := certs[0].PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return fail("public key type")
	}
	pk, err := publicKeyBytes(pub)
	if err != nil {
		return fail("public key: %v", err)
	}
	if id := sha256.Sum256(pk); !bytes.Equal(id[:], keyID) {
		return fail("key id")
	}
	a, err := parseAuthData(ad, true)
	if err != nil {
		return Key{}, err
	}
	if !bytes.Equal(a.rpIDHash, v.rpIDHash()) {
		return fail("app id")
	}
	if a.counter != 0 {
		return fail("counter")
	}
	dev := false
	switch {
	case bytes.Equal(a.aaguid, aaguidProduction):
	case bytes.Equal(a.aaguid, aaguidDevelopment) && v.AllowDevelopment:
		dev = true
	default:
		return fail("environment")
	}
	if !bytes.Equal(a.credID, keyID) {
		return fail("credential id")
	}
	return Key{ID: keyID, PublicKey: pub, Development: dev}, nil
}

func (v *Verifier) VerifyAssertion(pub *ecdsa.PublicKey, lastCounter uint32, assertion []byte, clientData []byte) (uint32, error) {
	fail := func(format string, args ...any) (uint32, error) {
		return 0, fmt.Errorf("%w: %s", ErrInvalid, fmt.Sprintf(format, args...))
	}
	if len(assertion) == 0 || len(assertion) > maxAssertionSize {
		return fail("assertion size")
	}
	raw, err := decodeCBOR(assertion)
	if err != nil {
		return 0, fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	obj, ok := raw.(map[string]any)
	if !ok {
		return fail("format")
	}
	sig, ok1 := obj["signature"].([]byte)
	ad, ok2 := obj["authenticatorData"].([]byte)
	if !ok1 || !ok2 {
		return fail("fields")
	}
	cdh := sha256.Sum256(clientData)
	nonce := sha256.Sum256(append(append([]byte(nil), ad...), cdh[:]...))
	digest := sha256.Sum256(nonce[:])
	if !ecdsa.VerifyASN1(pub, digest[:], sig) {
		return fail("signature")
	}
	a, err := parseAuthData(ad, false)
	if err != nil {
		return 0, err
	}
	if !bytes.Equal(a.rpIDHash, v.rpIDHash()) {
		return fail("app id")
	}
	if a.counter <= lastCounter {
		return fail("counter")
	}
	return a.counter, nil
}
