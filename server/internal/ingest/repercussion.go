package ingest

import (
	"context"
	"errors"
	"path/filepath"
	"sort"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/repercussion"
)

const (
	repercussionStoreFile = "repercussion.json"
	defaultNewsBudget     = 120
	repercussionKeep      = 14 * 24 * time.Hour
)

func (in *Ingest) newsBudget() int {
	if in.cfg.NewsBudget > 0 {
		return in.cfg.NewsBudget
	}
	return defaultNewsBudget
}

func (in *Ingest) loadSignals(ctx context.Context, rep *Report, ds *publicdata.Dataset, srcs *sourceSet) *publicdata.Signals {
	path := filepath.Join(in.cfg.DataDir, repercussionStoreFile)
	store, err := repercussion.LoadStore(path)
	if err != nil {
		in.warn(rep, "repercussion store: %v (measuring again)", err)
		store = repercussion.NewStore()
	}
	now := in.now()
	stamp := now.UTC().Format(time.RFC3339)
	store.Prune(now, repercussionKeep)
	plan := publicdata.PlanSignals(ds)
	sig := &publicdata.Signals{
		WindowEnd:  now.UTC().AddDate(0, 0, -1).Format("2006-01-02"),
		News:       map[string]int64{},
		PersonNews: map[string]int64{},
		Wiki:       map[string]int64{},
		ThemeWiki:  map[string]int64{},
	}
	wikiOK := in.loadWiki(ctx, rep, plan.People, store, sig, now, stamp)
	newsOK := in.loadNews(ctx, rep, plan, store, sig, now, stamp)
	if err := store.Save(path); err != nil {
		in.warn(rep, "repercussion store: %v", err)
	}
	if newsOK {
		srcs.add("gdelt", repercussion.GDELTName, repercussion.GDELTSite, []any{sig.News, sig.PersonNews})
		sig.Sources = append(sig.Sources, "gdelt")
	}
	if wikiOK {
		srcs.add("wikipedia", repercussion.WikiName, repercussion.WikiSite, []any{sig.Wiki, sig.ThemeWiki})
		sig.Sources = append(sig.Sources, "wikipedia")
	}
	in.logger.Printf("repercussion: propositions=%d people=%d news=%d personNews=%d wiki=%d themes=%d", len(plan.Propositions), len(plan.People), len(sig.News), len(sig.PersonNews), len(sig.Wiki), len(sig.ThemeWiki))
	return sig
}

func (in *Ingest) loadWiki(ctx context.Context, rep *Report, people []*publicdata.Person, store *repercussion.Store, sig *publicdata.Signals, now time.Time, stamp string) bool {
	w := repercussion.Wiki{Get: in.get}
	var pending []string
	seen := map[string]bool{}
	for _, p := range people {
		for _, n := range []string{p.Name, p.CivilName} {
			if n == "" || seen[n] {
				continue
			}
			seen[n] = true
			if t, ok := store.Titles[n]; ok && freshAt(t.FetchedAt, repercussion.TitleTTL, now) {
				continue
			}
			pending = append(pending, n)
		}
	}
	if len(pending) > 0 {
		found, err := w.Resolve(ctx, pending, true)
		for n, t := range found {
			store.Titles[n] = repercussion.Title{Title: t, FetchedAt: stamp}
		}
		if err != nil {
			in.warn(rep, "wikipedia titles: %v (kept the titles already known)", err)
		}
	}
	end := now.UTC().AddDate(0, 0, -1)
	failed := false
	views := func(title string) (int64, bool) {
		if c, ok := store.Views[title]; ok && (failed || freshAt(c.FetchedAt, repercussion.ViewsTTL, now)) {
			return c.Value, true
		}
		if failed {
			return 0, false
		}
		n, err := w.Count(ctx, title, end)
		if err != nil {
			failed = true
			in.warn(rep, "wikipedia pageviews: %v (kept the counts already known)", err)
			if c, ok := store.Views[title]; ok {
				return c.Value, true
			}
			return 0, false
		}
		store.Views[title] = repercussion.Count{Value: n, FetchedAt: stamp}
		return n, true
	}
	for _, p := range people {
		title := store.Titles[p.Name].Title
		if title == "" && p.CivilName != "" {
			title = store.Titles[p.CivilName].Title
		}
		if title == "" {
			continue
		}
		if n, ok := views(title); ok {
			sig.Wiki[publicdata.PersonSignalKey(p)] = n
		}
	}
	articles := publicdata.ThemeArticles()
	keys := make([]string, 0, len(articles))
	for k := range articles {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		if n, ok := views(articles[k]); ok {
			sig.ThemeWiki[k] = n
		}
	}
	return len(sig.Wiki) > 0 || len(sig.ThemeWiki) > 0
}

func (in *Ingest) loadNews(ctx context.Context, rep *Report, plan publicdata.SignalPlan, store *repercussion.Store, sig *publicdata.Signals, now time.Time, stamp string) bool {
	g := &repercussion.GDELT{Get: in.get, Limit: in.newsBudget(), Now: in.now}
	throttled := false
	measure := func(query string) (int64, bool) {
		c, cached := store.News[query]
		if cached && freshAt(c.FetchedAt, repercussion.NewsTTL, now) {
			return c.Value, true
		}
		if throttled || g.Exhausted() {
			return c.Value, cached
		}
		n, err := g.Count(ctx, query)
		if err != nil {
			if errors.Is(err, repercussion.ErrThrottled) && !g.Exhausted() {
				throttled = true
				in.warn(rep, "gdelt: rate limited (kept the counts already known)")
			} else if !errors.Is(err, repercussion.ErrThrottled) {
				in.warn(rep, "gdelt %q: %v", query, err)
			}
			return c.Value, cached
		}
		store.News[query] = repercussion.Count{Value: n, FetchedAt: stamp}
		return n, true
	}
	share := in.newsBudget() * 2 / 3
	for i, label := range plan.Propositions {
		q := repercussion.Phrase(label)
		if q == "" {
			continue
		}
		if i >= share {
			if c, ok := store.News[q]; ok {
				sig.News[publicdata.PropositionKey(label)] = c.Value
			}
			continue
		}
		if n, ok := measure(q); ok {
			sig.News[publicdata.PropositionKey(label)] = n
		}
	}
	for _, p := range plan.People {
		q := repercussion.Phrase(p.Name)
		if q == "" {
			continue
		}
		if n, ok := measure(q); ok {
			sig.PersonNews[publicdata.PersonSignalKey(p)] = n
		}
	}
	return len(sig.News) > 0 || len(sig.PersonNews) > 0
}

func freshAt(at string, ttl time.Duration, now time.Time) bool {
	t, err := time.Parse(time.RFC3339, at)
	return err == nil && now.Sub(t) < ttl
}
