package ingest

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"liveresults/internal/publicdata"
	"liveresults/internal/publish"
	"liveresults/internal/sources/fetch"
	"liveresults/internal/sources/ibge"
)

type Fetcher interface {
	JSON(ctx context.Context, rawURL string, v any) error
	JSONHeader(ctx context.Context, rawURL string, v any) (http.Header, error)
	Cache(ctx context.Context, rawURL string, limit int64) (fetch.Cached, error)
	Open(ctx context.Context, rawURL string) (*fetch.Remote, error)
}

type Config struct {
	PublicDir         string
	DataDir           string
	Years             []int
	TSEYears          []int
	TSECandidateYears []int
	UFs               []string
	Sources           map[string]bool
	Workers           int
	ChecksSince       string
	ChecksMaxPages    int
}

func (c Config) Enabled(source string) bool {
	if len(c.Sources) == 0 {
		return true
	}
	return c.Sources[source]
}

func (c Config) wantUF(uf string) bool {
	if len(c.UFs) == 0 {
		return true
	}
	uf = strings.ToLower(uf)
	for _, u := range c.UFs {
		if u == uf {
			return true
		}
	}
	return false
}

func (c Config) tseUFs() []string {
	if len(c.UFs) == 0 {
		return nil
	}
	out := []string{"br"}
	for _, u := range c.UFs {
		if u != "br" {
			out = append(out, u)
		}
	}
	return out
}

type Ingest struct {
	cfg    Config
	get    Fetcher
	now    func() time.Time
	logger *log.Logger
	loc    *time.Location

	mu      sync.Mutex
	dataset *publicdata.Dataset
}

func New(cfg Config, get Fetcher, now func() time.Time, logger *log.Logger) *Ingest {
	if now == nil {
		now = time.Now
	}
	if logger == nil {
		logger = log.Default()
	}
	if cfg.Workers <= 0 {
		cfg.Workers = 4
	}
	loc, err := time.LoadLocation("America/Sao_Paulo")
	if err != nil {
		loc = time.FixedZone("BRT", -3*3600)
	}
	return &Ingest{cfg: cfg, get: get, now: now, logger: logger, loc: loc}
}

func (in *Ingest) today() string {
	return in.now().In(in.loc).Format("2006-01-02")
}

func (in *Ingest) stamp() string {
	return in.now().In(in.loc).Format(time.RFC3339)
}

type sourceSet struct {
	mu     sync.Mutex
	at     string
	list   map[string]publicdata.Source
	hashes map[string]string
}

func newSourceSet(at string) *sourceSet {
	return &sourceSet{at: at, list: map[string]publicdata.Source{}, hashes: map[string]string{}}
}

func (s *sourceSet) add(id, name, url string, data any) {
	sum := sha256.New()
	json.NewEncoder(sum).Encode(data)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.list[id] = publicdata.Source{ID: id, Name: name, URL: url, UpdatedAt: s.at}
	s.hashes[id] = hex.EncodeToString(sum.Sum(nil))
}

type sourceState struct {
	Hash      string `json:"hash"`
	UpdatedAt string `json:"updatedAt"`
}

