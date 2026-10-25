package ingest

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/comprova"
)

const (
	checksStoreFile  = "comprova.json"
	checksReviewFile = "checks-review.json"
)

func (in *Ingest) loadChecks(ctx context.Context, rep *Report, srcs *sourceSet) []publicdata.RawCheck {
	path := filepath.Join(in.cfg.DataDir, checksStoreFile)
	prev, err := comprova.LoadStore(path)
	if err != nil {
		in.warn(rep, "comprova: %v (reading again from the start)", err)
		prev = nil
	}
	client := comprova.Client{Get: in.get, Since: in.cfg.ChecksSince, MaxPages: in.cfg.ChecksMaxPages, Now: in.now}
	store, st, err := client.Update(ctx, prev)
	if err != nil {
		if prev == nil {
			in.warn(rep, "comprova: %v (no fact checks published)", err)
			return nil
		}
		in.warn(rep, "comprova: %v (kept the checks from the last load)", err)
		store = *prev
	} else {
		if err := comprova.SaveStore(path, store); err != nil {
			in.warn(rep, "comprova store: %v", err)
		}
		in.logger.Printf("comprova: full=%v pages=%d posts=%d skipped=%d stored=%d", st.Full, st.Pages, st.Fetched, st.Skipped, len(store.Checks))
	}
	checks := make([]publicdata.RawCheck, 0, len(store.Checks))
	for _, c := range store.Checks {
		checks = append(checks, publicdata.RawCheck{
			ID: "comprova-" + strconv.FormatInt(c.ID, 10), Source: "comprova", Title: c.Title, Texts: c.Explanations,
			Verdict: c.Verdict, Conflict: c.Conflict, Date: c.Date, URL: c.URL,
			Publisher: comprova.Name, License: comprova.License, LicenseURL: comprova.LicenseURL,
		})
	}
	srcs.add("comprova", comprova.Name, comprova.SiteURL, checks)
	return checks
}

type checkReviewFile struct {
	GeneratedAt string                   `json:"generatedAt"`
	Items       []publicdata.CheckReview `json:"items"`
}

func (in *Ingest) writeCheckReview(items []publicdata.CheckReview) error {
	path := filepath.Join(in.cfg.DataDir, checksReviewFile)
	body, err := json.Marshal(items)
	if err != nil {
		return err
	}
	if old, err := os.ReadFile(path); err == nil {
		var prev struct {
			Items json.RawMessage `json:"items"`
		}
		var compact bytes.Buffer
		if json.Unmarshal(old, &prev) == nil && json.Compact(&compact, prev.Items) == nil && bytes.Equal(compact.Bytes(), body) {
			return nil
		}
	}
	data, err := json.MarshalIndent(checkReviewFile{GeneratedAt: in.now().UTC().Format(time.RFC3339), Items: items}, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(in.cfg.DataDir, 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
