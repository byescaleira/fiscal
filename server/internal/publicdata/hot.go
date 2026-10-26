package publicdata

import (
	"time"
)

const HotBaseVersion = 1

var HotPaths = []string{"today.json", "agenda/today.json", "votes/recent.json"}

type HotBase struct {
	Version  int
	Recent   []*HouseVote
	Laws     []LawEvent
	Sources  map[string]Source
	KeySlugs map[string]string
}

type HotInput struct {
	Base        HotBase
	GeneratedAt time.Time
	Today       string
	Agenda      []RawAgendaHouse
	Votes       []*HouseVote
	Races       []RaceEvent
}

func (b *builder) hotBase() HotBase {
	all := append([]*HouseVote(nil), b.ds.Votes...)
	sortVotes(all)
	if len(all) > RecentVotes {
		all = all[:RecentVotes]
	}
	recent := make([]*HouseVote, 0, len(all))
	for _, v := range all {
		c := *v
		c.Ballots = nil
		c.Guidance = nil
		recent = append(recent, &c)
	}
	keys := make(map[string]string, len(b.byKey))
	for k, p := range b.byKey {
		if slug, ok := b.slugs[p]; ok && k != "" {
			keys[k] = slug
		}
	}
	return HotBase{Version: HotBaseVersion, Recent: recent, Laws: append([]LawEvent(nil), b.ds.Laws...), Sources: b.ds.Sources, KeySlugs: keys}
}

func MergeVotes(base, fresh []*HouseVote) []*HouseVote {
	out := append([]*HouseVote(nil), base...)
	idx := make(map[string]int, len(out))
	for i, v := range out {
		idx[v.ID] = i
	}
	for _, v := range fresh {
		if i, ok := idx[v.ID]; ok {
			out[i] = v
			continue
		}
		idx[v.ID] = len(out)
		out = append(out, v)
	}
	return out
}

func BuildHot(in HotInput) []File {
	ds := &Dataset{GeneratedAt: in.GeneratedAt, Today: in.Today, Sources: in.Base.Sources, Votes: MergeVotes(in.Base.Recent, in.Votes), Agenda: in.Agenda, Laws: in.Base.Laws, Races: in.Races}
	if ds.Sources == nil {
		ds.Sources = map[string]Source{}
	}
	fresh := make(map[string]bool, len(in.Votes))
	for _, v := range in.Votes {
		fresh[v.ID] = true
	}
	b := &builder{ds: ds, byKey: map[string]*Person{}, slugs: map[*Person]string{}, keySlugs: in.Base.KeySlugs}
	b.votes(func(v *HouseVote) bool { return fresh[v.ID] })
	b.agenda()
	b.today()
	return b.files
}
