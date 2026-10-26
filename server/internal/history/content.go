package history

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"
)

const (
	PeriodsPath = "history/periods.json"
	StudyPath   = "history/study.json"
)

//go:embed content/sources.json
var sourcesJSON []byte

//go:embed content/periods.json
var periodsJSON []byte

//go:embed content/study.json
var studyJSON []byte

type Ref struct {
	ID   string  `json:"id"`
	Name string  `json:"name"`
	URL  *string `json:"url"`
}

type Item struct {
	Text    string `json:"text"`
	Sources []Ref  `json:"sources"`
}

type President struct {
	Name    string  `json:"name"`
	Start   string  `json:"start"`
	End     *string `json:"end"`
	How     string  `json:"how"`
	Sources []Ref   `json:"sources"`
}

type Milestone struct {
	Date    string `json:"date"`
	Kind    string `json:"kind"`
	Title   string `json:"title"`
	Text    string `json:"text"`
	Sources []Ref  `json:"sources"`
}

type Divergence struct {
	Topic     string `json:"topic"`
	Positions []Item `json:"positions"`
}

type Period struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Era         string            `json:"era"`
	Start       string            `json:"start"`
	End         *string           `json:"end"`
	Summary     string            `json:"summary"`
	Presidents  []President       `json:"presidents"`
	Milestones  []Milestone       `json:"milestones"`
	Advances    []Item            `json:"advances"`
	Critiques   []Item            `json:"critiques"`
	Divergences []Divergence      `json:"divergences"`
	Indicators  []PeriodIndicator `json:"indicators"`
	Sources     []Ref             `json:"sources"`
}

type Timeline struct {
	Version string   `json:"version"`
	Method  []string `json:"method"`
	Periods []Period `json:"periods"`
}

type Card struct {
	Title   string `json:"title"`
	Text    string `json:"text"`
	Sources []Ref  `json:"sources"`
}

type Question struct {
	Question    string   `json:"question"`
	Options     []string `json:"options"`
	Answer      int      `json:"answer"`
	Explanation string   `json:"explanation"`
	Sources     []Ref    `json:"sources"`
}

type Term struct {
	Term       string `json:"term"`
	Definition string `json:"definition"`
	Sources    []Ref  `json:"sources"`
}

type Guide struct {
	ID      string     `json:"id"`
	Kind    string     `json:"kind"`
	Title   string     `json:"title"`
	Summary string     `json:"summary"`
	Cards   []Card     `json:"cards"`
	Quiz    []Question `json:"quiz"`
	Terms   []Term     `json:"terms"`
	Sources []Ref      `json:"sources"`
}

type Study struct {
	Version string   `json:"version"`
	Method  []string `json:"method"`
	Guides  []Guide  `json:"guides"`
}

type rawSource struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type rawItem struct {
	Text    string   `json:"text"`
	Sources []string `json:"sources"`
}

type rawPeriod struct {
	ID    string  `json:"id"`
	Name  string  `json:"name"`
	Era   string  `json:"era"`
	Start string  `json:"start"`
	End   *string `json:"end"`
	Years struct {
		From int `json:"from"`
		To   int `json:"to"`
	} `json:"years"`
	Summary    string `json:"summary"`
	Presidents []struct {
		Name    string   `json:"name"`
		Start   string   `json:"start"`
		End     *string  `json:"end"`
		How     string   `json:"how"`
		Sources []string `json:"sources"`
	} `json:"presidents"`
	Milestones []struct {
		Date    string   `json:"date"`
		Kind    string   `json:"kind"`
		Title   string   `json:"title"`
		Text    string   `json:"text"`
		Sources []string `json:"sources"`
	} `json:"milestones"`
	Advances    []rawItem `json:"advances"`
	Critiques   []rawItem `json:"critiques"`
	Divergences []struct {
		Topic     string    `json:"topic"`
		Positions []rawItem `json:"positions"`
	} `json:"divergences"`
}

