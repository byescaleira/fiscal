package publicdata

import (
	"regexp"
	"sort"
	"strconv"
	"strings"
)

const RelatedVotesShown = 10

type VoteStage int

const (
	StageProcedural VoteStage = iota
	StageOther
	StageAmendment
	StageMerit
)

type VoteRelated struct {
	ID       string  `json:"id"`
	Time     *string `json:"time"`
	Summary  string  `json:"summary"`
	Nominal  bool    `json:"nominal"`
	Approved *bool   `json:"approved"`
}

type VoteGroup struct {
	ID    string
	Main  *HouseVote
	Votes []*HouseVote
}

var (
	voteQualifier  = regexp.MustCompile(` (ressalvad[oa]s?|salvo|salvos) (o |a |os |as )?(destaques?|emendas?)( e (destaques?|emendas?))? `)
	proceduralCues = []string{"redacao final", "requerimento", "mantido o texto", "mantida a expressao", "destaque", "apreciacao preliminar", "pressupostos constitucionais", "adiamento", "retirada de pauta", "encerramento da discussao", "encerramento do encaminhamento", "quebra de intersticio", "votacao em globo", "preferencia", "inversao de pauta", "questao de ordem", "recurso"}
	notAmendment   = []string{"subemenda substitutiva", "emenda a constituicao", "emenda constitucional", "emendas do senado", "emenda do senado", "emendas da camara", "emenda da camara"}
	amendmentCues  = []string{" emenda ", " emendas ", " subemenda ", " subemendas ", " emenda aglutinativa "}
	meritCues      = []string{"substitutivo", "subemenda substitutiva", "projeto de lei", "projeto de decreto", "projeto de resolucao", "proposta de emenda", "medida provisoria", "texto base", "texto principal", " turno ", "emendas do senado", "emenda do senado", "emendas da camara", "nos termos do parecer"}
	amendmentRef   = regexp.MustCompile(`(?i)\b(sub)?emendas?\s+(aglutinativa\s+)?(n\s*[º°o.]*\s*)?(\d+)`)
)

func voteText(v *HouseVote) string {
	return voteQualifier.ReplaceAllString(" "+Fold(v.Description)+" ", " ")
}

func containsAny(s string, cues []string) bool {
	for _, c := range cues {
		if strings.Contains(s, c) {
			return true
		}
	}
	return false
}

func StageOf(v *HouseVote) VoteStage {
	d := voteText(v)
	switch {
	case containsAny(d, proceduralCues):
		return StageProcedural
	case isAmendment(d):
		return StageAmendment
	case containsAny(d, meritCues):
		return StageMerit
	}
	return StageOther
}

func isAmendment(d string) bool {
	for _, n := range notAmendment {
		d = strings.ReplaceAll(d, n, " ")
	}
	return containsAny(" "+d+" ", amendmentCues)
}

func voteTurn(v *HouseVote) int {
	d := voteText(v)
	switch {
	case strings.Contains(d, "primeiro turno"), strings.Contains(d, " 1o turno"), strings.Contains(d, " 1 turno"):
		return 1
	case strings.Contains(d, "segundo turno"), strings.Contains(d, " 2o turno"), strings.Contains(d, " 2 turno"):
		return 2
	}
	return 0
}

func voteSeq(id string) int {
	i := strings.LastIndexAny(id, "-")
	n, err := strconv.Atoi(id[i+1:])
	if err != nil {
		return 0
	}
	return n
}

func laterVote(a, b *HouseVote) bool {
	if a.Time != b.Time {
		return a.Time > b.Time
	}
	if sa, sb := voteSeq(a.ID), voteSeq(b.ID); sa != sb {
		return sa > sb
	}
	return a.ID > b.ID
}

func MainVoteFirst(a, b *HouseVote) bool {
	if sa, sb := StageOf(a), StageOf(b); sa != sb {
		return sa > sb
	}
	if a.Nominal != b.Nominal {
		return a.Nominal
	}
	return laterVote(a, b)
}

func GroupVotes(votes []*HouseVote) []VoteGroup {
	buckets := map[string][]*HouseVote{}
	var order []string
	for _, v := range votes {
		key := "vote:" + v.ID
		if prop := Slugify(PropositionKey(v.Proposition)); prop != "" {
			key = v.House + "-" + v.Date + "-" + prop
		}
		if _, ok := buckets[key]; !ok {
			order = append(order, key)
		}
		buckets[key] = append(buckets[key], v)
	}
	var groups []VoteGroup
	for _, key := range order {
		for id, members := range splitTurns(key, buckets[key]) {
			groups = append(groups, newGroup(id, members))
		}
	}
	sort.SliceStable(groups, func(i, j int) bool {
		a, b := groups[i].Main, groups[j].Main
		if a.Date != b.Date {
			return a.Date > b.Date
		}
		if laterVote(a, b) != laterVote(b, a) {
			return laterVote(a, b)
		}
		return groups[i].ID > groups[j].ID
	})
	return groups
}

