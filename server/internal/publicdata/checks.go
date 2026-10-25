package publicdata

import (
	"sort"
	"strings"
	"unicode"
)

type RawCheck struct {
	ID         string
	Source     string
	Title      string
	Texts      []string
	Verdict    *string
	Conflict   []string
	Date       string
	URL        string
	Publisher  string
	License    string
	LicenseURL string
}

type FactCheck struct {
	ID         string  `json:"id"`
	Title      string  `json:"title"`
	Verdict    *string `json:"verdict"`
	Date       string  `json:"date"`
	URL        string  `json:"url"`
	Publisher  string  `json:"publisher"`
	License    string  `json:"license"`
	LicenseURL string  `json:"licenseUrl"`
}

type CheckList struct {
	Items   []FactCheck `json:"items"`
	Sources []Source    `json:"sources"`
}

const (
	ReviewAmbiguousName    = "ambiguousName"
	ReviewPartOfLongerName = "partOfLongerName"
	ReviewSurnameOnly      = "surnameOnly"
	ReviewOfficeMismatch   = "officeMismatch"
	ReviewPossibleHomonym  = "possibleHomonym"
	ReviewVerdictConflict  = "verdictConflict"
)

type CheckReview struct {
	CheckID    string   `json:"checkId"`
	Title      string   `json:"title"`
	Date       string   `json:"date"`
	URL        string   `json:"url"`
	Reason     string   `json:"reason"`
	Name       string   `json:"name,omitempty"`
	Candidates []string `json:"candidates,omitempty"`
	Labels     []string `json:"labels,omitempty"`
}

type CheckMatch struct {
	ByPerson map[*Person][]FactCheck
	Reviews  []CheckReview
}

const (
	minOneWordName = 4
	titleWindow    = 4
	longName       = 3
)

var nameParticles = map[string]bool{"da": true, "de": true, "do": true, "das": true, "dos": true, "di": true, "du": true, "del": true, "van": true, "von": true}

var officeTitles = map[string]bool{
	"presidente": true, "presidenta": true, "vice": true, "ex": true, "senador": true, "senadora": true, "deputado": true,
	"deputada": true, "governador": true, "governadora": true, "ministro": true, "ministra": true, "candidato": true,
	"candidata": true, "prefeito": true, "prefeita": true, "vereador": true, "vereadora": true, "pre": true,
}

var titleOffices = map[string][]string{
	"presidente": {OfficePresident}, "presidenta": {OfficePresident},
	"senador": {OfficeSenator}, "senadora": {OfficeSenator},
	"deputado": {OfficeFederalDeputy, OfficeStateDeputy}, "deputada": {OfficeFederalDeputy, OfficeStateDeputy},
	"governador": {OfficeGovernor}, "governadora": {OfficeGovernor},
	"ministro": nil, "ministra": nil, "prefeito": nil, "prefeita": nil, "vereador": nil, "vereadora": nil,
	"juiz": nil, "juiza": nil, "desembargador": nil, "desembargadora": nil,
}

var pastMarkers = map[string]bool{"ex": true, "pre": true, "entao": true, "antigo": true, "antiga": true, "futuro": true, "futura": true, "eleito": true, "eleita": true}

var viceOffices = map[string][]string{
	"presidente": {OfficeVicePresident}, "presidenta": {OfficeVicePresident},
	"governador": {OfficeViceGovernor}, "governadora": {OfficeViceGovernor},
}

type token struct {
	word    string
	upper   bool
	joined  bool
	hard    bool
	paren   bool
	initial bool
}

func tokenize(s string) []token {
	var out []token
	var cur strings.Builder
	var next token
	gapOK, hard, paren := true, false, false
	for _, r := range s + " " {
		l := unicode.ToLower(r)
		if m, ok := foldMap[l]; ok {
			l = m
		}
		if (l >= 'a' && l <= 'z') || (l >= '0' && l <= '9') {
			if cur.Len() == 0 {
				next = token{upper: unicode.IsUpper(r), joined: len(out) > 0 && gapOK, hard: hard, paren: paren, initial: len(out) == 0 || hard}
			}
			cur.WriteRune(l)
			continue
		}
		if cur.Len() > 0 {
			next.word = cur.String()
			out = append(out, next)
			cur.Reset()
			gapOK, hard, paren = true, false, false
		}
		switch r {
		case ' ', ' ', '-', '\'', '’':
		case '.', '!', '?', ';', ':':
			gapOK, hard = false, true
		case '(', '[':
			gapOK, paren = false, true
		default:
			gapOK = false
		}
	}
	return out
}

type nameIndex struct {
	owners   map[string][]*Person
	surnames map[string][]*Person
	maxWords int
}

func addOwner(m map[string][]*Person, key string, p *Person) {
	for _, q := range m[key] {
		if q == p {
			return
		}
	}
	m[key] = append(m[key], p)
}

