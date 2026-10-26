package appattest

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"math/big"
	"sort"
	"testing"
	"time"
)

const appID = "TEAM123456.com.byescaleira.fiscal"

func encodeCBOR(v any) []byte {
	var b bytes.Buffer
	head := func(major byte, n uint64) {
		switch {
		case n < 24:
			b.WriteByte(major<<5 | byte(n))
		case n < 256:
			b.WriteByte(major<<5 | 24)
			b.WriteByte(byte(n))
		case n < 65536:
			b.WriteByte(major<<5 | 25)
			binary.Write(&b, binary.BigEndian, uint16(n))
		default:
			b.WriteByte(major<<5 | 26)
			binary.Write(&b, binary.BigEndian, uint32(n))
		}
	}
	var enc func(v any)
	enc = func(v any) {
		switch x := v.(type) {
		case uint64:
			head(0, x)
		case []byte:
			head(2, uint64(len(x)))
			b.Write(x)
		case string:
			head(3, uint64(len(x)))
			b.WriteString(x)
		case []any:
			head(4, uint64(len(x)))
			for _, e := range x {
				enc(e)
			}
		case map[string]any:
			head(5, uint64(len(x)))
			keys := make([]string, 0, len(x))
			for k := range x {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			for _, k := range keys {
				enc(k)
				enc(x[k])
			}
		}
	}
	enc(v)
	return b.Bytes()
}

type chain struct {
	pool     *x509.CertPool
	interKey *ecdsa.PrivateKey
	inter    *x509.Certificate
}

func newChain(t *testing.T) chain {
	t.Helper()
	rootKey, _ := ecdsa.GenerateKey(elliptic.P384(), rand.Reader)
	rootTmpl := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "Test Root"}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTmpl, rootTmpl, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	root, _ := x509.ParseCertificate(rootDER)
	interKey, _ := ecdsa.GenerateKey(elliptic.P384(), rand.Reader)
	interTmpl := &x509.Certificate{SerialNumber: big.NewInt(2), Subject: pkix.Name{CommonName: "Test Intermediate"}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign}
	interDER, err := x509.CreateCertificate(rand.Reader, interTmpl, root, &interKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	inter, _ := x509.ParseCertificate(interDER)
	pool := x509.NewCertPool()
	pool.AddCert(root)
	return chain{pool: pool, interKey: interKey, inter: inter}
}

type device struct {
	key   *ecdsa.PrivateKey
	keyID []byte
}

func newDevice() device {
	k, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	pub, _ := k.PublicKey.ECDH()
	id := sha256.Sum256(pub.Bytes())
	return device{key: k, keyID: id[:]}
}

type attestOpts struct {
	appID   string
	aaguid  []byte
	counter uint32
	credID  []byte
	nonce   []byte
}

func authenticatorData(app string, counter uint32, attested []byte) []byte {
	rp := sha256.Sum256([]byte(app))
	b := append([]byte(nil), rp[:]...)
	b = append(b, 0x40)
	b = binary.BigEndian.AppendUint32(b, counter)
	return append(b, attested...)
}

func (c chain) attest(t *testing.T, d device, clientDataHash []byte, o attestOpts) []byte {
	t.Helper()
	if o.appID == "" {
		o.appID = appID
	}
	if o.aaguid == nil {
		o.aaguid = aaguidProduction
	}
	if o.credID == nil {
		o.credID = d.keyID
	}
	cred := append([]byte(nil), o.aaguid...)
	cred = binary.BigEndian.AppendUint16(cred, uint16(len(o.credID)))
	cred = append(cred, o.credID...)
	cred = append(cred, 0xa0)
	ad := authenticatorData(o.appID, o.counter, cred)
	nonce := o.nonce
	if nonce == nil {
		sum := sha256.Sum256(append(append([]byte(nil), ad...), clientDataHash...))
		nonce = sum[:]
	}
	ext, err := asn1.Marshal(struct {
		Nonce []byte `asn1:"tag:1,explicit"`
	}{nonce})
	if err != nil {
		t.Fatal(err)
	}
	leafTmpl := &x509.Certificate{SerialNumber: big.NewInt(3), Subject: pkix.Name{CommonName: hex.EncodeToString(d.keyID)}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour), ExtraExtensions: []pkix.Extension{{Id: nonceOID, Value: ext}}}
	leafDER, err := x509.CreateCertificate(rand.Reader, leafTmpl, c.inter, &d.key.PublicKey, c.interKey)
	if err != nil {
		t.Fatal(err)
	}
	return encodeCBOR(map[string]any{
		"fmt":      "apple-appattest",
		"attStmt":  map[string]any{"x5c": []any{leafDER, c.inter.Raw}, "receipt": []byte("receipt")},
		"authData": ad,
	})
}

