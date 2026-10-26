package httpapi

import (
	"bytes"
	"encoding/base64"
	"io"
	"log"
	"strings"
	"testing"
	"time"

	"liveresults/internal/appattest"
)

type fakeAttest struct {
	registered [][]byte
	checked    [][]byte
	err        error
}

func (f *fakeAttest) Challenge() (string, error) { return "challenge-1", nil }

func (f *fakeAttest) Register(keyID, attestation []byte, challenge string) error {
	if f.err != nil {
		return f.err
	}
	f.registered = append(f.registered, keyID)
	return nil
}

func (f *fakeAttest) Check(keyID, assertion, body []byte) error {
	if f.err != nil {
		return f.err
	}
	f.checked = append(f.checked, append([]byte(nil), body...))
	return nil
}

func attestEnv(mode string, a *fakeAttest) (*env, *fakeAttest) {
	now := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	e := &env{races: &fakeRaces{}, regs: &fakeRegs{}, logs: &bytes.Buffer{}, now: &now}
	clock := func() time.Time { return *e.now }
	e.h = New(Config{Races: e.races, Registrations: e.regs, Attest: a, AttestMode: mode, Unattested: 2, Now: clock, Logger: log.New(io.Discard, "", 0)})
	return e, a
}

const regBody = `{"raceId":"presidente-br","pushToken":"0123456789abcdef0123456789abcdef","environment":"production","challenge":"challenge-1"}`

func attestHeaders() map[string]string {
	return map[string]string{keyHeader: base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)), assertionHeader: base64.StdEncoding.EncodeToString([]byte{0xa0})}
}

func TestAttestChallengeAndKeyRoutes(t *testing.T) {
	e, a := attestEnv(AttestOptional, &fakeAttest{})
	rec := e.do("POST", "/api/v1/attest/challenge", "", nil)
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "challenge-1") || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("challenge %d %s", rec.Code, rec.Body.String())
	}
	key := base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32))
	rec = e.do("POST", "/api/v1/attest/keys", `{"keyId":"`+key+`","attestation":"`+base64.StdEncoding.EncodeToString([]byte{1, 2})+`","challenge":"challenge-1"}`, nil)
	if rec.Code != 204 || len(a.registered) != 1 {
		t.Fatalf("keys %d %s", rec.Code, rec.Body.String())
	}
	if rec := e.do("POST", "/api/v1/attest/keys", `{"keyId":"short","attestation":"AA==","challenge":"c"}`, nil); rec.Code != 422 {
		t.Fatalf("bad key %d", rec.Code)
	}
	a.err = appattest.ErrInvalid
	if rec := e.do("POST", "/api/v1/attest/keys", `{"keyId":"`+key+`","attestation":"AQI=","challenge":"challenge-1"}`, nil); rec.Code != 401 || errorCode(t, rec) != "attest_invalid" {
		t.Fatalf("rejected %d", rec.Code)
	}
	big := strings.Repeat("A", maxAttestBody+1)
	if rec := e.do("POST", "/api/v1/attest/keys", `{"attestation":"`+big+`"}`, nil); rec.Code != 413 {
		t.Fatalf("large %d", rec.Code)
	}
}

func TestAttestedRegistrationPassesTheExactBody(t *testing.T) {
	e, a := attestEnv(AttestRequired, &fakeAttest{})
	rec := e.do("POST", "/api/v1/live-activities", regBody, attestHeaders())
	if rec.Code != 204 || len(e.regs.put) != 1 || string(a.checked[0]) != regBody {
		t.Fatalf("attested %d %s", rec.Code, rec.Body.String())
	}
	if rec := e.do("POST", "/api/v1/live-activities", regBody, nil); rec.Code != 401 || errorCode(t, rec) != "attest_required" {
		t.Fatalf("required %d", rec.Code)
	}
	a.err = appattest.ErrUnknownKey
	if rec := e.do("POST", "/api/v1/highlight-activities", `{"pushToken":"0123456789abcdef0123456789abcdef","environment":"production","challenge":"c"}`, attestHeaders()); rec.Code != 401 || errorCode(t, rec) != "attest_unknown_key" {
		t.Fatalf("unknown key %d", rec.Code)
	}
	a.err = appattest.ErrChallenge
	if rec := e.do("POST", "/api/v1/live-activities", regBody, attestHeaders()); rec.Code != 401 || errorCode(t, rec) != "attest_challenge" {
		t.Fatalf("challenge %d", rec.Code)
	}
	if rec := e.do("POST", "/api/v1/live-activities", regBody, map[string]string{keyHeader: "%%%", assertionHeader: "x"}); rec.Code != 401 {
		t.Fatalf("garbage %d", rec.Code)
	}
	if len(e.regs.put) != 1 {
		t.Fatal("rejected requests must not register")
	}
}

func TestUnattestedRegistrationHasItsOwnLimit(t *testing.T) {
	e, _ := attestEnv(AttestOptional, &fakeAttest{})
	for i := range 2 {
		if rec := e.do("POST", "/api/v1/live-activities", regBody, nil); rec.Code != 204 {
			t.Fatalf("unattested %d = %d", i, rec.Code)
		}
	}
	if rec := e.do("POST", "/api/v1/live-activities", regBody, nil); rec.Code != 429 {
		t.Fatalf("third unattested = %d", rec.Code)
	}
	if rec := e.do("POST", "/api/v1/live-activities", regBody, attestHeaders()); rec.Code != 204 {
		t.Fatalf("attested after the unattested limit = %d", rec.Code)
	}
	off, _ := attestEnv(AttestOff, &fakeAttest{err: appattest.ErrInvalid})
	if rec := off.do("POST", "/api/v1/live-activities", regBody, attestHeaders()); rec.Code != 204 {
		t.Fatalf("off mode = %d", rec.Code)
	}
	none := newEnv(t, "")
	if rec := none.do("POST", "/api/v1/attest/challenge", "", nil); rec.Code != 404 {
		t.Fatalf("no attestor = %d", rec.Code)
	}
}