type rawStudy struct {
	Version string   `json:"version"`
	Method  []string `json:"method"`
	Guides  []struct {
		ID      string `json:"id"`
		Kind    string `json:"kind"`
		Title   string `json:"title"`
		Summary string `json:"summary"`
		Cards   []struct {
			Title   string   `json:"title"`
			Text    string   `json:"text"`
			Sources []string `json:"sources"`
		} `json:"cards"`
		Quiz []struct {
			Question    string   `json:"question"`
			Options     []string `json:"options"`
			Answer      int      `json:"answer"`
			Explanation string   `json:"explanation"`
			Sources     []string `json:"sources"`
		} `json:"quiz"`
		Terms []struct {
			Term       string   `json:"term"`
			Definition string   `json:"definition"`
			Sources    []string `json:"sources"`
		} `json:"terms"`
		Sources []string `json:"sources"`
	} `json:"guides"`
}

var milestoneKinds = map[string]bool{"constitution": true, "law": true, "economy": true, "election": true, "rupture": true, "impeachment": true, "event": true}

type resolver struct {
	catalog map[string]rawSource
	errs    []string
	used    map[string]bool
}

func newResolver() (*resolver, error) {
	r := &resolver{catalog: map[string]rawSource{}}
	if err := json.Unmarshal(sourcesJSON, &r.catalog); err != nil {
		return nil, fmt.Errorf("history sources: %w", err)
	}
	return r, nil
}

func (r *resolver) fail(format string, args ...any) {
	r.errs = append(r.errs, fmt.Sprintf(format, args...))
}

func (r *resolver) refs(where string, ids []string) []Ref {
	if len(ids) == 0 {
		r.fail("%s: no source", where)
	}
	out := make([]Ref, 0, len(ids))
	for _, id := range ids {
		s, ok := r.catalog[id]
		if !ok {
			r.fail("%s: unknown source %q", where, id)
			continue
		}
		if r.used != nil {
			r.used[id] = true
		}
		ref := Ref{ID: id, Name: s.Name}
		if s.URL != "" {
			u := s.URL
			ref.URL = &u
		}
		out = append(out, ref)
	}
	return out
}

func (r *resolver) text(where, s string) string {
	if strings.TrimSpace(s) == "" {
		r.fail("%s: empty text", where)
	}
	return s
}

func (r *resolver) date(where, s string) string {
	if _, err := time.Parse("2006-01-02", s); err != nil {
		r.fail("%s: bad date %q", where, s)
	}
	return s
}

func (r *resolver) items(where string, in []rawItem) []Item {
	out := make([]Item, 0, len(in))
	for i, it := range in {
		w := fmt.Sprintf("%s[%d]", where, i)
		out = append(out, Item{Text: r.text(w, it.Text), Sources: r.refs(w, it.Sources)})
	}
	return out
}

