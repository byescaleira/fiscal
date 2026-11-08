package main

import (
	"errors"
	"fmt"
	"testing"

	"liveresults/internal/ingest"
)

func TestSyncExitKeepsAFailureNextToADivergence(t *testing.T) {
	divergence := fmt.Errorf("%w: x", ingest.ErrDivergence)
	cases := []struct {
		failed bool
		err    error
		want   int
	}{
		{false, nil, 0},
		{true, nil, 1},
		{false, errors.New("x"), 1},
		{false, divergence, exitDivergence},
		{true, divergence, exitDivergenceAndFailure},
	}
	for _, c := range cases {
		if got := syncExit(c.failed, c.err); got != c.want {
			t.Errorf("syncExit(%v, %v) = %d, want %d", c.failed, c.err, got, c.want)
		}
	}
}
