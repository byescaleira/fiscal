package datastore

import (
	"fmt"
	"strings"
)

type table struct {
	name    string
	columns []string
	indexes [][]string
	stamp   string
}

var (
	tablePeople        = table{name: "people", columns: []string{"name", "office", "uf", "party", "status", "house", "slug"}, indexes: [][]string{{"slug"}, {"office", "uf"}}}
	tableMandates      = table{name: "mandates", columns: []string{"person_key", "office", "uf", "status", "party", "start_date", "end_date"}, indexes: [][]string{{"person_key"}}}
	tableVotes         = table{name: "votes", columns: []string{"house", "date", "proposition"}, indexes: [][]string{{"date"}}}
	tableBallots       = table{name: "ballots", columns: []string{"vote_id", "person_key", "vote", "party", "uf"}, indexes: [][]string{{"vote_id"}, {"person_key"}}}
	tablePropositions  = table{name: "propositions", columns: []string{"person_key", "year", "kind", "number"}, indexes: [][]string{{"person_key"}}}
	tableExpenses      = table{name: "expenses", columns: []string{"person_key", "year", "month", "category", "cents"}, indexes: [][]string{{"person_key", "year"}}}
	tablePlaces        = table{name: "places", columns: []string{"kind", "code", "name", "uf"}, indexes: [][]string{{"uf"}}}
	tableCityOfficials = table{name: "city_officials", columns: []string{"city_code", "person_key", "office", "party", "slug"}, indexes: [][]string{{"city_code"}}}
	tableSnapshots     = table{name: "snapshots", columns: []string{"fetched_at"}, stamp: "fetched_at"}
	tableSeries        = table{name: "series", columns: []string{"series_id", "scope", "date", "value"}, indexes: [][]string{{"series_id", "scope", "date"}}}
)

var versioned = []table{tablePeople, tableMandates, tableVotes, tableBallots, tablePropositions, tableExpenses, tablePlaces, tableCityOfficials, tableSnapshots, tableSeries}

func (t table) createSQL() string {
	var b strings.Builder
	fmt.Fprintf(&b, "CREATE TABLE %s (\n\tid INTEGER PRIMARY KEY,\n\tsource TEXT NOT NULL,\n\t\"key\" TEXT NOT NULL,\n", t.name)
	for _, c := range t.columns {
		kind := "TEXT"
		switch c {
		case "year", "month", "cents", "number":
			kind = "INTEGER"
		case "value":
			kind = "REAL"
		}
		fmt.Fprintf(&b, "\t%s %s,\n", c, kind)
	}
	b.WriteString("\thash TEXT NOT NULL,\n\tpayload TEXT NOT NULL,\n\tvalid_from TEXT NOT NULL,\n\tvalid_to TEXT,\n\tfirst_run INTEGER NOT NULL,\n\tseen_run INTEGER NOT NULL\n);\n")
	fmt.Fprintf(&b, "CREATE UNIQUE INDEX %s_current ON %s (source, \"key\") WHERE valid_to IS NULL;\n", t.name, t.name)
	fmt.Fprintf(&b, "CREATE INDEX %s_history ON %s (source, \"key\", valid_from);\n", t.name, t.name)
	fmt.Fprintf(&b, "CREATE INDEX %s_seen ON %s (source, seen_run) WHERE valid_to IS NULL;\n", t.name, t.name)
	for _, idx := range t.indexes {
		fmt.Fprintf(&b, "CREATE INDEX %s_%s ON %s (%s) WHERE valid_to IS NULL;\n", t.name, strings.Join(idx, "_"), t.name, strings.Join(idx, ", "))
	}
	return b.String()
}

func migrations() []string {
	var first strings.Builder
	first.WriteString(`CREATE TABLE sources_runs (
	id INTEGER PRIMARY KEY,
	run_id INTEGER,
	kind TEXT NOT NULL,
	source TEXT NOT NULL,
	started_at TEXT NOT NULL,
	finished_at TEXT,
	status TEXT NOT NULL,
	counts TEXT NOT NULL DEFAULT '{}',
	error TEXT
);
CREATE INDEX sources_runs_source ON sources_runs (source, kind, id);
CREATE INDEX sources_runs_run ON sources_runs (run_id);
`)
	for _, t := range versioned {
		first.WriteString(t.createSQL())
	}
	return []string{first.String()}
}