func (r *resolver) collected() []Ref {
	var ids []string
	for id := range r.used {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	r.used = nil
	return r.refs("collected", ids)
}

func (r *resolver) err() error {
	if len(r.errs) == 0 {
		return nil
	}
	return fmt.Errorf("history content: %s", strings.Join(r.errs, "; "))
}

type IndicatorSet map[string][]Point

func BuildTimeline(series IndicatorSet) (Timeline, error) {
	r, err := newResolver()
	if err != nil {
		return Timeline{}, err
	}
	var raw struct {
		Version string      `json:"version"`
		Method  []string    `json:"method"`
		Periods []rawPeriod `json:"periods"`
	}
	if err := json.Unmarshal(periodsJSON, &raw); err != nil {
		return Timeline{}, fmt.Errorf("history periods: %w", err)
	}
	out := Timeline{Version: raw.Version, Method: raw.Method}
	seen := map[string]bool{}
	for _, p := range raw.Periods {
		if p.ID == "" || seen[p.ID] {
			r.fail("period %q: missing or repeated id", p.ID)
		}
		seen[p.ID] = true
		r.used = map[string]bool{}
		per := Period{ID: p.ID, Name: r.text(p.ID, p.Name), Era: r.text(p.ID, p.Era), Start: r.date(p.ID, p.Start), End: p.End, Summary: r.text(p.ID, p.Summary)}
		if p.End != nil {
			r.date(p.ID, *p.End)
		}
		if p.Years.From == 0 || p.Years.To < p.Years.From {
			r.fail("%s: bad indicator years", p.ID)
		}
		for i, pr := range p.Presidents {
			w := fmt.Sprintf("%s.presidents[%d]", p.ID, i)
			if pr.End != nil {
				r.date(w, *pr.End)
			}
			per.Presidents = append(per.Presidents, President{Name: r.text(w, pr.Name), Start: r.date(w, pr.Start), End: pr.End, How: r.text(w, pr.How), Sources: r.refs(w, pr.Sources)})
		}
		for i, m := range p.Milestones {
			w := fmt.Sprintf("%s.milestones[%d]", p.ID, i)
			if !milestoneKinds[m.Kind] {
				r.fail("%s: unknown kind %q", w, m.Kind)
			}
			per.Milestones = append(per.Milestones, Milestone{Date: r.date(w, m.Date), Kind: m.Kind, Title: r.text(w, m.Title), Text: r.text(w, m.Text), Sources: r.refs(w, m.Sources)})
		}
		sort.SliceStable(per.Milestones, func(i, j int) bool { return per.Milestones[i].Date < per.Milestones[j].Date })
		per.Advances = r.items(p.ID+".advances", p.Advances)
		per.Critiques = r.items(p.ID+".critiques", p.Critiques)
		per.Divergences = []Divergence{}
		for i, d := range p.Divergences {
			w := fmt.Sprintf("%s.divergences[%d]", p.ID, i)
			if len(d.Positions) < 2 {
				r.fail("%s: a divergence needs two positions", w)
			}
			per.Divergences = append(per.Divergences, Divergence{Topic: r.text(w, d.Topic), Positions: r.items(w, d.Positions)})
		}
		per.Indicators = []PeriodIndicator{}
		for _, spec := range Series {
			if ind := Slice(spec, series[spec.ID], p.Years.From, p.Years.To); ind != nil {
				per.Indicators = append(per.Indicators, *ind)
			}
		}
		if len(per.Indicators) > 0 {
			r.used["ipeadata"] = true
		}
		per.Sources = r.collected()
		out.Periods = append(out.Periods, per)
	}
	return out, r.err()
}

func BuildStudy() (Study, error) {
	r, err := newResolver()
	if err != nil {
		return Study{}, err
	}
	var raw rawStudy
	if err := json.Unmarshal(studyJSON, &raw); err != nil {
		return Study{}, fmt.Errorf("history study: %w", err)
	}
	out := Study{Version: raw.Version, Method: raw.Method}
	for _, g := range raw.Guides {
		guide := Guide{ID: g.ID, Kind: g.Kind, Title: r.text(g.ID, g.Title), Summary: r.text(g.ID, g.Summary), Cards: []Card{}, Quiz: []Question{}, Terms: []Term{}, Sources: r.refs(g.ID, g.Sources)}
		if g.Kind != "guide" && g.Kind != "glossary" {
			r.fail("%s: unknown kind %q", g.ID, g.Kind)
		}
		for i, c := range g.Cards {
			w := fmt.Sprintf("%s.cards[%d]", g.ID, i)
			guide.Cards = append(guide.Cards, Card{Title: r.text(w, c.Title), Text: r.text(w, c.Text), Sources: r.refs(w, c.Sources)})
		}
		for i, q := range g.Quiz {
			w := fmt.Sprintf("%s.quiz[%d]", g.ID, i)
			if len(q.Options) < 2 || q.Answer < 0 || q.Answer >= len(q.Options) {
				r.fail("%s: bad options or answer", w)
			}
			guide.Quiz = append(guide.Quiz, Question{Question: r.text(w, q.Question), Options: q.Options, Answer: q.Answer, Explanation: r.text(w, q.Explanation), Sources: r.refs(w, q.Sources)})
		}
		for i, t := range g.Terms {
			w := fmt.Sprintf("%s.terms[%d]", g.ID, i)
			guide.Terms = append(guide.Terms, Term{Term: r.text(w, t.Term), Definition: r.text(w, t.Definition), Sources: r.refs(w, t.Sources)})
		}
		sort.SliceStable(guide.Terms, func(i, j int) bool {
			return strings.ToLower(guide.Terms[i].Term) < strings.ToLower(guide.Terms[j].Term)
		})
		out.Guides = append(out.Guides, guide)
	}
	return out, r.err()
}
