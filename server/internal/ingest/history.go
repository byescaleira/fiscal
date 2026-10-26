package ingest

import (
	"archive/zip"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"liveresults/internal/datastore"
	"liveresults/internal/history"
	"liveresults/internal/publish"
	"liveresults/internal/sources/tse"
)

const (
	historyCacheVersion  = "7"
	historyIndicatorFile = "history-indicators.json"
)

func DefaultHistoryYears() []int {
	years := []int{tse.UFOnlyYear, tse.UFOnlyYear + 1}
	for y := tse.FirstMunZoneYear; y <= 2022; y += 4 {
		years = append(years, y)
	}
	return years
}

type historyCache struct {
	Version string         `json:"version"`
	Races   []history.Race `json:"races"`
}

func (in *Ingest) historyCachePath(year int) string {
	return filepath.Join(in.cfg.DataDir, "cache", "history", fmt.Sprintf("elections-%d.json", year))
}

func (in *Ingest) readHistoryCache(year int) (historyCache, bool) {
	var c historyCache
	data, err := os.ReadFile(in.historyCachePath(year))
	if err != nil || json.Unmarshal(data, &c) != nil || c.Version == "" || len(c.Races) == 0 {
		return c, false
	}
	return c, true
}

func writePrivateJSON(path string, v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func historySources(year int) []history.Ref {
	url := history.DatasetURL(year)
	return []history.Ref{{ID: "tse", Name: fmt.Sprintf("Tribunal Superior Eleitoral, Resultados %d (dados abertos)", year), URL: &url}}
}

func (in *Ingest) electionYear(ctx context.Context, year int) ([]history.Race, error) {
	votesURL, turnoutURL := tse.VotesURL(year), tse.TurnoutURL(year)
	if year < tse.FirstMunZoneYear {
		votesURL, turnoutURL = tse.UFVotesURL(year), tse.UFTurnoutURL(year)
	}
	votes, err := in.get.Open(ctx, votesURL)
	if err != nil {
		return nil, err
	}
	turnout, err := in.get.Open(ctx, turnoutURL)
	if err != nil {
		return nil, err
	}
	version := votes.Version() + "|" + turnout.Version() + "#" + historyCacheVersion
	if c, ok := in.readHistoryCache(year); ok && c.Version == version {
		return c.Races, nil
	}
	tally := history.NewTally(year)
	vz, err := votes.Zip()
	if err != nil {
		return nil, err
	}
	tz, err := turnout.Zip()
	if err != nil {
		return nil, err
	}
	if year < tse.FirstMunZoneYear {
		for round, date := range ufRoundDates[year] {
			tally.SetDate(round, date)
		}
		if err := eachText(vz, "VOTACAO_CANDIDATO_UF", func(r io.Reader) error {
			return tse.ReadUFVotes(r, tally.Vote)
		}); err != nil {
			return nil, err
		}
		if err := eachText(tz, "DETALHE_VOTACAO_UF", func(r io.Reader) error {
			return tse.ReadUFTurnout(r, tally.Turnout)
		}); err != nil {
			return nil, err
		}
	} else {
		if err := readMunZone(vz, "votacao_candidato_munzona", year, func(r io.Reader, keep func(int) bool) error {
			return tse.ReadMajoritarianVotes(r, func(v tse.VoteRow) {
				if keep(v.Office) {
					tally.Vote(v)
				}
			})
		}); err != nil {
			return nil, err
		}
		if err := readMunZone(tz, "detalhe_votacao_munzona", year, func(r io.Reader, keep func(int) bool) error {
			return tse.ReadTurnout(r, func(t tse.TurnoutRow) {
				if keep(t.Office) {
					tally.Turnout(t)
				}
			})
		}); err != nil {
			return nil, err
		}
	}
	if tally.NeedsResults() {
		if err := in.fillResults(ctx, year, tally); err != nil {
			in.logger.Printf("warning: history %d: results missing in the vote file and the candidates file failed: %v", year, err)
		}
	}
	if bad := tally.Mismatches(); len(bad) > 0 {
		in.logger.Printf("warning: history %d: valid votes differ from the detail file in %d races: %s", year, len(bad), strings.Join(bad, "; "))
	}
	races := tally.Races(historySources(year))
	if len(races) == 0 {
		return nil, errors.New("no majoritarian race in the files")
	}
	in.logger.Printf("history %d: %d races, %s over HTTP range", year, len(races), humanBytes(votes.BytesRead()+turnout.BytesRead()))
	if err := writePrivateJSON(in.historyCachePath(year), historyCache{Version: version, Races: races}); err != nil {
		in.logger.Printf("warning: history cache %d: %v", year, err)
	}
	return races, nil
}

func readMunZone(zr *zip.Reader, prefix string, year int, read func(r io.Reader, keep func(int) bool) error) error {
	if whole := tse.WholeCountry(zr, prefix, year); whole != nil {
		return tse.EachEntry([]*zip.File{whole}, func(_ string, r io.Reader) error {
			return read(r, func(int) bool { return true })
		})
	}
	files := tse.Entries(zr, prefix, year, nil)
	if len(files) == 0 {
		return errors.New("no matching CSV inside the ZIP")
	}
	return tse.EachEntry(files, func(name string, r io.Reader) error {
		national := strings.HasSuffix(strings.ToUpper(name), "_BR.CSV")
		return read(r, func(office int) bool { return (office == tse.President) == national })
	})
}

func (in *Ingest) fillResults(ctx context.Context, year int, tally *history.Tally) error {
	cands, err := cached(ctx, in, "consulta_cand", year, nil, tse.CandidatesURL(year), func(r io.Reader, out *[]tse.Candidate) error {
		return tse.ReadCandidates(r, func(c tse.Candidate) { *out = append(*out, c) })
	})
	if err != nil {
		return err
	}
	type key struct {
		sq    string
		round int
	}
	type seat struct {
		office, scope, number string
		round                 int
	}
	bySQ := map[key]string{}
	byNumber := map[seat]string{}
	for _, c := range cands {
		office, ok := history.OfficeOf(c.Office)
		if !ok || c.Result == "" {
			continue
		}
		scope := strings.ToLower(c.UF)
		if office == history.OfficePresident {
			scope = history.ScopeBrazil
		}
		bySQ[key{c.SQ, c.Round}] = c.Result
		byNumber[seat{office, scope, c.Number, c.Round}] = c.Result
	}
	filled := tally.FillResults(func(office, scope string, round int, sq, number string) string {
		if r := bySQ[key{sq, round}]; r != "" {
			return r
		}
		return byNumber[seat{office, scope, number, round}]
	})
	in.logger.Printf("history %d: filled %d results from the candidates file", year, filled)
	return nil
}

var ufRoundDates = map[int]map[int]string{
	1989: {1: "1989-11-15", 2: "1989-12-17"},
	1990: {1: "1990-10-03", 2: "1990-11-25"},
}

func eachText(zr *zip.Reader, contains string, fn func(io.Reader) error) error {
	read := 0
	for _, f := range zr.File {
		up := strings.ToUpper(f.Name)
		if !strings.Contains(up, contains) || !strings.HasSuffix(up, ".TXT") {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return err
		}
		err = fn(rc)
		rc.Close()
		if err != nil {
			return fmt.Errorf("%s: %w", f.Name, err)
		}
		read++
	}
	if read == 0 {
		return fmt.Errorf("no %s file inside the ZIP", contains)
	}
	return nil
}

type historyIndicators struct {
	Series history.IndicatorSet `json:"series"`
}

func (in *Ingest) historyIndicators(ctx context.Context, rep *Report) history.IndicatorSet {
	path := filepath.Join(in.cfg.DataDir, historyIndicatorFile)
	var prev historyIndicators
	if data, err := os.ReadFile(path); err == nil {
		json.Unmarshal(data, &prev)
	}
	next := history.IndicatorSet{}
	for id, pts := range prev.Series {
		next[id] = pts
	}
	changed := false
	for _, spec := range history.Series {
		var resp history.IpeaResponse
		if err := in.get.JSON(ctx, fmt.Sprintf(history.IpeaAPI, spec.Code), &resp); err != nil {
			in.warn(rep, "ipeadata %s: %v (kept the last read)", spec.Code, err)
			continue
		}
		pts := history.AnnualPoints(spec, resp.Value)
		if len(pts) < 5 {
			in.warn(rep, "ipeadata %s: only %d points (kept the last read)", spec.Code, len(pts))
			continue
		}
		next[spec.ID], changed = pts, true
	}
	if changed {
		if err := writePrivateJSON(path, historyIndicators{Series: next}); err != nil {
			in.warn(rep, "history indicators store: %v", err)
		}
	}
	return next
}

func (in *Ingest) loadHistory(ctx context.Context, rep *Report, srcs *sourceSet) {
	t := in.track(ctx, "historia")
	var races []history.Race
	var gaps []history.Gap
	years := append([]int(nil), in.cfg.HistoryYears...)
	sort.Ints(years)
	failed := 0
	for _, y := range years {
		got, err := in.electionYear(ctx, y)
		if err != nil {
			if c, ok := in.readHistoryCache(y); ok {
				in.warn(rep, "history %d: %v (published the last read)", y, err)
				got = c.Races
			} else {
				in.warn(rep, "history %d: %v", y, err)
				failed++
				gaps = append(gaps, history.Gap{Year: y, Office: history.OfficePresident, Reason: "O arquivo do TSE não pôde ser lido nesta carga; o ano volta na próxima."})
				continue
			}
		}
		races = append(races, got...)
	}
	gaps = append(gaps, staticGaps(years)...)
	series := in.historyIndicators(ctx, rep)
	timeline, terr := history.BuildTimeline(series)
	if terr != nil {
		in.warn(rep, "history periods: %v", terr)
	}
	study, serr := history.BuildStudy()
	if serr != nil {
		in.warn(rep, "history study: %v", serr)
	}
	tree := publish.NewTree(filepath.Join(in.cfg.PublicDir, "v1"))
	var werr error
	write := func(rel string, v any) {
		if werr == nil {
			werr = tree.WriteJSON(rel, v)
		}
	}
	if len(races) > 0 {
		var ys []int
		seen := map[int]bool{}
		for _, r := range races {
			write(history.RacePath(r.ID), r)
			if !seen[r.Year] {
				seen[r.Year] = true
				ys = append(ys, r.Year)
			}
		}
		sort.Ints(ys)
		sort.Slice(gaps, func(i, j int) bool { return gaps[i].Year < gaps[j].Year })
		write(history.IndexPath, history.Index{Years: ys, Races: history.Summarize(races), Gaps: gaps, Method: electionMethod, Sources: indexSources(ys)})
		srcs.add("tse-historico", "Tribunal Superior Eleitoral, resultados de eleições anteriores", tse.SiteURL, history.Summarize(races))
	}
	if terr == nil {
		write(history.PeriodsPath, timeline)
		if len(series) > 0 {
			srcs.add("ipeadata", history.IpeaName, history.IpeaSiteURL, series)
		}
	}
	if serr == nil {
		write(history.StudyPath, study)
	}
	if werr == nil && len(races) > 0 && terr == nil && serr == nil {
		werr = tree.Prune("history")
	}
	status := datastore.StatusOK
	switch {
	case werr != nil || (len(races) == 0 && len(years) > 0):
		status = datastore.StatusFailed
	case failed > 0 || terr != nil || serr != nil:
		status = datastore.StatusFallback
	}
	if werr != nil {
		in.warn(rep, "history publish: %v", werr)
	}
	st := tree.Stats()
	in.logger.Printf("history: %d races, %d files (%d written, %d removed)", len(races), st.Files, st.Written, st.Removed)
	t.done(ctx, status, map[string]int{"races": len(races), "files": st.Files}, werr)
}

var electionMethod = []string{
	"Votos somados dos arquivos de votação por município e zona do TSE (de 1994 a 2022) e por UF (1989 e 1990).",
	"A porcentagem de cada candidato é sobre os votos válidos dados a candidatos, como o TSE divulga; brancos e nulos ficam de fora.",
	"Comparecimento, abstenção, brancos e nulos vêm do arquivo de detalhe da apuração do mesmo ano.",
	"Candidatos com votos anulados pela Justiça Eleitoral aparecem com os votos válidos e, à parte, os anulados.",
}

func staticGaps(years []int) []history.Gap {
	var out []history.Gap
	for _, y := range years {
		if y == tse.UFOnlyYear {
			out = append(out,
				history.Gap{Year: y, Office: history.OfficeGovernor, Reason: "Em 1989 só houve eleição para presidente."},
				history.Gap{Year: y, Office: history.OfficeSenator, Reason: "Em 1989 só houve eleição para presidente."},
			)
		}
	}
	return append(out, history.Gap{Year: 1986, Office: history.OfficeGovernor, Reason: "As eleições de 1945 a 1986 não entram nesta versão: a série começa em 1989, primeira eleição direta para presidente depois de 1960."})
}

func indexSources(years []int) []history.Ref {
	var out []history.Ref
	for _, y := range years {
		out = append(out, historySources(y)...)
	}
	for i := range out {
		out[i].ID = fmt.Sprintf("tse-%d", years[i])
	}
	return out
}

func (in *Ingest) historyPaths() []string {
	root := filepath.Join(in.cfg.PublicDir, "v1")
	var out []string
	filepath.WalkDir(filepath.Join(root, "history"), func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(p, ".json") {
			return nil
		}
		if rel, err := filepath.Rel(root, p); err == nil {
			out = append(out, filepath.ToSlash(rel))
		}
		return nil
	})
	sort.Strings(out)
	return out
}
