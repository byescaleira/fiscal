package main

import (
	"context"
	"errors"
	"log"
	"time"

	"liveresults/internal/datastore"
	"liveresults/internal/ingest"
)

const exitDivergence = 3

func planCommand(cfg config) int {
	in := ingest.New(cfg.ingest, nil, nil, nil)
	st := in.LoadSyncState()
	for _, d := range in.Plan(time.Now(), st, nil) {
		log.Print(d.String())
	}
	return 0
}

func runSync(ctx context.Context, in *ingest.Ingest, db *datastore.Store, cfg config, job string) int {
	force := map[string]bool{}
	if job != "" {
		force[job] = true
	}
	hooks := ingest.SyncHooks{
		AfterSources: func(ctx context.Context, j ingest.Job) {
			if err := in.SaveSnapshot(); err != nil {
				log.Printf("snapshot: %v (the next derived run waits for another phase)", err)
			}
			backup(ctx, db, in, cfg)
		},
		BeforeHeavy: func(ctx context.Context, j ingest.Job) error {
			if job != "" {
				_, err := cfg.capacity.WaitFor(ctx)
				return err
			}
			c := cfg.capacity
			c.Wait = 0
			_, err := c.WaitFor(ctx)
			return err
		},
	}
	var outcomes []ingest.Outcome
	var err error
	if job != "" {
		outcomes, err = in.RunJob(ctx, job, hooks)
	} else {
		outcomes, err = in.Sync(ctx, force, hooks)
	}
	failed := false
	for _, o := range outcomes {
		status := "ok"
		if o.Err != nil {
			status = "failed: " + o.Err.Error()
			failed = failed || !errors.Is(o.Err, ingest.ErrDivergence)
		}
		log.Printf("job %s: %s (%s, changed=%d, release=%s, %s)", o.Job, o.Result, status, o.Changed, o.Release, o.Duration.Round(time.Millisecond))
	}
	if len(outcomes) == 0 && err == nil {
		log.Printf("sync: nothing due")
	}
	switch {
	case errors.Is(err, ingest.ErrDivergence):
		return exitDivergence
	case err != nil:
		log.Printf("sync: %v", err)
		return 1
	case failed:
		return 1
	}
	return 0
}
