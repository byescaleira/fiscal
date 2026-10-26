package ingest

import (
	"context"
	"path/filepath"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/ibge"
	"liveresults/internal/sources/receita"
)

func (in *Ingest) Overlay(ctx context.Context) (Report, error) {
	in.begin(ctx, "full")
	rep, err := in.overlay(ctx)
	in.end(ctx, rep, err)
	return rep, err
}

func (in *Ingest) overlay(ctx context.Context) (Report, error) {
	start := in.now()
	var rep Report
	in.mu.Lock()
	loaded := in.dataset != nil
	in.mu.Unlock()
	if !loaded {
		if err := in.LoadSnapshot(); err != nil {
			return rep, err
		}
	}
	in.mu.Lock()
	ds := in.dataset
	retain := in.cities
	in.mu.Unlock()
	if paths, ok := in.loadCityPaths(); ok {
		retain = paths
	}
	ds.GeneratedAt = in.now()
	ds.Today = in.today()
	ds.Agenda = in.storedAgenda(ctx, ds.Today)
	in.loadHotState().merge(ds)
	ds.Races = in.races()
	srcs := newSourceSet(in.stamp())
	for id, s := range ds.Sources {
		srcs.keep(id, s.Name, s.URL)
	}
	fresh := func(source string) bool {
		return in.cfg.Enabled(source) && len(in.cfg.Refresh) > 0 && in.cfg.Refresh[source]
	}
	if fresh("ibge") {
		var muns []publicdata.PlaceEntry
		got, err := in.withSource(ctx, &rep, srcs, in.ibgeIO(ctx, &muns))
		switch {
		case err != nil:
			in.warn(&rep, "ibge: %v (kept the municipalities of the last load)", err)
		case got:
			ds.Municipalities = muns
			srcs.add("ibge", "IBGE", ibge.SiteURL, muns)
		default:
			ds.Municipalities = muns
		}
	}
	if fresh("cidades") && len(ds.Municipalities) > 0 {
		ds.Cities = in.storeCities(ctx, &rep, srcs, in.loadCities(ctx, &rep, ds.Municipalities, srcs))
		retain = nil
	}
	if fresh("comprova") {
		ds.Checks = in.storeChecks(ctx, &rep, srcs, in.loadChecks(ctx, &rep, srcs))
	}
	if fresh("repercussao") {
		ds.Signals = in.loadSignals(ctx, &rep, ds, srcs)
	}
	if fresh("anp") || fresh("sidra") {
		ds.Indicators = in.loadIndicators(ctx, &rep, srcs)
	}
	if fresh("receita") {
		var rev *publicdata.RevenueBlock
		got, err := in.withSource(ctx, &rep, srcs, in.receitaIO(ctx, &rev))
		switch {
		case err != nil:
			in.warn(&rep, "receita: %v (kept the revenue of the last load)", err)
		case got && rev != nil:
			ds.Revenue = rev
			srcs.add("receita", "Receita Federal", receita.SiteURL, rev)
		case !got:
			ds.Revenue = rev
		}
	}
	if fresh("historia") {
		in.loadHistory(ctx, &rep, srcs)
	}
	if err := srcs.settle(filepath.Join(in.cfg.DataDir, "sources.json")); err != nil {
		return rep, err
	}
	ds.Sources = srcs.list
	kind := in.cfg.ReleaseKind
	if kind == "" {
		kind = "overlay"
	}
	cities, _, err := in.publish(ctx, kind, ds, &rep, retain)
	if err != nil {
		return rep, err
	}
	if len(cities) == 0 {
		cities = retain
	}
	lite := *ds
	lite.Cities = nil
	in.mu.Lock()
	in.dataset = &lite
	in.cities = cities
	in.mu.Unlock()
	rep.Duration = in.now().Sub(start)
	return rep, nil
}