func (s *sourceSet) settle(path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	prev := map[string]sourceState{}
	if data, err := os.ReadFile(path); err == nil {
		json.Unmarshal(data, &prev)
	}
	next := map[string]sourceState{}
	for id, src := range s.list {
		h := s.hashes[id]
		if p, ok := prev[id]; ok && p.Hash == h && p.UpdatedAt != "" {
			src.UpdatedAt = p.UpdatedAt
			s.list[id] = src
		}
		next[id] = sourceState{Hash: h, UpdatedAt: s.list[id].UpdatedAt}
	}
	for id, p := range prev {
		if _, ok := next[id]; !ok {
			next[id] = p
		}
	}
	data, err := json.Marshal(next)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

type Report struct {
	People      int
	Votes       int
	Checks      int
	CheckPeople int
	CheckLinks  int
	Reviews     int
	Files       int
	Written     int
	Removed     int
	Bytes       int64
	Gzip        int64
	Duration    time.Duration
	Warnings    []string
}

func (in *Ingest) warn(r *Report, format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	in.logger.Printf("warning: %s", msg)
	in.mu.Lock()
	r.Warnings = append(r.Warnings, msg)
	in.mu.Unlock()
}

func (in *Ingest) Full(ctx context.Context) (Report, error) {
	start := in.now()
	var rep Report
	srcs := newSourceSet(in.stamp())
	ds := &publicdata.Dataset{GeneratedAt: in.now(), Today: in.today(), Years: in.cfg.Years}
	for _, s := range ibge.States {
		ds.States = append(ds.States, publicdata.PlaceEntry{Code: strings.ToLower(s.UF), Name: s.Name, UF: strings.ToLower(s.UF)})
	}
	if in.cfg.Enabled("ibge") {
		muns, err := in.loadIBGE(ctx)
		if err != nil {
			return rep, fmt.Errorf("ibge: %w", err)
		}
		ds.Municipalities = muns
		srcs.add("ibge", "IBGE", ibge.SiteURL, muns)
	}
	var people []*publicdata.Person
	if in.cfg.Enabled("camara") {
		cam, err := in.loadCamara(ctx, &rep)
		if err != nil {
			return rep, fmt.Errorf("camara: %w", err)
		}
		people = append(people, cam.people...)
		ds.Votes = append(ds.Votes, cam.votes...)
		ds.Laws = append(ds.Laws, cam.laws...)
		ds.Quota.FederalDeputies = cam.quotaTotal
		mergeCategories(&ds.Quota, cam.quotaByCategory)
		srcs.add("camara", "Câmara dos Deputados", "https://dadosabertos.camara.leg.br", []any{cam.people, cam.votes, cam.laws, cam.quotaTotal, cam.quotaByCategory})
	}
	if in.cfg.Enabled("senado") {
		sen, err := in.loadSenado(ctx, &rep)
		if err != nil {
			return rep, fmt.Errorf("senado: %w", err)
		}
		people = append(people, sen.people...)
		ds.Votes = append(ds.Votes, sen.votes...)
		ds.Quota.Senators = sen.quotaTotal
		mergeCategories(&ds.Quota, sen.quotaByCategory)
		srcs.add("senado", "Senado Federal", "https://legis.senado.leg.br/dadosabertos", []any{sen.people, sen.votes, sen.quotaTotal, sen.quotaByCategory})
	}
	ds.Quota.Year = in.currentYear()
	states := map[string]string{"br": "Brasil"}
	for _, s := range ds.States {
		states[s.Code] = s.Name
	}
	var cands []publicdata.Candidacy
	var campaigns *publicdata.CampaignTotals
	if in.cfg.Enabled("tse") {
		t, err := in.loadTSE(ctx, &rep)
		if err != nil {
			return rep, fmt.Errorf("tse: %w", err)
		}
		cands = t.candidacies
		campaigns = t.campaigns
		srcs.add("tse", "Tribunal Superior Eleitoral", "https://dadosabertos.tse.jus.br", []any{t.candidacies, t.campaigns})
	}
	prev, next := electionYears(in.cfg.TSEYears)
	people = publicdata.Link(publicdata.LinkInput{People: people, Candidacies: cands, PreviousYear: prev, ElectionYear: next, StateNames: states})
	people = in.filterScope(people)
	if in.cfg.Enabled("assembleias") {
		people = in.loadAssemblies(ctx, &rep, people, cands, prev, states, srcs)
	}
	ds.Campaigns = campaigns
	if in.cfg.Enabled("receita") {
		rev, err := in.loadReceita(ctx)
		if err != nil {
			in.warn(&rep, "receita: %v (revenue published as null)", err)
		} else if rev != nil {
			ds.Revenue = rev
			srcs.add("receita", "Receita Federal", "https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/dados-abertos", rev)
		}
	}
	ds.Salaries, ds.SalarySource = salaries()
	srcs.add("legislacao", salaryLaw, salaryLawURL, ds.Salaries)
	for _, p := range people {
		applyCoverage(p)
	}
	ds.People = people
	if in.cfg.Enabled("comprova") {
		ds.Checks = in.loadChecks(ctx, &rep, srcs)
	}
	if err := srcs.settle(filepath.Join(in.cfg.DataDir, "sources.json")); err != nil {
		return rep, err
	}
	ds.Sources = srcs.list
	in.refreshLive(ctx, ds, &rep)
	if err := in.publish(ds, &rep); err != nil {
		return rep, err
	}
	in.mu.Lock()
	in.dataset = ds
	in.mu.Unlock()
	rep.Duration = in.now().Sub(start)
	return rep, nil
}

func (in *Ingest) Live(ctx context.Context) (Report, error) {
	var rep Report
	in.mu.Lock()
	ds := in.dataset
	in.mu.Unlock()
	if ds == nil {
		return rep, errors.New("live: no full load yet")
	}
	ds.GeneratedAt = in.now()
	ds.Today = in.today()
	in.refreshLive(ctx, ds, &rep)
	return rep, in.publish(ds, &rep)
}

func (in *Ingest) publish(ds *publicdata.Dataset, rep *Report) error {
	slugs, err := publicdata.LoadSlugs(filepath.Join(in.cfg.DataDir, "slugs.json"))
	if err != nil {
		return err
	}
	out := publicdata.Build(ds, slugs)
	tree := publish.NewTree(filepath.Join(in.cfg.PublicDir, "v1"))
	if err := publicdata.Publish(out, tree, true); err != nil {
		return err
	}
	if in.cfg.Enabled("comprova") {
		if err := in.writeCheckReview(out.Reviews); err != nil {
			in.warn(rep, "checks review: %v", err)
		}
	}
	rep.Checks, rep.CheckPeople, rep.CheckLinks, rep.Reviews = len(ds.Checks), 0, 0, len(out.Reviews)
	for _, f := range out.Files {
		if l, ok := f.Value.(publicdata.CheckList); ok {
			rep.CheckPeople++
			rep.CheckLinks += len(l.Items)
		}
	}
	if err := slugs.Save(); err != nil {
		return err
	}
	st := tree.Stats()
	rep.People = len(ds.People)
	rep.Votes = len(ds.Votes)
	rep.Files, rep.Written, rep.Removed, rep.Bytes, rep.Gzip = st.Files, st.Written, st.Removed, st.Bytes, st.GzipBytes
	return nil
}

func (in *Ingest) currentYear() int {
	return in.now().In(in.loc).Year()
}

func (in *Ingest) filterScope(people []*publicdata.Person) []*publicdata.Person {
	var out []*publicdata.Person
	for _, p := range people {
		if len(p.Roles) == 0 {
			continue
		}
		r := p.Primary()
		if r.UF != "br" && !in.cfg.wantUF(r.UF) {
			continue
		}
		out = append(out, p)
	}
	return out
}

func electionYears(years []int) (int, int) {
	ys := append([]int(nil), years...)
	sort.Ints(ys)
	switch len(ys) {
	case 0:
		return 0, 0
	case 1:
		return ys[0], ys[0]
	}
	return ys[len(ys)-2], ys[len(ys)-1]
}

func mergeCategories(q *publicdata.QuotaTotals, cats map[string]int64) {
	if q.ByCategory == nil {
		q.ByCategory = map[string]int64{}
	}
	for k, v := range cats {
		q.ByCategory[k] += v
	}
}

const (
	salaryLaw    = "Decreto Legislativo nº 172/2022"
	salaryLawURL = "https://www2.camara.leg.br/legin/fed/decleg/2022/decretolegislativo-172-21-dezembro-2022-793529-publicacaooriginal-166604-pl.html"
	federalPay   = 4636619
)

func salaries() ([]publicdata.OfficeSalary, map[string]string) {
	offices := []string{publicdata.OfficePresident, publicdata.OfficeVicePresident, publicdata.OfficeSenator, publicdata.OfficeFederalDeputy}
	var out []publicdata.OfficeSalary
	src := map[string]string{}
	for _, o := range offices {
		out = append(out, publicdata.OfficeSalary{Office: o, MonthlyCents: federalPay, Law: salaryLaw})
		src[o] = "legislacao"
	}
	return out, src
}

func applyCoverage(p *publicdata.Person) {
	if p.Coverage == nil {
		p.Coverage = map[string]publicdata.Coverage{}
	}
	set := func(kind, status, source string) {
		if _, ok := p.Coverage[kind]; ok {
			return
		}
		p.Coverage[kind] = publicdata.Coverage{Kind: kind, Status: status, Source: source}
	}
	office := p.Primary().Office
	switch {
	case p.House == publicdata.HouseCamara:
		for _, k := range []string{"votes", "proposals", "speeches", "expenses"} {
			set(k, publicdata.CoverageAvailable, "camara")
		}
		set("attendance", publicdata.CoverageAvailable, "camara")
	case p.House == publicdata.HouseSenado:
		set("attendance", publicdata.CoverageNotPublished, "senado")
		for _, k := range []string{"votes", "proposals", "speeches", "expenses"} {
			set(k, publicdata.CoverageAvailable, "senado")
		}
	case office == publicdata.OfficeStateDeputy:
		src := "assembleia-" + p.Primary().UF
		if p.Assembly != "" {
			set("proposals", publicdata.CoverageAvailable, p.Assembly)
			src = p.Assembly
		}
		for _, k := range []string{"attendance", "votes", "proposals", "speeches", "expenses"} {
			set(k, publicdata.CoverageNotPublished, src)
		}
	}
	assets, campaigns := false, false
	for _, c := range p.Candidacies {
		assets = assets || c.AssetsLoaded
		campaigns = campaigns || c.RevenueCents != nil || c.ExpenseCents != nil
	}
	if assets {
		set("assets", publicdata.CoverageAvailable, "tse")
	} else {
		set("assets", publicdata.CoverageNotLoaded, "tse")
	}
	if campaigns {
		set("campaigns", publicdata.CoverageAvailable, "tse")
	} else {
		set("campaigns", publicdata.CoverageNotLoaded, "tse")
	}
	if publicdata.Federal(office) {
		set("salary", publicdata.CoverageAvailable, "legislacao")
	} else {
		set("salary", publicdata.CoverageNotLoaded, "legislacao")
	}
}
