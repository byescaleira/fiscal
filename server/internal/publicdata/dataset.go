package publicdata

import "time"

const (
	HouseCamara = "camara"
	HouseSenado = "senado"
)

type Role struct {
	Office       string
	UF           string
	Status       string
	Party        string
	MandateStart string
	MandateEnd   string
}

type Candidacy struct {
	Year         int
	Office       string
	UF           string
	Party        string
	Result       string
	Elected      bool
	SQ           string
	CPF          string
	Name         string
	BallotName   string
	BirthDate    string
	BirthUF      string
	Education    string
	Votes        *int64
	RevenueCents *int64
	ExpenseCents *int64
	Assets       []AssetItem
	AssetsLoaded bool
}

type RawProposal struct {
	ID       string
	Kind     string
	Number   int
	Year     int
	Ementa   string
	Keywords string
	URL      string
}

type RawSpeech struct {
	Date     string
	Kind     string
	Summary  string
	Keywords string
	URL      string
}

type YearActivity struct {
	Year      int
	Present   *int
	Eligible  *int
	Proposals []RawProposal
	Speeches  []RawSpeech
	Expenses  []Expense
}

type Person struct {
	Keys        []string
	Name        string
	CivilName   string
	Roles       []Role
	Photo       string
	BirthDate   string
	BirthPlace  string
	Education   string
	Contact     *Contact
	House       string
	Assembly    string
	Committees  []Committee
	Candidacies []Candidacy
	Activity    map[int]*YearActivity
	Coverage    map[string]Coverage
	SourceIDs   []string
	CPF         string
	HouseID     int64
}

func (p *Person) AddSource(id string) {
	for _, s := range p.SourceIDs {
		if s == id {
			return
		}
	}
	p.SourceIDs = append(p.SourceIDs, id)
}

func (p *Person) AddKey(k string) {
	if k == "" || hasKey(p, k) {
		return
	}
	p.Keys = append(p.Keys, k)
}

func (p *Person) HasRole(office, uf, status string) bool {
	for _, r := range p.Roles {
		if r.Office == office && r.UF == uf && r.Status == status {
			return true
		}
	}
	return false
}

func (p *Person) Primary() Role {
	best := -1
	for i, r := range p.Roles {
		if best < 0 || roleRank(r) < roleRank(p.Roles[best]) {
			best = i
		}
	}
	if best < 0 {
		return Role{}
	}
	return p.Roles[best]
}

func roleRank(r Role) int {
	status := map[string]int{StatusInOffice: 0, StatusOnLeave: 1, StatusElected: 2}[r.Status]
	return status*100 + officeRank(r.Office)
}

func officeRank(o string) int {
	switch o {
	case OfficePresident:
		return 0
	case OfficeVicePresident:
		return 1
	case OfficeGovernor:
		return 2
	case OfficeViceGovernor:
		return 3
	case OfficeSenator:
		return 4
	case OfficeFederalDeputy:
		return 5
	case OfficeStateDeputy:
		return 6
	}
	return 9
}

func Federal(office string) bool {
	switch office {
	case OfficePresident, OfficeVicePresident, OfficeSenator, OfficeFederalDeputy:
		return true
	}
	return false
}

type Ballot struct {
	PersonKey string
	Name      string
	Party     string
	UF        string
	Vote      string
	Present   bool
}

type HouseVote struct {
	ID          string
	House       string
	Date        string
	Time        string
	Proposition string
	Kind        string
	Description string
	Ementa      string
	Approved    *bool
	Result      string
	Nominal     bool
	Yes         *int
	No          *int
	Others      *int
	Guidance    []PartyGuidance
	Ballots     []Ballot
}

type RawAgendaItem struct {
	Proposition string
	Ementa      string
	Status      string
	URL         string
}

type RawAgendaHouse struct {
	House       string
	InSession   bool
	NextSession string
	Items       []RawAgendaItem
	Sessions    []RawSession
}

type RawSession struct {
	Title   string
	Summary string
	URL     string
}

type LawEvent struct {
	ID     string
	Title  string
	Ementa string
	Date   string
}

type RaceEvent struct {
	Title   string
	Summary string
}

type QuotaTotals struct {
	Year            int
	FederalDeputies *int64
	Senators        *int64
	ByCategory      map[string]int64
}

type CampaignTotals struct {
	Year     int
	Revenue  int64
	Expense  int64
	ByOrigin map[string]int64
}

type Dataset struct {
	GeneratedAt    time.Time
	Today          string
	Years          []int
	Sources        map[string]Source
	People         []*Person
	Votes          []*HouseVote
	Municipalities []PlaceEntry
	States         []PlaceEntry
	Agenda         []RawAgendaHouse
	Laws           []LawEvent
	Races          []RaceEvent
	Quota          QuotaTotals
	Campaigns      *CampaignTotals
	Revenue        *RevenueBlock
	Salaries       []OfficeSalary
	SalarySource   map[string]string
}
