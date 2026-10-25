package tse

import (
	"context"
	"embed"
	"fmt"
	"hash/fnv"
	"math"
	"time"
)

//go:embed seed/*.json
var seedFS embed.FS

type SimSource struct {
	start    time.Time
	now      func() time.Time
	duration time.Duration
	base     map[string]Race
	order    map[string]int
}

func NewSimSource(now func() time.Time, duration time.Duration) (*SimSource, error) {
	if now == nil {
		now = time.Now
	}
	s := &SimSource{start: now(), now: now, duration: duration, base: map[string]Race{}, order: map[string]int{}}
	for i, d := range Definitions() {
		file := d.Path[len(d.Election+"/dados/"+d.UF+"/"):]
		data, err := seedFS.ReadFile("seed/" + file)
		if err != nil {
			return nil, fmt.Errorf("seed %s: %w", d.ID, err)
		}
		r, err := Parse(d, data)
		if err != nil {
			return nil, err
		}
		s.base[d.ID] = r
		s.order[d.ID] = i
	}
	return s, nil
}

func seedHash(id string) uint32 {
	h := fnv.New32a()
	h.Write([]byte(id))
	return h.Sum32()
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

func (s *SimSource) Fetch(_ context.Context, d Definition) (Race, bool, error) {
	base, ok := s.base[d.ID]
	if !ok {
		return Race{}, false, fmt.Errorf("simulate %s: unknown race", d.ID)
	}
	n := len(s.base)
	length := s.duration
	if n > 1 {
		length = time.Duration(float64(s.duration) * (0.7 + 0.3*float64(s.order[d.ID])/float64(n-1)))
	}
	now := s.now()
	elapsed := now.Sub(s.start)
	f := 1.0
	if length > 0 {
		f = math.Min(1, math.Max(0, float64(elapsed)/float64(length)))
	}
	h := seedHash(d.ID)
	margin := 0.01 + float64(h%70)/1000
	leader := int(h/70) % 2
	r := base
	r.Candidates = make([]Candidate, len(base.Candidates))
	copy(r.Candidates, base.Candidates)
	ts := r.Sections.Total
	r.Sections.Counted = int64(math.Round(float64(ts) * f))
	if ts > 0 {
		r.Sections.Percent = round2(100 * float64(r.Sections.Counted) / float64(ts))
	}
	r.Turnout = int64(math.Round(float64(r.Electorate) * 0.78 * f))
	r.Abstention = int64(math.Round(float64(r.Electorate)*f)) - r.Turnout
	valid := int64(math.Round(float64(r.Turnout) * 0.94))
	blank := int64(math.Round(float64(r.Turnout) * 0.02))
	r.Votes = Votes{Valid: valid, Blank: blank, Null: r.Turnout - valid - blank, Total: r.Turnout}
	wobble := (1 - f) * 0.05 * math.Sin(elapsed.Seconds()/37+float64(h%13))
	share := 0.5 + margin + wobble
	for i := range r.Candidates {
		r.Candidates[i].Votes = 0
		r.Candidates[i].Percent = 0
		r.Candidates[i].Elected = false
	}
	if len(r.Candidates) == 1 {
		r.Candidates[0].Votes = valid
	} else if len(r.Candidates) >= 2 {
		if leader >= len(r.Candidates) {
			leader = 0
		}
		other := 1 - leader
		r.Candidates[leader].Votes = int64(math.Round(float64(valid) * share))
		r.Candidates[other].Votes = valid - r.Candidates[leader].Votes
	}
	if valid > 0 {
		for i := range r.Candidates {
			r.Candidates[i].Percent = round2(100 * float64(r.Candidates[i].Votes) / float64(valid))
		}
	}
	r.Final = f >= 1
	SortCandidates(r.Candidates)
	if r.Final && len(r.Candidates) > 0 {
		r.Candidates[0].Elected = true
	}
	r.SourceGeneratedAt = FormatGenerated(now.Truncate(time.Second))
	return r, true, nil
}
