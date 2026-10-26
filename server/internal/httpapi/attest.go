package httpapi

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"liveresults/internal/appattest"
)

const (
	AttestOff      = "off"
	AttestOptional = "optional"
	AttestRequired = "required"

	ClassUnattested = "unattested"
	keyHeader       = "X-Fiscal-Attest-Key"
	assertionHeader = "X-Fiscal-Attest-Assertion"
	maxAttestBody   = 16 << 10
)

type Attestor interface {
	Challenge() (string, error)
	Register(keyID, attestation []byte, challenge string) error
	Check(keyID, assertion, body []byte) error
}

func (s *server) challenge(w http.ResponseWriter, r *http.Request) {
	if s.attest == nil {
		writeError(w, http.StatusNotFound, "not_found", "route not found")
		return
	}
	c, err := s.attest.Challenge()
	if err != nil {
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusServiceUnavailable, "attest_busy", "try again later")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"challenge": c})
}

func (s *server) registerKey(w http.ResponseWriter, r *http.Request) {
	if s.attest == nil {
		writeError(w, http.StatusNotFound, "not_found", "route not found")
		return
	}
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxAttestBody))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", "body exceeds 16 KiB")
			return
		}
		writeError(w, http.StatusBadRequest, "bad_request", "could not read body")
		return
	}
	var body struct {
		KeyID       string `json:"keyId"`
		Attestation string `json:"attestation"`
		Challenge   string `json:"challenge"`
	}
	if json.Unmarshal(data, &body) != nil {
		writeError(w, http.StatusUnprocessableEntity, "invalid_request", "body must be a JSON object")
		return
	}
	keyID, err1 := base64.StdEncoding.DecodeString(body.KeyID)
	att, err2 := base64.StdEncoding.DecodeString(body.Attestation)
	if err1 != nil || err2 != nil || len(keyID) != 32 || len(att) == 0 || body.Challenge == "" {
		writeError(w, http.StatusUnprocessableEntity, "invalid_request", "keyId, attestation and challenge are required")
		return
	}
	err = s.attest.Register(keyID, att, body.Challenge)
	switch {
	case err == nil:
		w.WriteHeader(http.StatusNoContent)
	case errors.Is(err, appattest.ErrCapacity):
		writeError(w, http.StatusInsufficientStorage, "capacity_reached", "attestation capacity reached")
	default:
		s.logger.Printf("attest key rejected: %v", err)
		writeError(w, http.StatusUnauthorized, "attest_invalid", "attestation rejected")
	}
}

func (s *server) attested(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if s.attest == nil || s.attestMode == AttestOff {
			h(w, r)
			return
		}
		data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBody))
		if err != nil {
			var tooLarge *http.MaxBytesError
			if errors.As(err, &tooLarge) {
				writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", "body exceeds 4 KiB")
				return
			}
			writeError(w, http.StatusBadRequest, "bad_request", "could not read body")
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(data))
		keyHdr, assertHdr := r.Header.Get(keyHeader), r.Header.Get(assertionHeader)
		if keyHdr == "" && assertHdr == "" {
			if s.attestMode == AttestRequired {
				writeError(w, http.StatusUnauthorized, "attest_required", "this request needs App Attest")
				return
			}
			if !s.limiter.Allow(ClientIP(r), ClassUnattested) {
				w.Header().Set("Retry-After", "60")
				writeError(w, http.StatusTooManyRequests, "rate_limited", "too many requests")
				return
			}
			h(w, r)
			return
		}
		keyID, err1 := base64.StdEncoding.DecodeString(keyHdr)
		assertion, err2 := base64.StdEncoding.DecodeString(assertHdr)
		if err1 != nil || err2 != nil || len(keyID) != 32 || len(assertion) == 0 {
			writeError(w, http.StatusUnauthorized, "attest_invalid", "assertion rejected")
			return
		}
		switch err := s.attest.Check(keyID, assertion, data); {
		case err == nil:
			h(w, r)
		case errors.Is(err, appattest.ErrUnknownKey):
			writeError(w, http.StatusUnauthorized, "attest_unknown_key", "attest the key again")
		case errors.Is(err, appattest.ErrChallenge):
			writeError(w, http.StatusUnauthorized, "attest_challenge", "challenge missing, used or expired")
		default:
			writeError(w, http.StatusUnauthorized, "attest_invalid", "assertion rejected")
		}
	}
}