func newNameIndex(people []*Person) nameIndex {
	ix := nameIndex{owners: map[string][]*Person{}, surnames: map[string][]*Person{}}
	for _, p := range people {
		ballot := Fold(p.Name)
		for _, n := range []string{ballot, Fold(p.CivilName)} {
			words := strings.Fields(n)
			if len(words) == 0 {
				continue
			}
			if len(words) == 1 && (n != ballot || len(n) < minOneWordName) {
				continue
			}
			addOwner(ix.owners, n, p)
			if len(words) > ix.maxWords {
				ix.maxWords = len(words)
			}
		}
		if words := strings.Fields(ballot); len(words) > 1 {
			last := words[len(words)-1]
			if len(last) >= minOneWordName && !nameParticles[last] {
				addOwner(ix.surnames, last, p)
			}
		}
	}
	return ix
}

const (
	evidenceNone = iota
	evidenceMatch
	evidenceMismatch
)

type nameHit struct {
	name       string
	owners     []*Person
	standalone bool
	surname    bool
	evidence   int
}

func capitalized(toks []token) bool {
	for _, t := range toks {
		if !nameParticles[t.word] && !t.upper {
			return false
		}
	}
	return true
}

func significant(toks []token) int {
	n := 0
	for _, t := range toks {
		if !nameParticles[t.word] {
			n++
		}
	}
	return n
}

func chained(toks []token) bool {
	for _, t := range toks[1:] {
		if !t.joined {
			return false
		}
	}
	return true
}

func standalone(toks []token, start, end int) bool {
	if start > 0 && toks[start].joined {
		prev := toks[start-1]
		if prev.upper && !officeTitles[prev.word] && !nameParticles[prev.word] {
			return false
		}
		if nameParticles[prev.word] && start > 1 && prev.joined && toks[start-2].upper && !toks[start-2].initial && !officeTitles[toks[start-2].word] {
			return false
		}
	}
	if end < len(toks) && toks[end].joined {
		next := toks[end]
		if next.upper && !nameParticles[next.word] {
			return false
		}
		if nameParticles[next.word] && end+1 < len(toks) && toks[end+1].joined && toks[end+1].upper {
			return false
		}
	}
	return true
}

func titleBefore(toks []token, start int) ([]string, bool) {
	for k := start - 1; k >= 0 && k >= start-titleWindow; k-- {
		if toks[k+1].hard {
			return nil, false
		}
		word := toks[k].word
		offices, ok := titleOffices[word]
		if !ok {
			continue
		}
		vice := k > 0 && toks[k].joined && toks[k-1].word == "vice"
		if vice {
			offices = viceOffices[word]
			k--
		}
		if k > 0 && pastMarkers[toks[k-1].word] {
			return nil, false
		}
		head := toks[k].word
		if !vice && (head == "presidente" || head == "presidenta") && k+1 < start && nameParticles[toks[k+1].word] {
			return nil, false
		}
		return offices, true
	}
	return nil, false
}

func partyAfter(toks []token, end int, p *Person) bool {
	if end >= len(toks) || !toks[end].paren {
		return false
	}
	words := strings.Fields(Fold(p.Primary().Party))
	if len(words) == 0 || end+len(words) > len(toks) {
		return false
	}
	for i, w := range words {
		if toks[end+i].word != w {
			return false
		}
	}
	return true
}

func holds(p *Person, offices []string) bool {
	for _, r := range p.Roles {
		for _, o := range offices {
			if r.Office == o {
				return true
			}
		}
	}
	return false
}

func evidenceFor(toks []token, start, end int, p *Person) int {
	if offices, ok := titleBefore(toks, start); ok {
		if holds(p, offices) {
			return evidenceMatch
		}
		return evidenceMismatch
	}
	if partyAfter(toks, end, p) {
		return evidenceMatch
	}
	return evidenceNone
}

func (ix nameIndex) scan(text string) []nameHit {
	toks := tokenize(text)
	var hits []nameHit
	for i := 0; i < len(toks); {
		found := false
		for l := min(ix.maxWords, len(toks)-i); l >= 1; l-- {
			span := toks[i : i+l]
			if !chained(span) || !capitalized(span) || nameParticles[span[0].word] || nameParticles[span[l-1].word] {
				continue
			}
			words := make([]string, l)
			for k, t := range span {
				words[k] = t.word
			}
			key := strings.Join(words, " ")
			owners, ok := ix.owners[key]
			if !ok {
				continue
			}
			h := nameHit{name: key, owners: owners, standalone: significant(span) >= longName || standalone(toks, i, i+l)}
			if len(owners) == 1 {
				h.evidence = evidenceFor(toks, i, i+l, owners[0])
			}
			hits = append(hits, h)
			i += l
			found = true
			break
		}
		if found {
			continue
		}
		t := toks[i]
		if owners, ok := ix.surnames[t.word]; ok && t.upper && standalone(toks, i, i+1) {
			hits = append(hits, nameHit{name: t.word, owners: owners, standalone: true, surname: true})
		}
		i++
	}
	return hits
}

