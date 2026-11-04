package ingest

import (
	"context"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"liveresults/internal/datastore"
	"liveresults/internal/publicdata"
	"liveresults/internal/sources/camara"
)

const ceapHeader = "ideCadastro;cpf;numMes;numAno;txtDescricao;txtFornecedor;txtCNPJCPF;txtNumero;vlrLiquido;ideDocumento;urlDocumento\n"

const ceapRows = ceapHeader +
	"1;;1;2025;PASSAGEM;Companhia A;11222333000181;A1;98,77;100;\n" +
	"1;;2;2025;PASSAGEM;Companhia A;11222333000181;A1;-2113,91;100;\n" +
	"1;;2;2025;PASSAGEM;Companhia A;11222333000181;A2;1992,63;100;\n" +
	"1;;3;2025;TELEFONIA;Operadora;11222333000181;;104,67;0;\n" +
	"1;;4;2025;TELEFONIA;Operadora;11222333000181;;104,67;0;\n" +
	"1;;5;2025;ESCRITORIO;Loja;11222333000181;B1;50,00;200;\n" +
	"2;;1;2025;PASSAGEM;Companhia A;11222333000181;C1;10,00;100;\n" +
	"2;;2;2025;TELEFONIA;Operadora;11222333000181;;20,00;;\n"

func deputiesFromCEAP(t *testing.T, csv string) ([]*publicdata.Person, map[string][2]int64) {
	t.Helper()
	ids := expenseIDs{}
	byDeputy := map[int64]*publicdata.YearActivity{}
	want := map[string][2]int64{}
	err := camara.ReadExpenses(strings.NewReader(csv), func(e camara.Expense) {
		act := byDeputy[e.DeputyID]
		if act == nil {
			act = &publicdata.YearActivity{Year: e.Year}
			byDeputy[e.DeputyID] = act
		}
		act.Expenses = append(act.Expenses, camaraExpense(ids, e))
		key := "camara:" + strconv.FormatInt(e.DeputyID, 10)
		got := want[key]
		want[key] = [2]int64{got[0] + 1, got[1] + e.Cents}
	})
	if err != nil {
		t.Fatal(err)
	}
	var people []*publicdata.Person
	for id, name := range map[int64]string{1: "Pessoa A", 2: "Pessoa B"} {
		people = append(people, &publicdata.Person{Name: name, HouseID: id, Keys: []string{"camara:" + strconv.FormatInt(id, 10)}, Activity: map[int]*publicdata.YearActivity{2025: byDeputy[id]}})
	}
	return people, want
}

func storeRead(t *testing.T, db *datastore.Store, people []*publicdata.Person) (datastore.Counts, map[string][2]int64) {
	t.Helper()
	ctx := context.Background()
	run, err := db.BeginRun(ctx, "test")
	if err != nil {
		t.Fatal(err)
	}
	counts, err := db.PutSourcePeople(ctx, run.ID, publicdata.HouseCamara, people, true)
	if err != nil {
		t.Fatal(err)
	}
	restored, err := db.SourcePeople(ctx, publicdata.HouseCamara)
	if err != nil {
		t.Fatal(err)
	}
	got := map[string][2]int64{}
	for _, p := range restored {
		sum := [2]int64{}
		for _, e := range p.Activity[2025].Expenses {
			sum[0]++
			sum[1] += e.Cents
		}
		got[datastore.PersonKey(p)] = sum
	}
	return counts, got
}

func expenseStore(t *testing.T) *datastore.Store {
	t.Helper()
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	db, err := datastore.Open(filepath.Join(t.TempDir(), "fiscal.db"), func() time.Time { return now })
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func TestEveryExpenseRowOfTheSourceSurvivesTheStore(t *testing.T) {
	db := expenseStore(t)
	people, want := deputiesFromCEAP(t, ceapRows)
	counts, got := storeRead(t, db, people)
	if counts.Repeated != 0 {
		t.Fatalf("repeated = %d, every row must have its own key", counts.Repeated)
	}
	if want["camara:1"] != [2]int64{6, 23683} || want["camara:2"] != [2]int64{2, 3000} {
		t.Fatalf("source = %v", want)
	}
	for key, sum := range want {
		if got[key] != sum {
			t.Errorf("%s: store = %v, source = %v", key, got[key], sum)
		}
	}
}

func TestReadingTheSameExpensesAgainChangesNothingInTheStore(t *testing.T) {
	db := expenseStore(t)
	people, _ := deputiesFromCEAP(t, ceapRows)
	storeRead(t, db, people)
	again, _ := deputiesFromCEAP(t, ceapRows)
	counts, _ := storeRead(t, db, again)
	if counts.Changed != 0 || counts.Inserted != 0 || counts.Closed != 0 {
		t.Fatalf("second read: %+v", counts)
	}
}

func TestANewRowOfAnotherDeputyDoesNotRenameTheRowsWithoutADocument(t *testing.T) {
	ids := expenseIDs{}
	if got := ids.next(1, "0"); got != "camara-1-0-1" {
		t.Fatalf("first without document = %s", got)
	}
	ids.next(2, "0")
	ids.next(2, "")
	if got := ids.next(1, ""); got != "camara-1-0-2" {
		t.Fatalf("second without document = %s", got)
	}
}

func TestARepeatedDocumentKeepsItsIDOnTheFirstRowOnly(t *testing.T) {
	ids := expenseIDs{}
	if got := ids.next(1, "100"); got != "camara-100" {
		t.Fatalf("first = %s", got)
	}
	if got := ids.next(1, "100"); got != "camara-100-2" {
		t.Fatalf("second = %s", got)
	}
	if got := ids.next(2, "100"); got != "camara-100" {
		t.Fatalf("other deputy = %s", got)
	}
}

func TestTheStoreCountsARepeatedKeyWithOtherContentOnly(t *testing.T) {
	db := expenseStore(t)
	expense := func(cents int64) publicdata.Expense {
		return publicdata.Expense{ID: "camara-100", Year: 2025, Month: 1, Category: "PASSAGEM", Cents: cents}
	}
	person := func(items ...publicdata.Expense) []*publicdata.Person {
		return []*publicdata.Person{{Name: "Pessoa A", HouseID: 1, Keys: []string{"camara:1"}, Activity: map[int]*publicdata.YearActivity{2025: {Year: 2025, Expenses: items}}}}
	}
	counts, got := storeRead(t, db, person(expense(100), expense(100)))
	if counts.Repeated != 0 || got["camara:1"] != [2]int64{1, 100} {
		t.Fatalf("identical rows: %+v %v", counts, got)
	}
	counts, got = storeRead(t, db, person(expense(100), expense(-50)))
	if counts.Repeated != 1 || got["camara:1"] != [2]int64{1, -50} {
		t.Fatalf("other content: %+v %v", counts, got)
	}
}
