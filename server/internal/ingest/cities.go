package ingest

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/ibge"
	"liveresults/internal/sources/tse"
)

type cityRoster struct {
	Units     map[string]string `json:"units"`
	Officials []tse.Official    `json:"officials"`
}

var cityOffice = map[int]string{
	tse.Mayor:     publicdata.OfficeMayor,
	tse.ViceMayor: publicdata.OfficeViceMayor,
	tse.Councilor: publicdata.OfficeCityCouncilor,
}

type cityReport struct {
	Cities    int
	People    int
	Matched   int
	Units     int
	Reviews   []publicdata.UnitReview
	NoMayor   []string
	NoCouncil []string
}

func (c Config) cityUFs() []string {
	var out []string
	for _, u := range c.UFs {
		if u != "br" {
			out = append(out, u)
		}
	}
	return out
}

func (c Config) cityYear() int {
	if c.CityYear > 0 {
		return c.CityYear
	}
	return 2024
}

func (in *Ingest) loadCities(ctx context.Context, rep *Report, muns []publicdata.PlaceEntry, srcs *sourceSet) []publicdata.City {
	year := in.cfg.cityYear()
	ufs := in.cfg.cityUFs()
	roster, err := cached(ctx, in, "consulta_cand", year, ufs, tse.CandidatesURL(year), func(r io.Reader, out *cityRoster) error {
		if out.Units == nil {
			out.Units = map[string]string{}
		}
		return tse.ReadOfficials(r, func(uf, code, name string) {
			out.Units[publicdata.UnitKey(uf, code)] = name
		}, func(o tse.Official) { out.Officials = append(out.Officials, o) })
	})
	if err != nil {
		stale, ok := staleCache[cityRoster](in, "consulta_cand", year, ufs)
		if !ok {
			in.warn(rep, "cities %d: %v (no city files published)", year, err)
			return nil
		}
		in.warn(rep, "cities %d: %v (using the last good read)", year, err)
		roster = stale
	}
	officials := tse.Seated(roster.Officials)
	keep := map[string]bool{}
	var sqs []string
	for _, o := range officials {
		if !keep[o.SQ] {
			keep[o.SQ] = true
			sqs = append(sqs, o.SQ)
		}
	}
	sort.Strings(sqs)
	sum := sha256.Sum256([]byte(strings.Join(sqs, ",")))
	salt := hex.EncodeToString(sum[:8])
	assets, err := cachedSalted(ctx, in, "bem_candidato", year, ufs, tse.AssetsURL(year), salt, func(r io.Reader, out *map[string][]publicdata.AssetItem) error {
		if *out == nil {
			*out = map[string][]publicdata.AssetItem{}
		}
		return tse.ReadAssets(r, func(sq string) bool { return keep[sq] }, func(a tse.Asset) {
			(*out)[a.SQ] = append((*out)[a.SQ], publicdata.AssetItem{Kind: a.Kind, Cents: a.Cents})
		})
	})
	assetsOK := err == nil
	if err != nil {
		in.warn(rep, "cities %d assets: %v", year, err)
	}
	rounds, err := cachedSalted(ctx, in, "votacao_candidato_munzona", year, ufs, tse.VotesURL(year), salt, func(r io.Reader, out *map[string]map[int]int64) error {
		if *out == nil {
			*out = map[string]map[int]int64{}
		}
		return tse.ReadOfficialVotes(r, func(sq string, round int, n int64) {
			if !keep[sq] {
				return
			}
			m := (*out)[sq]
			if m == nil {
				m = map[int]int64{}
				(*out)[sq] = m
			}
			m[round] += n
		})
	})
	var votes map[string]int64
	if err != nil {
		in.warn(rep, "cities %d votes: %v", year, err)
	} else {
		votes = lastRound(rounds)
	}
	var units []publicdata.Unit
	for key, name := range roster.Units {
		uf, code, _ := strings.Cut(key, ":")
		units = append(units, publicdata.Unit{UF: uf, Code: code, Name: name})
	}
	var scope []publicdata.PlaceEntry
	for _, m := range muns {
		if in.cfg.wantUF(m.UF) {
			scope = append(scope, m)
		}
	}
	match := publicdata.MatchUnits(units, scope)
	byIBGE := map[string]string{}
	for key, code := range match.ByUnit {
		byIBGE[code] = key
	}
	people := map[string][]*publicdata.Person{}
	names := map[string]string{}
	for _, m := range scope {
		names[m.Code] = m.Name
	}
	for _, o := range officials {
		key := publicdata.UnitKey(o.UF, o.Unit)
		code, ok := match.ByUnit[key]
		if !ok {
			continue
		}
		people[code] = append(people[code], cityPerson(o, year, names[code], assetsOK, assets, votes))
	}
	cr := cityReport{Units: len(units), Matched: len(match.ByUnit), Reviews: match.Reviews}
	var cities []publicdata.City
	for _, m := range scope {
		c := publicdata.City{Code: m.Code, Name: m.Name, UF: m.UF, Officials: people[m.Code]}
		if key, ok := byIBGE[m.Code]; ok {
			_, c.Unit, _ = strings.Cut(key, ":")
		}
		cities = append(cities, c)
		cr.People += len(c.Officials)
		if c.Unit != "" && !hasOffice(c, publicdata.OfficeMayor) {
			cr.NoMayor = append(cr.NoMayor, c.Code+" "+c.Name+" ("+strings.ToUpper(c.UF)+")")
		}
		if c.Unit != "" && !hasOffice(c, publicdata.OfficeCityCouncilor) {
			cr.NoCouncil = append(cr.NoCouncil, c.Code+" "+c.Name+" ("+strings.ToUpper(c.UF)+")")
		}
	}
	cr.Cities = len(cities)
	if err := in.writeCityReview(cr); err != nil {
		in.warn(rep, "cities review: %v", err)
	}
	unmatched := 0
	for _, r := range match.Reviews {
		if r.Kind == "unmatchedUnit" {
			unmatched++
		}
	}
	if unmatched > 0 {
		in.warn(rep, "cities: %d TSE units without an IBGE municipality (see cities-review.json)", unmatched)
	}
	in.logger.Printf("cities %d: %d municipalities, %d TSE units matched of %d, %d officials, %d without mayor, %d without council", year, len(cities), cr.Matched, cr.Units, cr.People, len(cr.NoMayor), len(cr.NoCouncil))
	rep.Cities, rep.CityPeople = len(cities), cr.People
	srcs.add(publicdata.CitySource, "Tribunal Superior Eleitoral", tse.SiteURL, []any{officials, assetsOK, votes != nil})
	return cities
}

