package history

import (
	"fmt"
	"math"
	"sort"
	"strings"

	"liveresults/internal/sources/ibge"
	"liveresults/internal/sources/tse"
)

const (
	OfficePresident = "president"
	OfficeGovernor  = "governor"
	OfficeSenator   = "senator"
	ScopeBrazil     = "br"
	ScopeAbroad     = "zz"
)

var officeByCode = map[int]string{tse.President: OfficePresident, tse.Governor: OfficeGovernor, tse.Senator: OfficeSenator}

var officeSlug = map[string]string{OfficePresident: "presidente", OfficeGovernor: "governador", OfficeSenator: "senador"}

var officeOrder = map[string]int{OfficePresident: 0, OfficeGovernor: 1, OfficeSenator: 2}

type Candidate struct {
	Number     string  `json:"number"`
	Name       string  `json:"name"`
	BallotName string  `json:"ballotName"`
	Party      string  `json:"party"`
	Coalition  *string `json:"coalition"`
	Members    *string `json:"members"`
	Votes      int64   `json:"votes"`
	Annulled   *int64  `json:"annulled"`
	Share      float64 `json:"share"`
	Result     string  `json:"result"`
	Elected    bool    `json:"elected"`
	Advanced   bool    `json:"advanced"`
}

type StateTally struct {
	UF     string           `json:"uf"`
	Name   string           `json:"name"`
	Valid  int64            `json:"valid"`
	Winner string           `json:"winner"`
	Share  float64          `json:"share"`
	Votes  map[string]int64 `json:"votes"`
}

type Round struct {
	Round       int          `json:"round"`
	Date        string       `json:"date"`
	Electorate  *int64       `json:"electorate"`
	Turnout     *int64       `json:"turnout"`
	Abstentions *int64       `json:"abstentions"`
	Blank       *int64       `json:"blank"`
	Null        *int64       `json:"null"`
	Valid       int64        `json:"valid"`
	Candidates  []Candidate  `json:"candidates"`
	States      []StateTally `json:"states"`
}

type Race struct {
	ID        string  `json:"id"`
	Year      int     `json:"year"`
	Office    string  `json:"office"`
	Scope     string  `json:"scope"`
	ScopeName string  `json:"scopeName"`
	Seats     int     `json:"seats"`
	Rounds    []Round `json:"rounds"`
	Note      *string `json:"note"`
	Sources   []Ref   `json:"sources"`
}

type Pick struct {
	Number     string  `json:"number"`
	BallotName string  `json:"ballotName"`
	Party      string  `json:"party"`
	Votes      int64   `json:"votes"`
	Share      float64 `json:"share"`
	Elected    bool    `json:"elected"`
	Advanced   bool    `json:"advanced"`
}

type RoundSummary struct {
	Round   int      `json:"round"`
	Date    string   `json:"date"`
	Turnout *float64 `json:"turnout"`
	Leaders []Pick   `json:"leaders"`
}

type RaceSummary struct {
	ID        string         `json:"id"`
	Year      int            `json:"year"`
	Office    string         `json:"office"`
	Scope     string         `json:"scope"`
	ScopeName string         `json:"scopeName"`
	Seats     int            `json:"seats"`
	Rounds    []RoundSummary `json:"rounds"`
}

type Gap struct {
	Year   int    `json:"year"`
	Office string `json:"office"`
	Reason string `json:"reason"`
}

type Index struct {
	Years   []int         `json:"years"`
	Races   []RaceSummary `json:"races"`
	Gaps    []Gap         `json:"gaps"`
	Method  []string      `json:"method"`
	Sources []Ref         `json:"sources"`
}

func RaceID(year int, office, scope string) string {
	return fmt.Sprintf("%d-%s-%s", year, officeSlug[office], scope)
}

func RacePath(id string) string {
	return "history/elections/" + id + ".json"
}

const IndexPath = "history/elections/index.json"

func DatasetURL(year int) string {
	return fmt.Sprintf("%s/dataset/resultados-%d", tse.SiteURL, year)
}

func SenateSeats(year int) int {
	if (year-1994)%8 == 0 {
		return 2
	}
	return 1
}

func ScopeName(scope string) string {
	switch scope {
	case ScopeBrazil:
		return "Brasil"
	case ScopeAbroad:
		return "Exterior"
	}
	return ibge.StateName(strings.ToUpper(scope))
}

