package ingest

import (
	"strings"
	"testing"
	"time"
)

var brt = func() *time.Location {
	loc, err := time.LoadLocation("America/Sao_Paulo")
	if err != nil {
		return time.FixedZone("BRT", -3*3600)
	}
	return loc
}()

func at(day, clock string) time.Time {
	t, err := time.ParseInLocation("2006-01-02 15:04", day+" "+clock, brt)
	if err != nil {
		panic(err)
	}
	return t
}

func job(t *testing.T, name string) Job {
	t.Helper()
	j, ok := JobByName(name)
	if !ok {
		t.Fatalf("no job %s", name)
	}
	return j
}

func TestHotRunsEveryFiveMinutesInSessionHoursAndHourlyOutside(t *testing.T) {
	hot := job(t, "hot")
	monday := at("2026-10-26", "14:00")
	cases := []struct {
		now  time.Time
		last time.Time
		due  bool
	}{
		{monday, time.Time{}, true},
		{monday, monday.Add(-5 * time.Minute), true},
		{monday, monday.Add(-4*time.Minute - 20*time.Second), true},
		{monday, monday.Add(-2 * time.Minute), false},
		{at("2026-10-26", "23:55"), at("2026-10-26", "23:50"), true},
		{at("2026-10-27", "03:00"), at("2026-10-27", "02:40"), false},
		{at("2026-10-27", "03:00"), at("2026-10-27", "02:00"), true},
		{at("2026-10-31", "15:00"), at("2026-10-31", "14:50"), false},
		{at("2026-10-31", "15:00"), at("2026-10-31", "14:00"), true},
	}
	for i, c := range cases {
		if due, why := hot.Due(c.now, brt, JobState{LastAttempt: c.last}); due != c.due {
			t.Fatalf("case %d: due=%v (%s), want %v", i, due, why, c.due)
		}
	}
}

func TestDailyWeeklyAndMonthlyAnchorsRunOncePerPeriodAndCatchUp(t *testing.T) {
	camara := job(t, "camara")
	if due, _ := camara.Due(at("2026-10-26", "04:59"), brt, JobState{LastOK: at("2026-10-25", "05:03")}); due {
		t.Fatal("camara is not due before 05:00")
	}
	if due, _ := camara.Due(at("2026-10-26", "05:00"), brt, JobState{LastOK: at("2026-10-25", "05:03")}); !due {
		t.Fatal("camara is due at 05:00")
	}
	if due, _ := camara.Due(at("2026-10-26", "11:00"), brt, JobState{LastOK: at("2026-10-25", "05:03")}); !due {
		t.Fatal("a missed daily run catches up on the next tick")
	}
	if due, _ := camara.Due(at("2026-10-26", "05:05"), brt, JobState{LastOK: at("2026-10-26", "05:02")}); due {
		t.Fatal("camara runs once a day")
	}
	failed := JobState{LastOK: at("2026-10-25", "05:03"), LastAttempt: at("2026-10-26", "05:00")}
	if due, _ := camara.Due(at("2026-10-26", "05:10"), brt, failed); due {
		t.Fatal("a failed run waits before retrying")
	}
	if due, _ := camara.Due(at("2026-10-26", "05:31"), brt, failed); !due {
		t.Fatal("a failed run retries after 30 minutes")
	}
	tse := job(t, "tse")
	if due, _ := tse.Due(at("2026-10-28", "12:00"), brt, JobState{LastOK: at("2026-10-25", "00:21")}); due {
		t.Fatal("tse runs once a week, on Sundays")
	}
	if due, _ := tse.Due(at("2026-11-01", "00:25"), brt, JobState{LastOK: at("2026-10-25", "00:21")}); !due {
		t.Fatal("tse is due on the next Sunday")
	}
	hist := job(t, "historia")
	if due, _ := hist.Due(at("2026-10-26", "12:00"), brt, JobState{LastOK: at("2026-10-01", "03:51")}); due {
		t.Fatal("historia runs once a month")
	}
	if due, _ := hist.Due(at("2026-11-01", "04:00"), brt, JobState{LastOK: at("2026-10-01", "03:51")}); !due {
		t.Fatal("historia is due on the first day of the month")
	}
}

func TestDerivedRunsOnlyWithPendingVotesAndAtMostEveryTwentyMinutes(t *testing.T) {
	d := job(t, "destaques")
	now := at("2026-10-26", "15:00")
	if due, _ := d.Due(now, brt, JobState{}); due {
		t.Fatal("no pending vote, no derived run")
	}
	if due, _ := d.Due(now, brt, JobState{Pending: true, LastAttempt: now.Add(-10 * time.Minute)}); due {
		t.Fatal("derived runs at most every 20 minutes")
	}
	if due, _ := d.Due(now, brt, JobState{Pending: true, LastAttempt: now.Add(-20 * time.Minute)}); !due {
		t.Fatal("pending votes after 20 minutes trigger the derived run")
	}
}

func TestCatalogIsDocumented(t *testing.T) {
	seen := map[string]bool{}
	for _, j := range Catalog {
		if seen[j.Name] {
			t.Fatalf("duplicate job %s", j.Name)
		}
		seen[j.Name] = true
		if j.Reason == "" || j.Theme == "" || j.Cadence() == "" {
			t.Fatalf("job %s needs a theme, a cadence and a reason", j.Name)
		}
		if j.Kind == JobSources && len(j.Sources) == 0 {
			t.Fatalf("job %s refreshes no source", j.Name)
		}
		if j.Probe != ProbeNone && j.Probe != ProbeSelf && j.MaxAge == 0 {
			t.Fatalf("probed job %s needs a max age so a wrong validator cannot starve it", j.Name)
		}
	}
	if !IsElectionDay(at("2026-10-25", "10:00")) || IsElectionDay(at("2026-10-26", "10:00")) {
		t.Fatal("election days")
	}
	if c := job(t, "hot").Cadence(); !strings.Contains(c, "seg–sex") || !strings.Contains(c, "1h0m0s") {
		t.Fatalf("hot cadence = %s", c)
	}
}