func hasOffice(c publicdata.City, office string) bool {
	for _, p := range c.Officials {
		if p.Primary().Office == office {
			return true
		}
	}
	return false
}

func cityPerson(o tse.Official, year int, city string, assetsOK bool, assets map[string][]publicdata.AssetItem, votes map[string]int64) *publicdata.Person {
	office := cityOffice[o.Office]
	uf := strings.ToLower(o.UF)
	p := &publicdata.Person{Name: publicdata.TitleName(o.BallotName), CivilName: publicdata.TitleName(o.Name), BirthDate: o.BirthDate}
	if p.Name == "" {
		p.Name = p.CivilName
	}
	if o.Key != "" {
		p.AddKey(o.Key)
	} else {
		p.AddKey("tse:" + strconv.Itoa(year) + ":" + o.SQ)
	}
	start := ""
	if strings.HasPrefix(o.Date, strconv.Itoa(year)) {
		start = strconv.Itoa(year+1) + "-01-01"
	}
	p.Roles = []publicdata.Role{{Office: office, UF: uf, Status: publicdata.StatusInOffice, Party: o.Party, MandateStart: start, MandateEnd: strconv.Itoa(year+4) + "-12-31"}}
	if o.Education != "" {
		p.Education = strings.TrimSuffix(publicdata.Sentence(strings.ToLower(o.Education)), ".")
	}
	if n := ibge.StateName(strings.ToUpper(o.BirthUF)); n != "" {
		p.BirthPlace = n
	}
	c := publicdata.Candidacy{Year: year, Office: office, UF: uf, Party: o.Party, Result: o.Result, Elected: true, SQ: o.SQ, Name: o.Name, BallotName: o.BallotName, BirthDate: o.BirthDate, BirthUF: o.BirthUF, Education: o.Education, Place: city + " (" + strings.ToUpper(uf) + ")"}
	if assetsOK {
		c.Assets, c.AssetsLoaded = assets[o.SQ], true
	}
	if n, ok := votes[o.SQ]; ok {
		c.Votes = &n
	}
	p.Candidacies = []publicdata.Candidacy{c}
	p.AddSource(publicdata.CitySource)
	p.Coverage = map[string]publicdata.Coverage{}
	if assetsOK {
		p.Coverage["assets"] = publicdata.Coverage{Kind: "assets", Status: publicdata.CoverageAvailable, Source: publicdata.CitySource}
	} else {
		p.Coverage["assets"] = publicdata.Coverage{Kind: "assets", Status: publicdata.CoverageNotLoaded, Source: publicdata.CitySource}
	}
	p.Coverage["campaigns"] = publicdata.Coverage{Kind: "campaigns", Status: publicdata.CoverageNotLoaded, Source: publicdata.CitySource}
	p.Coverage["salary"] = publicdata.Coverage{Kind: "salary", Status: publicdata.CoverageNotLoaded, Source: publicdata.CitySource}
	return p
}

func (in *Ingest) writeCityReview(cr cityReport) error {
	path := filepath.Join(in.cfg.DataDir, "cities-review.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	reviews := cr.Reviews
	if reviews == nil {
		reviews = []publicdata.UnitReview{}
	}
	data, err := json.MarshalIndent(map[string]any{
		"municipalities": cr.Cities, "tseUnits": cr.Units, "matched": cr.Matched, "officials": cr.People,
		"reviews": reviews, "withoutMayor": nonEmpty(cr.NoMayor), "withoutCouncil": nonEmpty(cr.NoCouncil),
	}, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return fmt.Errorf("write %s: %w", tmp, err)
	}
	return os.Rename(tmp, path)
}

func nonEmpty(in []string) []string {
	if in == nil {
		return []string{}
	}
	return in
}
