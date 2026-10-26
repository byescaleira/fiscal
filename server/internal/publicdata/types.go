package publicdata

type Source struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	URL       string `json:"url"`
	UpdatedAt string `json:"updatedAt"`
}

const (
	OfficePresident      = "president"
	OfficeVicePresident  = "vicePresident"
	OfficeSenator        = "senator"
	OfficeFederalDeputy  = "federalDeputy"
	OfficeGovernor       = "governor"
	OfficeViceGovernor   = "viceGovernor"
	OfficeStateDeputy    = "stateDeputy"
	StatusInOffice       = "inOffice"
	StatusElected        = "electedAwaiting"
	StatusOnLeave        = "onLeave"
	CoverageAvailable    = "available"
	CoverageNotPublished = "notPublished"
	CoverageNotLoaded    = "notLoaded"
)

type PersonCard struct {
	Slug   string  `json:"slug"`
	Name   string  `json:"name"`
	Office string  `json:"office"`
	UF     string  `json:"uf"`
	Party  string  `json:"party"`
	Photo  *string `json:"photo"`
	Status string  `json:"status"`
	Gender *string `json:"gender"`
}

type RepresentativeGroup struct {
	Level  string       `json:"level"`
	Office string       `json:"office"`
	Title  string       `json:"title"`
	People []PersonCard `json:"people"`
}

type Counts struct {
	People  int `json:"people"`
	Federal int `json:"federal"`
	State   int `json:"state"`
	Places  int `json:"places"`
}

type Meta struct {
	GeneratedAt string   `json:"generatedAt"`
	Sources     []Source `json:"sources"`
	Counts      Counts   `json:"counts"`
}

type PlaceEntry struct {
	Code string `json:"code"`
	Name string `json:"name"`
	UF   string `json:"uf"`
}

type PlaceFile struct {
	UF      string                `json:"uf"`
	Name    string                `json:"name"`
	Groups  []RepresentativeGroup `json:"groups"`
	Sources []Source              `json:"sources"`
}

type Mandate struct {
	Start *string `json:"start"`
	End   *string `json:"end"`
}

type Contact struct {
	Email  *string `json:"email"`
	Phone  *string `json:"phone"`
	Office *string `json:"office"`
}

type Salary struct {
	MonthlyCents int64  `json:"monthlyCents"`
	Law          string `json:"law"`
}

type Attendance struct {
	Present  int `json:"present"`
	Eligible int `json:"eligible"`
}

type Numbers struct {
	Attendance           *Attendance `json:"attendance"`
	Proposals            *int        `json:"proposals"`
	Laws                 *int        `json:"laws"`
	Speeches             *int        `json:"speeches"`
	Votes                *int        `json:"votes"`
	QuotaCents           *int64      `json:"quotaCents"`
	AssetsCents          *int64      `json:"assetsCents"`
	CampaignRevenueCents *int64      `json:"campaignRevenueCents"`
	LastElectionVotes    *int64      `json:"lastElectionVotes"`
}

type YearSummary struct {
	Year       int    `json:"year"`
	Present    *int   `json:"present"`
	Eligible   *int   `json:"eligible"`
	Proposals  *int   `json:"proposals"`
	Laws       *int   `json:"laws"`
	Speeches   *int   `json:"speeches"`
	Votes      *int   `json:"votes"`
	QuotaCents *int64 `json:"quotaCents"`
}

type ThemeCount struct {
	Key       string `json:"key"`
	Proposals int    `json:"proposals"`
	Speeches  int    `json:"speeches"`
}

type Committee struct {
	Name  string  `json:"name"`
	Role  string  `json:"role"`
	Start *string `json:"start"`
	End   *string `json:"end"`
}

type AssetItem struct {
	Kind  string `json:"kind"`
	Cents int64  `json:"cents"`
}

type AssetYear struct {
	Year       int         `json:"year"`
	TotalCents int64       `json:"totalCents"`
	Items      []AssetItem `json:"items"`
}

type Campaign struct {
	Year         int     `json:"year"`
	Office       string  `json:"office"`
	Result       *string `json:"result"`
	RevenueCents *int64  `json:"revenueCents"`
	ExpenseCents *int64  `json:"expenseCents"`
}

type TimelineEntry struct {
	Year   int     `json:"year"`
	Office string  `json:"office"`
	Place  string  `json:"place"`
	Party  *string `json:"party"`
	Result *string `json:"result"`
	Votes  *int64  `json:"votes"`
}

type Coverage struct {
	Kind   string `json:"kind"`
	Status string `json:"status"`
	Source string `json:"source"`
}

type Profile struct {
	Slug       string          `json:"slug"`
	Name       string          `json:"name"`
	CivilName  *string         `json:"civilName"`
	Office     string          `json:"office"`
	UF         string          `json:"uf"`
	Party      string          `json:"party"`
	Photo      *string         `json:"photo"`
	Status     string          `json:"status"`
	Gender     *string         `json:"gender"`
	Mandate    Mandate         `json:"mandate"`
	BirthDate  *string         `json:"birthDate"`
	BirthPlace *string         `json:"birthPlace"`
	Education  *string         `json:"education"`
	Contact    *Contact        `json:"contact"`
	Salary     *Salary         `json:"salary"`
	Numbers    Numbers         `json:"numbers"`
	Years      []YearSummary   `json:"years"`
	Themes     []ThemeCount    `json:"themes"`
	Committees []Committee     `json:"committees"`
	Assets     []AssetYear     `json:"assets"`
	Campaigns  []Campaign      `json:"campaigns"`
	Timeline   []TimelineEntry `json:"timeline"`
	Coverage   []Coverage      `json:"coverage"`
	Sources    []Source        `json:"sources"`
}

