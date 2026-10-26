package tse

import (
	"context"
	"time"
)

const (
	OfficePresident = "president"
	OfficeGovernor  = "governor"
)

type Sections struct {
	Total   int64   `json:"total"`
	Counted int64   `json:"counted"`
	Percent float64 `json:"percent"`
}

type Votes struct {
	Valid int64 `json:"valid"`
	Blank int64 `json:"blank"`
	Null  int64 `json:"null"`
	Total int64 `json:"total"`
}

type Candidate struct {
	Number  string  `json:"number"`
	Name    string  `json:"name"`
	Party   string  `json:"party"`
	Votes   int64   `json:"votes"`
	Percent float64 `json:"percent"`
	Elected bool    `json:"elected"`
}

type Race struct {
	ID                string      `json:"id"`
	Office            string      `json:"office"`
	UF                string      `json:"uf"`
	Round             int         `json:"round"`
	Sections          Sections    `json:"sections"`
	Electorate        int64       `json:"electorate"`
	Turnout           int64       `json:"turnout"`
	Abstention        int64       `json:"abstention"`
	Votes             Votes       `json:"votes"`
	Candidates        []Candidate `json:"candidates"`
	Final             bool        `json:"final"`
	SourceGeneratedAt string      `json:"sourceGeneratedAt"`
}

func (r Race) GeneratedAt() (time.Time, bool) {
	t, err := time.Parse(time.RFC3339, r.SourceGeneratedAt)
	if err != nil {
		return time.Time{}, false
	}
	return t, true
}

func (r Race) Elected() (Candidate, bool) {
	for _, c := range r.Candidates {
		if c.Elected {
			return c, true
		}
	}
	return Candidate{}, false
}

type Definition struct {
	ID       string
	Office   string
	UF       string
	Election string
	Cargo    string
	Path     string
}

type Source interface {
	Fetch(ctx context.Context, d Definition) (Race, bool, error)
}

var governorUFs = []string{"ac", "am", "df", "es", "rn", "to"}

func Definitions() []Definition {
	defs := []Definition{{
		ID:       "presidente-br",
		Office:   OfficePresident,
		UF:       "br",
		Election: "6258",
		Cargo:    "1",
		Path:     "6258/dados/br/br-c0001-e006258-u.json",
	}}
	for _, uf := range governorUFs {
		defs = append(defs, Definition{
			ID:       "governador-" + uf,
			Office:   OfficeGovernor,
			UF:       uf,
			Election: "6260",
			Cargo:    "3",
			Path:     "6260/dados/" + uf + "/" + uf + "-c0003-e006260-u.json",
		})
	}
	return defs
}

func KnownRace(id string) bool {
	for _, d := range Definitions() {
		if d.ID == id {
			return true
		}
	}
	return false
}
