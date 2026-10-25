package tse

import (
	"cmp"
	"encoding/json"
	"fmt"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

var brasilia = time.FixedZone("BRT", -3*60*60)

type rawCandidate struct {
	N    string `json:"n"`
	Nm   string `json:"nm"`
	Nmu  string `json:"nmu"`
	E    string `json:"e"`
	Vap  string `json:"vap"`
	Pvap string `json:"pvap"`
}

type rawParty struct {
	Sg   string         `json:"sg"`
	Cand []rawCandidate `json:"cand"`
}

type rawFile struct {
	Ele  string `json:"ele"`
	T    string `json:"t"`
	DG   string `json:"dg"`
	HG   string `json:"hg"`
	TF   string `json:"tf"`
	Carg []struct {
		Cd  string `json:"cd"`
		Agr []struct {
			Par []rawParty `json:"par"`
		} `json:"agr"`
	} `json:"carg"`
	S struct {
		Ts  string `json:"ts"`
		St  string `json:"st"`
		Pst string `json:"pst"`
	} `json:"s"`
	E struct {
		Te string `json:"te"`
		C  string `json:"c"`
		A  string `json:"a"`
	} `json:"e"`
	V struct {
		Vv  string `json:"vv"`
		Vb  string `json:"vb"`
		Tvn string `json:"tvn"`
		Tv  string `json:"tv"`
	} `json:"v"`
}

type parser struct {
	err error
}

func (p *parser) int(s string) int64 {
	s = strings.TrimSpace(s)
	if s == "" || p.err != nil {
		return 0
	}
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		p.err = fmt.Errorf("invalid integer %q", s)
	}
	return v
}

func (p *parser) percent(s string) float64 {
	s = strings.TrimSpace(s)
	if s == "" || p.err != nil {
		return 0
	}
	v, err := strconv.ParseFloat(strings.ReplaceAll(s, ",", "."), 64)
	if err != nil {
		p.err = fmt.Errorf("invalid percent %q", s)
	}
	return v
}

func Parse(d Definition, data []byte) (Race, error) {
	var f rawFile
	if err := json.Unmarshal(data, &f); err != nil {
		return Race{}, fmt.Errorf("decode %s: %w", d.ID, err)
	}
	if f.Ele != "" && f.Ele != d.Election {
		return Race{}, fmt.Errorf("decode %s: election %q, want %q", d.ID, f.Ele, d.Election)
	}
	if len(f.Carg) == 0 {
		return Race{}, fmt.Errorf("decode %s: no office", d.ID)
	}
	if f.Carg[0].Cd != "" && f.Carg[0].Cd != d.Cargo {
		return Race{}, fmt.Errorf("decode %s: office %q, want %q", d.ID, f.Carg[0].Cd, d.Cargo)
	}
	p := &parser{}
	round := 2
	if n, err := strconv.Atoi(strings.TrimSpace(f.T)); err == nil && n > 0 {
		round = n
	}
	r := Race{
		ID:     d.ID,
		Office: d.Office,
		UF:     d.UF,
		Round:  round,
		Sections: Sections{
			Total:   p.int(f.S.Ts),
			Counted: p.int(f.S.St),
			Percent: p.percent(f.S.Pst),
		},
		Electorate: p.int(f.E.Te),
		Turnout:    p.int(f.E.C),
		Votes: Votes{
			Valid: p.int(f.V.Vv),
			Blank: p.int(f.V.Vb),
			Null:  p.int(f.V.Tvn),
			Total: p.int(f.V.Tv),
		},
		Candidates: []Candidate{},
		Final:      strings.EqualFold(f.TF, "s"),
	}
	for _, agr := range f.Carg[0].Agr {
		for _, par := range agr.Par {
			for _, c := range par.Cand {
				name := c.Nmu
				if strings.TrimSpace(name) == "" {
					name = c.Nm
				}
				cand := Candidate{
					Number:  strings.TrimSpace(c.N),
					Name:    TitleName(name),
					Party:   strings.TrimSpace(par.Sg),
					Votes:   p.int(c.Vap),
					Percent: p.percent(c.Pvap),
					Elected: strings.EqualFold(c.E, "s"),
				}
				if cand.Elected {
					r.Final = true
				}
				r.Candidates = append(r.Candidates, cand)
			}
		}
	}
	if p.err != nil {
		return Race{}, fmt.Errorf("decode %s: %w", d.ID, p.err)
	}
	SortCandidates(r.Candidates)
	if t, err := time.ParseInLocation("02/01/2006 15:04:05", strings.TrimSpace(f.DG)+" "+strings.TrimSpace(f.HG), brasilia); err == nil {
		r.SourceGeneratedAt = t.Format(time.RFC3339)
	}
	return r, nil
}

func SortCandidates(cs []Candidate) {
	slices.SortStableFunc(cs, func(a, b Candidate) int {
		if c := cmp.Compare(b.Votes, a.Votes); c != 0 {
			return c
		}
		an, aerr := strconv.Atoi(a.Number)
		bn, berr := strconv.Atoi(b.Number)
		if aerr == nil && berr == nil {
			return cmp.Compare(an, bn)
		}
		return cmp.Compare(a.Number, b.Number)
	})
}

var lowerParticles = map[string]bool{"da": true, "de": true, "do": true, "dos": true, "das": true, "e": true}

func TitleName(s string) string {
	words := strings.Fields(strings.ToLower(s))
	for i, w := range words {
		if i > 0 && lowerParticles[w] {
			continue
		}
		r, size := utf8.DecodeRuneInString(w)
		words[i] = string(unicode.ToUpper(r)) + w[size:]
	}
	return strings.Join(words, " ")
}

func FormatGenerated(t time.Time) string {
	return t.In(brasilia).Format(time.RFC3339)
}
