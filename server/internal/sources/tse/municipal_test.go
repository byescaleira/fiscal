package tse

import (
	"strings"
	"testing"
)

func readOfficials(t *testing.T, names ...string) ([]Official, map[string]string) {
	t.Helper()
	var got []Official
	units := map[string]string{}
	for _, n := range names {
		err := ReadOfficials(openFixture(t, n), func(uf, code, name string) { units[uf+":"+code] = name }, func(o Official) { got = append(got, o) })
		if err != nil {
			t.Fatal(err)
		}
	}
	return got, units
}

func TestReadOfficialsKeepsOnlyTheElectedAndHashesTheTitle(t *testing.T) {
	got, units := readOfficials(t, "consulta_cand_2024_AC.csv")
	if len(units) != 2 || units["AC:01120"] != "ACRELÂNDIA" || units["AC:01490"] != "XAPURI" {
		t.Fatalf("units = %v", units)
	}
	counts := map[int]int{}
	for _, o := range got {
		counts[o.Office]++
		if !Elected(o.Result) || !Municipal(o.Office) {
			t.Fatalf("official = %+v", o)
		}
		if !strings.HasPrefix(o.Key, "titulo:") || strings.Contains(o.Key, "0000000") {
			t.Fatalf("title must be hashed: %q", o.Key)
		}
	}
	if counts[Mayor] != 2 || counts[ViceMayor] != 2 || counts[Councilor] != 18 {
		t.Fatalf("counts = %v", counts)
	}
	var mayor Official
	for _, o := range got {
		if o.SQ == "10002180860" {
			mayor = o
		}
	}
	if mayor.BallotName != "MAXSUEL MAIA" || mayor.Party != "PP" || mayor.Date != "2024-10-06" || mayor.Election != "619" || mayor.Unit != "01490" {
		t.Fatalf("mayor = %+v", mayor)
	}
}

func TestSeatedPrefersTheLatestElectionPerOffice(t *testing.T) {
	got, _ := readOfficials(t, "consulta_cand_2024_AP.csv")
	seated := Seated(got)
	byOffice := map[int][]string{}
	for _, o := range seated {
		byOffice[o.Office] = append(byOffice[o.Office], o.BallotName)
	}
	if strings.Join(byOffice[Mayor], ",") != "INACIO" || strings.Join(byOffice[ViceMayor], ",") != "OSCAR GISLAEL" {
		t.Fatalf("hall = %v", byOffice)
	}
	if len(byOffice[Councilor]) != 11 {
		t.Fatalf("council = %v", byOffice[Councilor])
	}
}

func TestReadOfficialVotesSumsZonesByRound(t *testing.T) {
	votes := map[string]int64{}
	err := ReadOfficialVotes(openFixture(t, "votacao_candidato_munzona_2024_AC.csv"), func(sq string, round int, n int64) {
		if round != 1 {
			t.Fatalf("round = %d", round)
		}
		votes[sq] += n
	})
	if err != nil {
		t.Fatal(err)
	}
	if votes["10002180860"] <= 0 || len(votes) == 0 {
		t.Fatalf("votes = %v", votes)
	}
}

func TestMunicipalYears(t *testing.T) {
	for y, want := range map[int]bool{2024: true, 2020: true, 2016: true, 2022: false, 2012: false, 2026: false} {
		if MunicipalYear(y) != want {
			t.Fatalf("MunicipalYear(%d) = %v", y, !want)
		}
	}
	if TitleKey("") != "" || TitleKey("1") == TitleKey("2") {
		t.Fatal("title keys")
	}
}
