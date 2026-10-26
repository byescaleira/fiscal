package camara

import (
	"encoding/json"
	"fmt"
	"html"
	"regexp"
	"strconv"
	"strings"
)

const (
	APIBase     = "https://dadosabertos.camara.leg.br/api/v2"
	FilesBase   = "https://dadosabertos.camara.leg.br/arquivos"
	SiteURL     = "https://dadosabertos.camara.leg.br"
	PlenaryID   = 180
	Legislature = 57
)

func AnnualURL(set string, year int) string {
	return fmt.Sprintf("%s/%s/csv/%s-%d.csv", FilesBase, set, set, year)
}

func CEAPURL(year int) string {
	return fmt.Sprintf("https://www.camara.leg.br/cotas/Ano-%d.csv.zip", year)
}

func CommitteesURL(legislature int) string {
	return fmt.Sprintf("%s/orgaosDeputados/csv/orgaosDeputados-L%d.csv", FilesBase, legislature)
}

func PropositionURL(id int64) string {
	return fmt.Sprintf("https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=%d", id)
}

func VoteURL(id string) string {
	return APIBase + "/votacoes/" + id
}

type Deputy struct {
	ID          int64
	Name        string
	Party       string
	UF          string
	Photo       string
	Email       string
	Legislature int
}

type Detail struct {
	Deputy
	CivilName     string
	ElectoralName string
	CPF           string
	BirthDate     string
	BirthCity     string
	BirthUF       string
	Education     string
	Sex           string
	Situation     string
	Condition     string
	Building      string
	Room          string
	Phone         string
	OfficeEmail   string
}

type Status struct {
	Time        string
	Situation   string
	Condition   string
	Description string
	Party       string
	Legislature int
}

type Speech struct {
	Start    string
	Kind     string
	Summary  string
	Keywords string
	URL      string
}

type Authorship struct {
	PropositionID int64
	DeputyID      int64
	Order         int
	Proponent     bool
}

type Proposition struct {
	ID         int64
	Kind       string
	Number     int
	Year       int
	Ementa     string
	Keywords   string
	Presented  string
	URL        string
	Situation  string
	StatusDate string
}

type Vote struct {
	ID          string
	Date        string
	Registered  string
	OrganID     int64
	Organ       string
	EventID     int64
	Approved    *bool
	Yes         int
	No          int
	Others      int
	Description string
}

type Ballot struct {
	VoteID   string
	DeputyID int64
	Name     string
	Party    string
	UF       string
	Vote     string
}

type Guidance struct {
	VoteID   string
	Bloc     string
	Guidance string
}

type VoteProposition struct {
	VoteID        string
	PropositionID int64
	Title         string
	Ementa        string
	Kind          string
	Number        int
	Year          int
}

type Presence struct {
	EventID  int64
	DeputyID int64
}

type Event struct {
	ID          int64
	Start       string
	End         string
	Situation   string
	Description string
	Type        string
	URL         string
}

type Expense struct {
	DeputyID   int64
	CPF        string
	Year       int
	Month      int
	Category   string
	Supplier   string
	SupplierID string
	Number     string
	Cents      int64
	DocumentID string
	URL        string
}

type Committee struct {
	DeputyID int64
	Acronym  string
	Name     string
	Role     string
	Start    string
	End      string
}

type AgendaItem struct {
	Order         int
	Topic         string
	Regime        string
	Title         string
	PropositionID int64
	Kind          string
	Number        int
	Year          int
	Ementa        string
}

func idFromURI(uri string) int64 {
	uri = strings.TrimRight(strings.TrimSpace(uri), "/")
	i := strings.LastIndexByte(uri, '/')
	n, err := strconv.ParseInt(uri[i+1:], 10, 64)
	if err != nil {
		return 0
	}
	return n
}

var tags = regexp.MustCompile(`<[^>]*>`)
var spaces = regexp.MustCompile(`\s+`)

func CleanText(s string) string {
	s = tags.ReplaceAllString(s, " ")
	s = html.UnescapeString(s)
	s = strings.ReplaceAll(s, " ", " ")
	return strings.TrimSpace(spaces.ReplaceAllString(s, " "))
}

func decode(data []byte, v any) error {
	if err := json.Unmarshal(data, v); err != nil {
		return fmt.Errorf("camara: %w", err)
	}
	return nil
}

func atoi(s string) int {
	n, _ := strconv.Atoi(strings.TrimSpace(s))
	return n
}

func atoi64(s string) int64 {
	n, _ := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	return n
}
