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

const minOneWordName = 4

var nameParticles = map[string]bool{"da": true, "de": true, "do": true, "das": true, "dos": true, "di": true, "du": true, "del": true, "van": true, "von": true}

var officeTitles = map[string]bool{
	"presidente": true, "vice": true, "ex": true, "senador": true, "senadora": true, "deputado": true, "deputada": true,
	"governador": true, "governadora": true, "ministro": true, "ministra": true, "candidato": true, "candidata": true,
	"prefeito": true, "prefeita": true, "vereador": true, "vereadora": true, "pre": true,
}

type token struct {
	word   string
	upper  bool
	joined bool
}

func tokenize(s string) []token {
	var out []token
	var cur strings.Builder
	var upper bool
	joined := false
	gapOK := true
	flush := func() {
		if cur.Len() == 0 {
			return
		}
		out = append(out, token{word: cur.String(), upper: upper, joined: joined})
		cur.Reset()
		gapOK = true
	}
	for _, r := range s {
		l := unicode.ToLower(r)
		if m, ok := foldMap[l]; ok {
			l = m
		}
		if (l >= 'a' && l <= 'z') || (l >= '0' && l <= '9') {
			if cur.Len() == 0 {
				upper = unicode.IsUpper(r)
				joined = len(out) > 0 && gapOK
			}
			cur.WriteRune(l)
			continue
		}
		flush()
		switch r {
		case ' ', ' ', '-', '\'', '’':
		default:
			gapOK = false
		}
	}
	flush()
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

type nameHit struct {
	name       string
	owners     []*Person
	words      int
	standalone bool
	surname    bool
}

func capitalized(toks []token) bool {
	for _, t := range toks {
		if !nameParticles[t.word] && !t.upper {
			return false
		}
	}
	return true
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
			hits = append(hits, nameHit{name: key, owners: owners, words: l, standalone: standalone(toks, i, i+l)})
			i += l
			found = true
			break
		}
		if found {
			continue
		}
		t := toks[i]
		if owners, ok := ix.surnames[t.word]; ok && t.upper && standalone(toks, i, i+1) {
			hits = append(hits, nameHit{name: t.word, owners: owners, words: 1, standalone: true, surname: true})
		}
		i++
	}
	return hits
}

func MatchChecks(people []*Person, slugs map[*Person]string, checks []RawCheck) CheckMatch {
	ix := newNameIndex(people)
	res := CheckMatch{ByPerson: map[*Person][]FactCheck{}}
	for _, c := range checks {
		linked := map[*Person]bool{}
		type pending struct {
			reason string
			hit    nameHit
		}
		var doubts []pending
		for _, text := range append([]string{c.Title}, c.Texts...) {
			for _, h := range ix.scan(text) {
				switch {
				case h.surname:
					doubts = append(doubts, pending{ReviewSurnameOnly, h})
				case len(h.owners) > 1:
					doubts = append(doubts, pending{ReviewAmbiguousName, h})
				case !h.standalone:
					doubts = append(doubts, pending{ReviewPartOfLongerName, h})
				default:
					linked[h.owners[0]] = true
				}
			}
		}
		fc := FactCheck{ID: c.ID, Title: c.Title, Verdict: c.Verdict, Date: c.Date, URL: c.URL, Publisher: c.Publisher, License: c.License, LicenseURL: c.LicenseURL}
		for p := range linked {
			res.ByPerson[p] = append(res.ByPerson[p], fc)
		}
		seen := map[string]bool{}
		for _, d := range doubts {
			var cands []string
			for _, p := range d.hit.owners {
				if !linked[p] {
					cands = append(cands, slugs[p])
				}
			}
			if len(cands) == 0 {
				continue
			}
			sort.Strings(cands)
			key := d.reason + "|" + d.hit.name
			if seen[key] {
				continue
			}
			seen[key] = true
			res.Reviews = append(res.Reviews, CheckReview{CheckID: c.ID, Title: c.Title, Date: c.Date, URL: c.URL, Reason: d.reason, Name: d.hit.name, Candidates: cands})
		}
		if len(c.Conflict) > 0 {
			var cands []string
			for p := range linked {
				cands = append(cands, slugs[p])
			}
			sort.Strings(cands)
			res.Reviews = append(res.Reviews, CheckReview{CheckID: c.ID, Title: c.Title, Date: c.Date, URL: c.URL, Reason: ReviewVerdictConflict, Candidates: cands, Labels: append([]string(nil), c.Conflict...)})
		}
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