func (d device) assert(t *testing.T, app string, counter uint32, body []byte) []byte {
	t.Helper()
	ad := authenticatorData(app, counter, nil)
	cdh := sha256.Sum256(body)
	nonce := sha256.Sum256(append(append([]byte(nil), ad...), cdh[:]...))
	digest := sha256.Sum256(nonce[:])
	sig, err := ecdsa.SignASN1(rand.Reader, d.key, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	return encodeCBOR(map[string]any{"signature": sig, "authenticatorData": ad})
}

func TestEmbeddedAppleRootIsThePublishedOne(t *testing.T) {
	root, err := AppleRoot()
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(root.Raw)
	if got := hex.EncodeToString(sum[:]); got != "1cb9823ba28ba6ad2d33a006941de2ae4f513ef1d4e831b9f7e0fa7b6242c932" {
		t.Fatalf("fingerprint = %s", got)
	}
	if root.Subject.CommonName != "Apple App Attestation Root CA" || !root.IsCA {
		t.Fatalf("subject = %v", root.Subject)
	}
}

func TestVerifyAttestation(t *testing.T) {
	c := newChain(t)
	d := newDevice()
	cdh := sha256.Sum256([]byte("challenge"))
	v := &Verifier{AppID: appID, Roots: c.pool}
	key, err := v.VerifyAttestation(d.keyID, c.attest(t, d, cdh[:], attestOpts{}), cdh[:])
	if err != nil {
		t.Fatal(err)
	}
	if !key.PublicKey.Equal(&d.key.PublicKey) || key.Development {
		t.Fatal("wrong key")
	}
	other := newDevice()
	wrong := sha256.Sum256([]byte("other"))
	cases := map[string]func() ([]byte, []byte, []byte, *Verifier){
		"app id": func() ([]byte, []byte, []byte, *Verifier) {
			return d.keyID, c.attest(t, d, cdh[:], attestOpts{appID: "OTHER.app"}), cdh[:], v
		},
		"client data": func() ([]byte, []byte, []byte, *Verifier) {
			return d.keyID, c.attest(t, d, cdh[:], attestOpts{}), wrong[:], v
		},
		"nonce": func() ([]byte, []byte, []byte, *Verifier) {
			return d.keyID, c.attest(t, d, cdh[:], attestOpts{nonce: wrong[:]}), cdh[:], v
		},
		"counter": func() ([]byte, []byte, []byte, *Verifier) {
			return d.keyID, c.attest(t, d, cdh[:], attestOpts{counter: 1}), cdh[:], v
		},
		"development": func() ([]byte, []byte, []byte, *Verifier) {
			return d.keyID, c.attest(t, d, cdh[:], attestOpts{aaguid: aaguidDevelopment}), cdh[:], v
		},
		"credential id": func() ([]byte, []byte, []byte, *Verifier) {
			return d.keyID, c.attest(t, d, cdh[:], attestOpts{credID: other.keyID}), cdh[:], v
		},
		"key id": func() ([]byte, []byte, []byte, *Verifier) {
			return other.keyID, c.attest(t, d, cdh[:], attestOpts{credID: other.keyID}), cdh[:], v
		},
		"apple root": func() ([]byte, []byte, []byte, *Verifier) {
			real, _ := NewVerifier(appID, false)
			return d.keyID, c.attest(t, d, cdh[:], attestOpts{}), cdh[:], real
		},
		"garbage": func() ([]byte, []byte, []byte, *Verifier) { return d.keyID, []byte{0xbf, 0x00}, cdh[:], v },
	}
	for name, mk := range cases {
		t.Run(name, func(t *testing.T) {
			id, att, hash, ver := mk()
			if _, err := ver.VerifyAttestation(id, att, hash); !errors.Is(err, ErrInvalid) {
				t.Fatalf("err = %v", err)
			}
		})
	}
	dev := &Verifier{AppID: appID, Roots: c.pool, AllowDevelopment: true}
	key, err = dev.VerifyAttestation(d.keyID, c.attest(t, d, cdh[:], attestOpts{aaguid: aaguidDevelopment}), cdh[:])
	if err != nil || !key.Development {
		t.Fatalf("development = %+v %v", key, err)
	}
}

func TestVerifyAssertion(t *testing.T) {
	d := newDevice()
	v := &Verifier{AppID: appID}
	body := []byte(`{"pushToken":"ab","challenge":"x"}`)
	counter, err := v.VerifyAssertion(&d.key.PublicKey, 0, d.assert(t, appID, 1, body), body)
	if err != nil || counter != 1 {
		t.Fatalf("assert = %d %v", counter, err)
	}
	if _, err := v.VerifyAssertion(&d.key.PublicKey, 1, d.assert(t, appID, 1, body), body); !errors.Is(err, ErrInvalid) {
		t.Fatalf("replayed counter = %v", err)
	}
	if _, err := v.VerifyAssertion(&d.key.PublicKey, 0, d.assert(t, appID, 2, body), []byte(`{"pushToken":"cd"}`)); !errors.Is(err, ErrInvalid) {
		t.Fatalf("tampered body = %v", err)
	}
	if _, err := v.VerifyAssertion(&d.key.PublicKey, 0, d.assert(t, "OTHER.app", 2, body), body); !errors.Is(err, ErrInvalid) {
		t.Fatalf("other app = %v", err)
	}
	other := newDevice()
	if _, err := v.VerifyAssertion(&other.key.PublicKey, 0, d.assert(t, appID, 2, body), body); !errors.Is(err, ErrInvalid) {
		t.Fatalf("other key = %v", err)
	}
}

func TestServiceRegistersKeysAndConsumesChallenges(t *testing.T) {
	c := newChain(t)
	d := newDevice()
	dir := t.TempDir()
	clock := time.Date(2026, 10, 26, 12, 0, 0, 0, time.UTC)
	v := &Verifier{AppID: appID, Roots: c.pool, Now: func() time.Time { return clock }}
	s, err := Open(dir, v, 10)
	if err != nil {
		t.Fatal(err)
	}
	s.now = func() time.Time { return clock }
	ch, err := s.Challenge()
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := base64.RawURLEncoding.DecodeString(ch)
	cdh := sha256.Sum256(raw)
	att := c.attest(t, d, cdh[:], attestOpts{})
	if err := s.Register(d.keyID, att, ch); err != nil {
		t.Fatal(err)
	}
	if err := s.Register(d.keyID, att, ch); !errors.Is(err, ErrChallenge) {
		t.Fatalf("reused challenge = %v", err)
	}
	ch2, _ := s.Challenge()
	body := []byte(`{"raceId":"presidente-br","pushToken":"abcd","environment":"production","challenge":"` + ch2 + `"}`)
	if err := s.Check(d.keyID, d.assert(t, appID, 1, body), body); err != nil {
		t.Fatal(err)
	}
	if err := s.Check(d.keyID, d.assert(t, appID, 2, body), body); !errors.Is(err, ErrChallenge) {
		t.Fatalf("reused challenge = %v", err)
	}
	if err := s.Check(newDevice().keyID, d.assert(t, appID, 3, body), body); !errors.Is(err, ErrUnknownKey) {
		t.Fatalf("unknown key = %v", err)
	}
	ch3, _ := s.Challenge()
	clock = clock.Add(6 * time.Minute)
	late := []byte(`{"challenge":"` + ch3 + `"}`)
	if err := s.Check(d.keyID, d.assert(t, appID, 4, late), late); !errors.Is(err, ErrChallenge) {
		t.Fatalf("expired challenge = %v", err)
	}
	if err := s.Flush(); err != nil {
		t.Fatal(err)
	}
	again, err := Open(dir, v, 10)
	if err != nil || again.Count() != 1 {
		t.Fatalf("reopen = %d %v", again.Count(), err)
	}
	again.now = func() time.Time { return clock }
	ch4, _ := again.Challenge()
	replay := []byte(`{"challenge":"` + ch4 + `"}`)
	if err := again.Check(d.keyID, d.assert(t, appID, 1, replay), replay); !errors.Is(err, ErrInvalid) {
		t.Fatalf("the counter must survive a restart: %v", err)
	}
}

func TestCBORRejectsMalformedInput(t *testing.T) {
	for _, in := range [][]byte{{}, {0x5f}, {0x42, 0x01}, {0xa1, 0x01, 0x01}, {0x81}, {0x00, 0x00}, {0xa2, 0x61, 0x61, 0x01, 0x61, 0x61, 0x02}} {
		if _, err := decodeCBOR(in); err == nil {
			t.Errorf("%x must fail", in)
		}
	}
	v, err := decodeCBOR(encodeCBOR(map[string]any{"a": []any{uint64(1), []byte{2}, "x"}}))
	if err != nil || len(v.(map[string]any)["a"].([]any)) != 3 {
		t.Fatalf("round trip = %v %v", v, err)
	}
}