type PersonVote struct {
	VoteID        string   `json:"voteId"`
	Date          string   `json:"date"`
	Proposition   *string  `json:"proposition"`
	Summary       string   `json:"summary"`
	Vote          string   `json:"vote"`
	PartyGuidance *string  `json:"partyGuidance"`
	Approved      *bool    `json:"approved"`
	Themes        []string `json:"themes"`
}

type Proposal struct {
	ID           string   `json:"id"`
	Kind         string   `json:"kind"`
	Number       int      `json:"number"`
	Year         int      `json:"year"`
	Summary      string   `json:"summary"`
	PlainSummary string   `json:"plainSummary"`
	CanBecomeLaw bool     `json:"canBecomeLaw"`
	Themes       []string `json:"themes"`
	URL          *string  `json:"url"`
}

type Speech struct {
	Date    string  `json:"date"`
	Kind    string  `json:"kind"`
	Summary string  `json:"summary"`
	URL     *string `json:"url"`
}

type Expense struct {
	ID       string  `json:"id"`
	Year     int     `json:"year"`
	Month    int     `json:"month"`
	Category string  `json:"category"`
	Supplier string  `json:"supplier"`
	Document *string `json:"document"`
	Cents    int64   `json:"cents"`
	URL      *string `json:"url"`
}

type ListFile[T any] struct {
	Items []T `json:"items"`
	Total int `json:"total"`
}

type MonthCents struct {
	Month int   `json:"month"`
	Cents int64 `json:"cents"`
}

type CategoryTotal struct {
	Category string `json:"category"`
	Cents    int64  `json:"cents"`
	Count    int    `json:"count"`
}

type ExpenseFile struct {
	Items      []Expense       `json:"items"`
	TotalCents int64           `json:"totalCents"`
	ByMonth    []MonthCents    `json:"byMonth"`
	ByCategory []CategoryTotal `json:"byCategory"`
}

type VoteSummary struct {
	ID           string   `json:"id"`
	House        string   `json:"house"`
	Date         string   `json:"date"`
	Time         *string  `json:"time"`
	Proposition  *string  `json:"proposition"`
	Kind         *string  `json:"kind"`
	Summary      string   `json:"summary"`
	PlainSummary *string  `json:"plainSummary"`
	Themes       []string `json:"themes"`
	Result       *string  `json:"result"`
	Approved     *bool    `json:"approved"`
	Nominal      bool     `json:"nominal"`
	Yes          *int     `json:"yes"`
	No           *int     `json:"no"`
	Others       *int     `json:"others"`
}

type PartyGuidance struct {
	Party    string `json:"party"`
	Guidance string `json:"guidance"`
}

type PartyTally struct {
	Party  string `json:"party"`
	Yes    int    `json:"yes"`
	No     int    `json:"no"`
	Others int    `json:"others"`
}

type VotePerson struct {
	Slug  *string `json:"slug"`
	Name  string  `json:"name"`
	Party string  `json:"party"`
	UF    string  `json:"uf"`
	Vote  string  `json:"vote"`
}

type VoteDetail struct {
	VoteSummary
	Quorum   *string         `json:"quorum"`
	Guidance []PartyGuidance `json:"guidance"`
	Parties  []PartyTally    `json:"parties"`
	People   []VotePerson    `json:"people"`
	Sources  []Source        `json:"sources"`
}

type AgendaItem struct {
	Proposition string   `json:"proposition"`
	Summary     string   `json:"summary"`
	Status      *string  `json:"status"`
	Themes      []string `json:"themes"`
	URL         *string  `json:"url"`
}

type AgendaHouse struct {
	House       string       `json:"house"`
	InSession   bool         `json:"inSession"`
	NextSession *string      `json:"nextSession"`
	Items       []AgendaItem `json:"items"`
}

type AgendaFile struct {
	Date   string        `json:"date"`
	Houses []AgendaHouse `json:"houses"`
}

type CategoryCents struct {
	Category string `json:"category"`
	Cents    int64  `json:"cents"`
}

type QuotaBlock struct {
	FederalDeputiesCents *int64          `json:"federalDeputiesCents"`
	SenatorsCents        *int64          `json:"senatorsCents"`
	ByCategory           []CategoryCents `json:"byCategory"`
}

type OfficeSalary struct {
	Office       string `json:"office"`
	MonthlyCents int64  `json:"monthlyCents"`
	Law          string `json:"law"`
}

type OriginCents struct {
	Origin string `json:"origin"`
	Cents  int64  `json:"cents"`
}

type CampaignBlock struct {
	Year         int           `json:"year"`
	RevenueCents int64         `json:"revenueCents"`
	ExpenseCents int64         `json:"expenseCents"`
	ByOrigin     []OriginCents `json:"byOrigin"`
}

type StateCents struct {
	UF    string `json:"uf"`
	Cents int64  `json:"cents"`
}

type RevenueBlock struct {
	Year       int          `json:"year"`
	TotalCents int64        `json:"totalCents"`
	ByState    []StateCents `json:"byState"`
}

type MoneyOverview struct {
	Year      int            `json:"year"`
	Quota     QuotaBlock     `json:"quota"`
	Salaries  []OfficeSalary `json:"salaries"`
	Campaigns *CampaignBlock `json:"campaigns"`
	Revenue   *RevenueBlock  `json:"revenue"`
	Sources   []Source       `json:"sources"`
}

type TodayEvent struct {
	Kind    string   `json:"kind"`
	Title   string   `json:"title"`
	Summary string   `json:"summary"`
	Themes  []string `json:"themes"`
	Ref     *string  `json:"ref"`
}

type TodayDigest struct {
	Date    string       `json:"date"`
	Events  []TodayEvent `json:"events"`
	Sources []Source     `json:"sources"`
}
