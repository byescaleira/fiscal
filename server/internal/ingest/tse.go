package ingest

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/tse"
)

type tseResult struct {
	candidacies []publicdata.Candidacy
	campaigns   *publicdata.CampaignTotals
}

type accountAgg struct {
	Revenue  map[string]int64 `json:"revenue"`
	Expense  map[string]int64 `json:"expense"`
	ByOrigin map[string]int64 `json:"byOrigin"`
}

var tseOffice = map[int]string{
	tse.President:      publicdata.OfficePresident,
	tse.VicePresident:  publicdata.OfficeVicePresident,
	tse.Governor:       publicdata.OfficeGovernor,
	tse.ViceGovernor:   publicdata.OfficeViceGovernor,
	tse.Senator:        publicdata.OfficeSenator,
	tse.FederalDeputy:  publicdata.OfficeFederalDeputy,
	tse.StateDeputy:    publicdata.OfficeStateDeputy,
	tse.DistrictDeputy: publicdata.OfficeStateDeputy,
}

func (in *Ingest) loadTSE(ctx context.Context, rep *Report) (tseResult, error) {
	var res tseResult
	years := map[int]bool{}
	for _, y := range in.cfg.TSEYears {
		years[y] = true
	}
	for _, y := range in.cfg.TSECandidateYears {
		years[y] = true
	}
	var ordered []int
	for y := range years {
		ordered = append(ordered, y)
	}
	sort.Ints(ordered)
	full := map[int]bool{}
	for _, y := range in.cfg.TSEYears {
		full[y] = true
	}
	ufs := in.cfg.tseUFs()
	latestAccounts := 0
	for _, y := range ordered {
		cands, err := cached(ctx, in, "consulta_cand", y, ufs, tse.CandidatesURL(y), func(r io.Reader, out *[]tse.Candidate) error {
			return tse.ReadCandidates(r, func(c tse.Candidate) { *out = append(*out, c) })
		})
		if err != nil {
			if full[y] {
				return res, fmt.Errorf("candidates %d: %w", y, err)
			}
			in.warn(rep, "tse candidates %d: %v", y, err)
			continue
		}
		merged := tse.MergeRounds(cands)
		assets, err := cached(ctx, in, "bem_candidato", y, ufs, tse.AssetsURL(y), func(r io.Reader, out *map[string][]publicdata.AssetItem) error {
			if *out == nil {
				*out = map[string][]publicdata.AssetItem{}
			}
			return tse.ReadAssets(r, nil, func(a tse.Asset) {
				(*out)[a.SQ] = append((*out)[a.SQ], publicdata.AssetItem{Kind: a.Kind, Cents: a.Cents})
			})
		})
		assetsOK := err == nil
		if err != nil {
			in.warn(rep, "tse assets %d: %v", y, err)
		}
		var votes map[string]int64
		var acc *accountAgg
		if full[y] {
			v, err := cached(ctx, in, "votacao_candidato_munzona", y, ufs, tse.VotesURL(y), func(r io.Reader, out *map[string]map[int]int64) error {
				if *out == nil {
					*out = map[string]map[int]int64{}
				}
				return tse.ReadVotes(r, nil, func(sq string, round int, n int64) {
					m := (*out)[sq]
					if m == nil {
						m = map[int]int64{}
						(*out)[sq] = m
					}
					m[round] += n
				})
			})
			if err != nil {
				in.warn(rep, "tse votes %d: %v", y, err)
			} else {
				votes = lastRound(v)
			}
			a, err := in.accounts(ctx, y, ufs)
			if err != nil {
				in.warn(rep, "tse accounts %d: %v", y, err)
			} else {
				acc = a
				if y > latestAccounts {
					latestAccounts = y
					res.campaigns = totals(y, a)
				}
			}
		}
		for _, c := range merged {
			office, ok := tseOffice[c.Office]
			if !ok {
				continue
			}
			pc := publicdata.Candidacy{
				Year: c.Year, Office: office, UF: strings.ToLower(c.UF), Party: c.Party, Result: c.Result, Elected: tse.Elected(c.Result),
				SQ: c.SQ, CPF: c.CPF, Name: c.Name, BallotName: c.BallotName, BirthDate: c.BirthDate, BirthUF: c.BirthUF, Education: c.Education,
			}
			if assetsOK {
				pc.Assets, pc.AssetsLoaded = assets[c.SQ], true
			}
			if votes != nil {
				if n, ok := votes[c.SQ]; ok {
					pc.Votes = &n
				}
			}
			if acc != nil {
				if v, ok := acc.Revenue[c.SQ]; ok {
					pc.RevenueCents = &v
				}
				if v, ok := acc.Expense[c.SQ]; ok {
					pc.ExpenseCents = &v
				}
			}
			res.candidacies = append(res.candidacies, pc)
		}
	}
	return res, nil
}

