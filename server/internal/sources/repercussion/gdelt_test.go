package repercussion

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"reflect"
	"testing"
	"time"

	"liveresults/internal/sources/fetch"
)

type scriptedGetter struct {
	replies []error
	calls   int
}

func (s *scriptedGetter) JSON(_ context.Context, _ string, v any) error {
	i := s.calls
	s.calls++
	if i < len(s.replies) && s.replies[i] != nil {
		return s.replies[i]
	}
	return json.Unmarshal([]byte(`{"timeline":[{"series":"x","data":[{"date":"d","value":3},{"date":"e","value":4}]}]}`), v)
}

func newTestGDELT(get Getter, slept *[]time.Duration) *GDELT {
	clock := time.Date(2026, 10, 26, 12, 0, 0, 0, time.UTC)
	return &GDELT{
		Get:      get,
		Backoffs: []time.Duration{time.Second, 2 * time.Second},
		Now:      func() time.Time { return clock },
		Sleep: func(_ context.Context, d time.Duration) error {
			*slept = append(*slept, d)
			clock = clock.Add(d)
			return nil
		},
	}
}

func TestCountWaitsOutARateLimitBeforeGivingUp(t *testing.T) {
	limited := &fetch.StatusError{Status: http.StatusTooManyRequests}
	var slept []time.Duration
	get := &scriptedGetter{replies: []error{limited, limited}}
	n, err := newTestGDELT(get, &slept).Count(context.Background(), `"x"`)
	if err != nil || n != 7 || get.calls != 3 {
		t.Fatalf("n=%d err=%v calls=%d", n, err, get.calls)
	}
	if !reflect.DeepEqual(slept, []time.Duration{time.Second, 2 * time.Second}) {
		t.Fatalf("slept %v", slept)
	}
}

func TestCountReportsThrottledAfterEveryBackoff(t *testing.T) {
	limited := &fetch.StatusError{Status: http.StatusTooManyRequests}
	var slept []time.Duration
	get := &scriptedGetter{replies: []error{limited, limited, limited}}
	if _, err := newTestGDELT(get, &slept).Count(context.Background(), `"x"`); !errors.Is(err, ErrThrottled) || get.calls != 3 {
		t.Fatalf("err=%v calls=%d", err, get.calls)
	}
}

func TestCountDoesNotRetryOtherErrors(t *testing.T) {
	var slept []time.Duration
	get := &scriptedGetter{replies: []error{&fetch.StatusError{Status: http.StatusBadRequest}}}
	if _, err := newTestGDELT(get, &slept).Count(context.Background(), `"x"`); err == nil || errors.Is(err, ErrThrottled) || get.calls != 1 || len(slept) != 0 {
		t.Fatalf("err=%v calls=%d slept=%v", err, get.calls, slept)
	}
}