type candKey struct {
	office string
	round  int
	scope  string
	sq     string
}

type groupKey struct {
	office string
	round  int
	scope  string
}

type stateKey struct {
	round  int
	uf     string
	number string
}

type turnout struct {
	electorate, turnout, abstentions, blank, null int64
}

type Tally struct {
	year    int
	cands   map[candKey]*Candidate
	nominal map[candKey]int64
	states  map[stateKey]int64
	turnout map[groupKey]*turnout
	dates   map[int]string
}

func NewTally(year int) *Tally {
	return &Tally{
		year: year, cands: map[candKey]*Candidate{}, nominal: map[candKey]int64{},
		states: map[stateKey]int64{}, turnout: map[groupKey]*turnout{}, dates: map[int]string{},
	}
}

func (t *Tally) scope(office string, uf string, national bool) (string, bool) {
	if office == OfficePresident {
		return ScopeBrazil, national
	}
	if national {
		return "", false
	}
	uf = strings.ToLower(uf)
	if len(uf) != 2 || ibge.StateName(strings.ToUpper(uf)) == "" {
		return "", false
	}
	return uf, true
}

func (t *Tally) Vote(v tse.VoteRow, national bool) {
	office, ok := officeByCode[v.Office]
	sq := v.SQ
	if sq == "" {
		sq = v.Number + "|" + v.Name
	}
	if !ok || v.Round < 1 || sq == "|" {
		return
	}
	scope, ok := t.scope(office, v.UF, national)
	if !ok {
		return
	}
	k := candKey{office: office, round: v.Round, scope: scope, sq: sq}
	c := t.cands[k]
	if c == nil {
		ballot := v.BallotName
		if ballot == "" {
			ballot = v.Name
		}
		c = &Candidate{
			Number: v.Number, Name: v.Name, BallotName: ballot, Party: v.Party,
			Coalition: optional(v.Coalition), Members: optional(v.Members), Result: v.Result,
		}
		t.cands[k] = c
	}
	if c.Result == "" {
		c.Result = v.Result
	}
	c.Votes += v.Valid
	t.nominal[k] += v.Nominal
	if v.Date != "" && t.dates[v.Round] == "" {
		t.dates[v.Round] = v.Date
	}
	if office == OfficePresident && v.Valid > 0 {
		t.states[stateKey{round: v.Round, uf: strings.ToLower(v.UF), number: v.Number}] += v.Valid
	}
}

func (t *Tally) Turnout(r tse.TurnoutRow, national bool) {
	office, ok := officeByCode[r.Office]
	if !ok || r.Round < 1 {
		return
	}
	scope, ok := t.scope(office, r.UF, national)
	if !ok {
		return
	}
	k := groupKey{office: office, round: r.Round, scope: scope}
	agg := t.turnout[k]
	if agg == nil {
		agg = &turnout{}
		t.turnout[k] = agg
	}
	agg.electorate += r.Electorate
	agg.turnout += r.Turnout
	agg.abstentions += r.Abstentions
	agg.blank += r.Blank
	agg.null += r.Null
}

func (t *Tally) SetDate(round int, date string) {
	if t.dates[round] == "" {
		t.dates[round] = date
	}
}

func (t *Tally) Races(sources []Ref) []Race {
	type raceKey struct{ office, scope string }
	rounds := map[raceKey]map[int][]Candidate{}
	for k, c := range t.cands {
		rk := raceKey{k.office, k.scope}
		if rounds[rk] == nil {
			rounds[rk] = map[int][]Candidate{}
		}
		cand := *c
		cand.Elected = tse.Elected(cand.Result)
		cand.Advanced = advanced(cand.Result)
		if n := t.nominal[k]; n > cand.Votes {
			lost := n - cand.Votes
			cand.Annulled = &lost
		}
		rounds[rk][k.round] = append(rounds[rk][k.round], cand)
	}
	var out []Race
	for rk, byRound := range rounds {
		race := Race{
			ID: RaceID(t.year, rk.office, rk.scope), Year: t.year, Office: rk.office, Scope: rk.scope,
			ScopeName: ScopeName(rk.scope), Seats: 1, Sources: sources,
		}
		if rk.office == OfficeSenator {
			race.Seats = SenateSeats(t.year)
		}
		var nums []int
		for n := range byRound {
			nums = append(nums, n)
		}
		sort.Ints(nums)
		for _, n := range nums {
			race.Rounds = append(race.Rounds, t.round(rk.office, rk.scope, n, byRound[n]))
		}
		if race.Seats == 2 {
			note := "Duas vagas: cada eleitor deu dois votos, e a porcentagem é sobre o total de votos válidos dados aos candidatos."
			race.Note = &note
		}
		out = append(out, race)
	}
	sort.Slice(out, func(i, j int) bool { return less(out[i].Office, out[i].Scope, out[j].Office, out[j].Scope) })
	return out
}