type checkDoubt struct {
	reason string
	name   string
	owners []*Person
}

type scannedCheck struct {
	check  RawCheck
	linked map[*Person]string
	doubts []checkDoubt
}

func scanCheck(ix nameIndex, c RawCheck, confirmed, contradicted map[*Person]bool) scannedCheck {
	sc := scannedCheck{check: c, linked: map[*Person]string{}}
	mismatch := map[*Person]string{}
	for _, text := range append([]string{c.Title}, c.Texts...) {
		for _, h := range ix.scan(text) {
			switch {
			case h.surname:
				sc.doubts = append(sc.doubts, checkDoubt{ReviewSurnameOnly, h.name, h.owners})
			case len(h.owners) > 1:
				sc.doubts = append(sc.doubts, checkDoubt{ReviewAmbiguousName, h.name, h.owners})
			case !h.standalone:
				sc.doubts = append(sc.doubts, checkDoubt{ReviewPartOfLongerName, h.name, h.owners})
			case h.evidence == evidenceMismatch:
				contradicted[h.owners[0]] = true
				mismatch[h.owners[0]] = h.name
			default:
				if h.evidence == evidenceMatch {
					confirmed[h.owners[0]] = true
				}
				if _, ok := sc.linked[h.owners[0]]; !ok {
					sc.linked[h.owners[0]] = h.name
				}
			}
		}
	}
	for p, name := range mismatch {
		delete(sc.linked, p)
		sc.doubts = append(sc.doubts, checkDoubt{ReviewOfficeMismatch, name, []*Person{p}})
	}
	return sc
}

func MatchChecks(people []*Person, slugs map[*Person]string, checks []RawCheck) CheckMatch {
	ix := newNameIndex(people)
	res := CheckMatch{ByPerson: map[*Person][]FactCheck{}}
	confirmed := map[*Person]bool{}
	contradicted := map[*Person]bool{}
	scanned := make([]scannedCheck, 0, len(checks))
	for _, c := range checks {
		scanned = append(scanned, scanCheck(ix, c, confirmed, contradicted))
	}
	for _, sc := range scanned {
		c := sc.check
		fc := FactCheck{ID: c.ID, Title: c.Title, Verdict: c.Verdict, Date: c.Date, URL: c.URL, Publisher: c.Publisher, License: c.License, LicenseURL: c.LicenseURL}
		published := map[*Person]bool{}
		doubts := sc.doubts
		for p, name := range sc.linked {
			if contradicted[p] && !confirmed[p] {
				doubts = append(doubts, checkDoubt{ReviewPossibleHomonym, name, []*Person{p}})
				continue
			}
			published[p] = true
			res.ByPerson[p] = append(res.ByPerson[p], fc)
		}
		res.Reviews = append(res.Reviews, reviewsFor(c, doubts, published, slugs)...)
	}
	for p, items := range res.ByPerson {
		sortChecks(items)
		res.ByPerson[p] = items
	}
	sort.SliceStable(res.Reviews, func(i, j int) bool {
		a, b := res.Reviews[i], res.Reviews[j]
		if a.Date != b.Date {
			return a.Date > b.Date
		}
		if a.CheckID != b.CheckID {
			return a.CheckID < b.CheckID
		}
		if a.Reason != b.Reason {
			return a.Reason < b.Reason
		}
		return a.Name < b.Name
	})
	return res
}

func reviewsFor(c RawCheck, doubts []checkDoubt, published map[*Person]bool, slugs map[*Person]string) []CheckReview {
	var out []CheckReview
	seen := map[string]bool{}
	for _, d := range doubts {
		var cands []string
		for _, p := range d.owners {
			if !published[p] {
				cands = append(cands, slugs[p])
			}
		}
		key := d.reason + "|" + d.name
		if len(cands) == 0 || seen[key] {
			continue
		}
		seen[key] = true
		sort.Strings(cands)
		out = append(out, CheckReview{CheckID: c.ID, Title: c.Title, Date: c.Date, URL: c.URL, Reason: d.reason, Name: d.name, Candidates: cands})
	}
	if len(c.Conflict) > 0 {
		var cands []string
		for p := range published {
			cands = append(cands, slugs[p])
		}
		sort.Strings(cands)
		out = append(out, CheckReview{CheckID: c.ID, Title: c.Title, Date: c.Date, URL: c.URL, Reason: ReviewVerdictConflict, Candidates: cands, Labels: append([]string(nil), c.Conflict...)})
	}
	return out
}

func sortChecks(items []FactCheck) {
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Date != items[j].Date {
			return items[i].Date > items[j].Date
		}
		if len(items[i].ID) != len(items[j].ID) {
			return len(items[i].ID) > len(items[j].ID)
		}
		return items[i].ID > items[j].ID
	})
}
