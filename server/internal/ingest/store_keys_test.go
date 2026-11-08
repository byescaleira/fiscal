package ingest

import (
	"context"
	"testing"

	"liveresults/internal/publicdata"
)

func TestAPersonWithTwoOfficesInACityKeepsBothInTheStore(t *testing.T) {
	db := expenseStore(t)
	ctx := context.Background()
	run, err := db.BeginRun(ctx, "test")
	if err != nil {
		t.Fatal(err)
	}
	person := func(office string) *publicdata.Person {
		return &publicdata.Person{Name: "Pessoa A", Keys: []string{"tse:1"}, Roles: []publicdata.Role{{Office: office, UF: "ce"}}}
	}
	city := publicdata.City{Code: "2303931", Name: "Cidade", UF: "ce", Officials: []*publicdata.Person{person(publicdata.OfficeMayor), person(publicdata.OfficeCityCouncilor)}}
	counts, err := db.PutCities(ctx, run.ID, publicdata.CitySource, []publicdata.City{city})
	if err != nil || counts.Repeated != 0 {
		t.Fatalf("put: %v %+v", err, counts)
	}
	stored, err := db.Cities(ctx, publicdata.CitySource)
	if err != nil || len(stored) != 1 || len(stored[0].Officials) != 2 {
		t.Fatalf("restored: %v %+v", err, stored)
	}
}

func TestReadingWithTheNewExpenseIDsClosesTheOldKeys(t *testing.T) {
	db := expenseStore(t)
	people, want := deputiesFromCEAP(t, ceapRows)
	old := []*publicdata.Person{}
	for _, p := range people {
		cp := *p
		act := *p.Activity[2025]
		act.Expenses = nil
		n := 0
		for _, e := range p.Activity[2025].Expenses {
			n++
			switch {
			case e.ID == "camara-100-2" || e.ID == "camara-100-3":
				e.ID = "camara-100"
			case len(e.ID) > 0 && e.ID[len(e.ID)-4:len(e.ID)-2] == "-0":
				e.ID = "camara-old-" + string(rune('a'+n))
			}
			act.Expenses = append(act.Expenses, e)
		}
		cp.Activity = map[int]*publicdata.YearActivity{2025: &act}
		old = append(old, &cp)
	}
	storeRead(t, db, old)
	counts, got := storeRead(t, db, people)
	if counts.Closed == 0 || counts.Repeated != 0 {
		t.Fatalf("migration counts: %+v", counts)
	}
	for key, sum := range want {
		if got[key] != sum {
			t.Errorf("%s: store = %v, source = %v", key, got[key], sum)
		}
	}
}