func less(o1, s1, o2, s2 string) bool {
	if officeOrder[o1] != officeOrder[o2] {
		return officeOrder[o1] < officeOrder[o2]
	}
	return s1 < s2
}

func (t *Tally) round(office, scope string, n int, cands []Candidate) Round {
	var valid int64
	for _, c := range cands {
		valid += c.Votes
	}
	for i := range cands {
		cands[i].Share = share(cands[i].Votes, valid)
	}
	sort.SliceStable(cands, func(i, j int) bool {
		if cands[i].Votes != cands[j].Votes {
			return cands[i].Votes > cands[j].Votes
		}
		return cands[i].BallotName < cands[j].BallotName
	})
	r := Round{Round: n, Date: t.dates[n], Valid: valid, Candidates: cands}
	if agg := t.turnout[groupKey{office: office, round: n, scope: scope}]; agg != nil && agg.electorate > 0 {
		r.Electorate, r.Turnout, r.Abstentions = ptr(agg.electorate), ptr(agg.turnout), ptr(agg.abstentions)
		r.Blank, r.Null = ptr(agg.blank), ptr(agg.null)
	}
	if office == OfficePresident {
		r.States = t.stateTallies(n)
	}
	return r
}

func (t *Tally) stateTallies(round int) []StateTally {
	byUF := map[string]map[string]int64{}
	for k, v := range t.states {
		if k.round != round {
			continue
		}
		if byUF[k.uf] == nil {
			byUF[k.uf] = map[string]int64{}
		}
		byUF[k.uf][k.number] += v
	}
	var out []StateTally
	for uf, votes := range byUF {
		st := StateTally{UF: uf, Name: ScopeName(uf), Votes: votes}
		var best int64 = -1
		var numbers []string
		for n := range votes {
			numbers = append(numbers, n)
		}
		sort.Strings(numbers)
		for _, n := range numbers {
			st.Valid += votes[n]
			if votes[n] > best {
				best, st.Winner = votes[n], n
			}
		}
		st.Share = share(best, st.Valid)
		out = append(out, st)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].UF < out[j].UF })
	return out
}

func Summarize(races []Race) []RaceSummary {
	out := make([]RaceSummary, 0, len(races))
	for _, r := range races {
		s := RaceSummary{ID: r.ID, Year: r.Year, Office: r.Office, Scope: r.Scope, ScopeName: r.ScopeName, Seats: r.Seats}
		keep := r.Seats + 1
		for _, rd := range r.Rounds {
			rs := RoundSummary{Round: rd.Round, Date: rd.Date}
			if rd.Electorate != nil && rd.Turnout != nil && *rd.Electorate > 0 {
				v := math.Round(float64(*rd.Turnout)/float64(*rd.Electorate)*10000) / 100
				rs.Turnout = &v
			}
			for i, c := range rd.Candidates {
				if i >= keep && !c.Elected {
					continue
				}
				rs.Leaders = append(rs.Leaders, Pick{Number: c.Number, BallotName: c.BallotName, Party: c.Party, Votes: c.Votes, Share: c.Share, Elected: c.Elected, Advanced: c.Advanced})
			}
			s.Rounds = append(s.Rounds, rs)
		}
		out = append(out, s)
	}
	return out
}

func advanced(result string) bool {
	r := strings.ToUpper(strings.TrimSpace(result))
	return strings.Contains(r, "2º TURNO") || strings.Contains(r, "2O TURNO") || strings.Contains(r, "SEGUNDO TURNO")
}

func share(part, total int64) float64 {
	if total <= 0 {
		return 0
	}
	return math.Round(float64(part)/float64(total)*10000) / 100
}

func ptr(v int64) *int64 {
	return &v
}

func optional(s string) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	return &s
}