func newGroup(id string, members []*HouseVote) VoteGroup {
	if strings.HasPrefix(id, "vote:") {
		id = members[0].ID
	}
	ranked := append([]*HouseVote(nil), members...)
	sort.SliceStable(ranked, func(i, j int) bool { return MainVoteFirst(ranked[i], ranked[j]) })
	ordered := append([]*HouseVote(nil), members...)
	sort.SliceStable(ordered, func(i, j int) bool { return laterVote(ordered[j], ordered[i]) })
	return VoteGroup{ID: id, Main: ranked[0], Votes: ordered}
}

func splitTurns(key string, members []*HouseVote) map[string][]*HouseVote {
	starts := map[int]string{}
	var turns []int
	for _, v := range members {
		t := voteTurn(v)
		if t == 0 {
			continue
		}
		start, seen := starts[t]
		if !seen {
			turns = append(turns, t)
			starts[t] = v.Time
			continue
		}
		if v.Time != "" && (start == "" || v.Time < start) {
			starts[t] = v.Time
		}
	}
	if len(turns) < 2 {
		return map[string][]*HouseVote{key: members}
	}
	sort.Ints(turns)
	out := map[string][]*HouseVote{}
	for _, v := range members {
		t := voteTurn(v)
		if t == 0 {
			t = turns[0]
			for _, c := range turns {
				if v.Time != "" && starts[c] != "" && starts[c] <= v.Time {
					t = c
				}
			}
		}
		id := key + "-turno-" + strconv.Itoa(t)
		out[id] = append(out[id], v)
	}
	return out
}

func (g VoteGroup) RelatedTo(v *HouseVote) []VoteRelated {
	out := []VoteRelated{}
	for _, o := range g.Votes {
		if o == v {
			continue
		}
		out = append(out, VoteRelated{ID: o.ID, Time: strPtr(o.Time), Summary: ShortVoteSummary(o), Nominal: o.Nominal, Approved: o.Approved})
	}
	if len(out) > RelatedVotesShown {
		out = out[:RelatedVotesShown]
	}
	return out
}

func ShortVoteSummary(v *HouseVote) string {
	d := voteText(v)
	switch {
	case strings.Contains(d, "redacao final"):
		return "Redação final"
	case strings.Contains(d, "requerimento de urgencia"):
		return "Requerimento de urgência"
	case strings.Contains(d, "requerimento"):
		return "Requerimento"
	case strings.Contains(d, "mantido o texto"), strings.Contains(d, "mantida a expressao"):
		return "Destaque: texto mantido"
	case strings.Contains(d, "destaque"):
		return "Destaque"
	case strings.Contains(d, "apreciacao preliminar"), strings.Contains(d, "pressupostos constitucionais"):
		return "Pressupostos de relevância e urgência"
	case strings.Contains(d, "emendas do senado"), strings.Contains(d, "emenda do senado"):
		return "Emendas do Senado"
	case strings.Contains(d, "substitutivo do senado"):
		return "Substitutivo do Senado"
	case strings.Contains(d, "subemenda substitutiva"):
		return "Subemenda substitutiva"
	case strings.Contains(d, "substitutivo"):
		return "Substitutivo"
	case isAmendment(d):
		if m := amendmentRef.FindStringSubmatch(v.Description); m != nil {
			if m[1] != "" {
				return "Subemenda nº " + m[4]
			}
			return "Emenda nº " + m[4]
		}
		return "Emenda"
	case strings.Contains(d, "primeiro turno"):
		return "Texto em 1º turno"
	case strings.Contains(d, "segundo turno"):
		return "Texto em 2º turno"
	case containsAny(d, meritCues):
		return "Texto principal"
	}
	return firstSentence(v.Description, 80)
}

func firstSentence(s string, limit int) string {
	s = strings.TrimSpace(s)
	if i := strings.Index(s, ". "); i > 0 {
		s = s[:i]
	}
	s = strings.TrimSuffix(s, ".")
	if r := []rune(s); len(r) > limit {
		return strings.TrimSpace(string(r[:limit-1])) + "…"
	}
	return s
}