func lastRound(in map[string]map[int]int64) map[string]int64 {
	out := make(map[string]int64, len(in))
	for sq, rounds := range in {
		best := 0
		for r := range rounds {
			if r > best {
				best = r
			}
		}
		out[sq] = rounds[best]
	}
	return out
}

func totals(year int, a *accountAgg) *publicdata.CampaignTotals {
	t := &publicdata.CampaignTotals{Year: year, ByOrigin: map[string]int64{}}
	for _, v := range a.Revenue {
		t.Revenue += v
	}
	for _, v := range a.Expense {
		t.Expense += v
	}
	for k, v := range a.ByOrigin {
		t.ByOrigin[k] = v
	}
	return t
}

func (in *Ingest) accounts(ctx context.Context, y int, ufs []string) (*accountAgg, error) {
	rev, err := cached(ctx, in, "receitas_candidatos", y, ufs, tse.AccountsURL(y), func(r io.Reader, out *accountAgg) error {
		if out.Revenue == nil {
			out.Revenue, out.ByOrigin = map[string]int64{}, map[string]int64{}
		}
		return tse.ReadRevenues(r, nil, func(sq, origin string, c int64) {
			out.Revenue[sq] += c
			if origin == "" {
				origin = "Não informada"
			}
			out.ByOrigin[origin] += c
		})
	})
	if err != nil {
		return nil, err
	}
	exp, err := cached(ctx, in, "despesas_contratadas_candidatos", y, ufs, tse.AccountsURL(y), func(r io.Reader, out *map[string]int64) error {
		if *out == nil {
			*out = map[string]int64{}
		}
		return tse.ReadExpenses(r, nil, func(sq string, c int64) { (*out)[sq] += c })
	})
	if err != nil {
		return nil, err
	}
	rev.Expense = exp
	return &rev, nil
}

type cacheEnvelope[T any] struct {
	Version string `json:"version"`
	Value   T      `json:"value"`
}

func cached[T any](ctx context.Context, in *Ingest, prefix string, year int, ufs []string, url string, read func(io.Reader, *T) error) (T, error) {
	var zero T
	remote, err := in.get.Open(ctx, url)
	if err != nil {
		return zero, err
	}
	key := "all"
	if len(ufs) > 0 {
		key = strings.Join(ufs, "-")
	}
	dir := filepath.Join(in.cfg.DataDir, "cache", "tse")
	path := filepath.Join(dir, fmt.Sprintf("%s-%d-%s.json", prefix, year, key))
	if data, err := os.ReadFile(path); err == nil {
		var env cacheEnvelope[T]
		if json.Unmarshal(data, &env) == nil && env.Version != "" && env.Version == remote.Version() {
			return env.Value, nil
		}
	}
	zr, err := remote.Zip()
	if err != nil {
		return zero, err
	}
	files := tse.Entries(zr, prefix, year, ufs)
	if len(files) == 0 {
		return zero, errors.New("no matching CSV inside the ZIP")
	}
	var value T
	if err := tse.EachEntry(files, func(_ string, r io.Reader) error { return read(r, &value) }); err != nil {
		return zero, err
	}
	in.logger.Printf("tse %s %d: read %d entries, %s over HTTP range", prefix, year, len(files), humanBytes(remote.BytesRead()))
	if remote.Version() != "" {
		if err := os.MkdirAll(dir, 0o700); err == nil {
			if data, err := json.Marshal(cacheEnvelope[T]{Version: remote.Version(), Value: value}); err == nil {
				tmp := path + ".tmp"
				if os.WriteFile(tmp, data, 0o600) == nil {
					os.Rename(tmp, path)
				}
			}
		}
	}
	return value, nil
}

func humanBytes(n int64) string {
	switch {
	case n >= 1<<20:
		return strconv.FormatFloat(float64(n)/(1<<20), 'f', 1, 64) + " MiB"
	case n >= 1<<10:
		return strconv.FormatFloat(float64(n)/(1<<10), 'f', 1, 64) + " KiB"
	}
	return strconv.FormatInt(n, 10) + " B"
}
