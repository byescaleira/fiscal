package main

import (
	"reflect"
	"testing"
	"time"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

var now = time.Date(2026, 10, 25, 18, 0, 0, 0, time.UTC)

func TestDefaults(t *testing.T) {
	c, err := loadConfig(env(nil), now)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(c.ingest.Years, []int{2023, 2024, 2025, 2026}) || !reflect.DeepEqual(c.ingest.TSEYears, []int{2022, 2026}) || !reflect.DeepEqual(c.ingest.TSECandidateYears, []int{2018}) {
		t.Fatalf("years = %v %v %v", c.ingest.Years, c.ingest.TSEYears, c.ingest.TSECandidateYears)
	}
	if c.ingest.PublicDir != "./public" || c.ingest.DataDir != "./data" || c.live != 10*time.Minute || c.fullAt != [2]int{6, 30} || c.ingest.UFs != nil || c.ingest.Sources != nil || c.ingest.Workers != 4 {
		t.Fatalf("config = %+v", c)
	}
}

func TestLimitedRun(t *testing.T) {
	c, err := loadConfig(env(map[string]string{"INGEST_YEARS": "2026", "INGEST_UFS": "AC, sp", "INGEST_SOURCES": "camara,tse", "INGEST_FULL_AT": "05:15", "INGEST_LIVE_INTERVAL": "5m"}), now)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(c.ingest.Years, []int{2026}) || !reflect.DeepEqual(c.ingest.UFs, []string{"ac", "sp"}) || !c.ingest.Sources["camara"] || c.ingest.Sources["senado"] || c.fullAt != [2]int{5, 15} || c.live != 5*time.Minute {
		t.Fatalf("config = %+v", c)
	}
}

func TestComprovaSource(t *testing.T) {
	c, err := loadConfig(env(map[string]string{"INGEST_SOURCES": "comprova", "COMPROVA_SINCE": "2024-01-01"}), now)
	if err != nil {
		t.Fatal(err)
	}
	if !c.ingest.Sources["comprova"] || c.ingest.ChecksSince != "2024-01-01" {
		t.Fatalf("config = %+v", c.ingest)
	}
	if d, _ := loadConfig(env(nil), now); d.ingest.ChecksSince != "" {
		t.Fatalf("default since = %q", d.ingest.ChecksSince)
	}
}

func TestInvalidConfigFailsClosed(t *testing.T) {
	for name, e := range map[string]map[string]string{
		"future year":   {"INGEST_YEARS": "2030"},
		"bad year":      {"INGEST_YEARS": "abc"},
		"bad range":     {"INGEST_YEARS": "2026-2024"},
		"tse year":      {"TSE_YEARS": "2024"},
		"city year":     {"TSE_CITY_YEAR": "2022"},
		"future city":   {"TSE_CITY_YEAR": "2028"},
		"uf":            {"INGEST_UFS": "xx"},
		"source":        {"INGEST_SOURCES": "stf"},
		"full at":       {"INGEST_FULL_AT": "25:00"},
		"live too fast": {"INGEST_LIVE_INTERVAL": "30s"},
		"gap":           {"INGEST_REQUEST_GAP": "1ms"},
		"workers":       {"INGEST_WORKERS": "100"},
		"checks since":  {"COMPROVA_SINCE": "2017-12-31"},
		"checks future": {"COMPROVA_SINCE": "2026-12-01"},
		"checks format": {"COMPROVA_SINCE": "01/01/2022"},
	} {
		if _, err := loadConfig(env(e), now); err == nil {
			t.Errorf("%s accepted", name)
		}
	}
}

func TestParseYearsRanges(t *testing.T) {
	got, err := parseYears("2023-2025, 2025,2026", nil)
	if err != nil || !reflect.DeepEqual(got, []int{2023, 2024, 2025, 2026}) {
		t.Fatalf("years = %v %v", got, err)
	}
}

func TestNextFull(t *testing.T) {
	loc, _ := time.LoadLocation("America/Sao_Paulo")
	before := time.Date(2026, 10, 25, 5, 0, 0, 0, loc)
	if got := nextFull(before, [2]int{6, 30}, loc); !got.Equal(time.Date(2026, 10, 25, 6, 30, 0, 0, loc)) {
		t.Fatalf("same day = %v", got)
	}
	after := time.Date(2026, 10, 25, 7, 0, 0, 0, loc)
	if got := nextFull(after, [2]int{6, 30}, loc); !got.Equal(time.Date(2026, 10, 26, 6, 30, 0, 0, loc)) {
		t.Fatalf("next day = %v", got)
	}
}

func TestCheckReadsTheHeartbeat(t *testing.T) {
	dir := t.TempDir()
	if check(dir, now, time.Minute) != 1 {
		t.Fatal("no status must be unhealthy")
	}
	writeStatus(dir, status{Heartbeat: now.Add(-30 * time.Second).Format(time.RFC3339)})
	if check(dir, now, time.Minute) != 0 {
		t.Fatal("recent heartbeat must be healthy")
	}
	if check(dir, now.Add(10*time.Minute), time.Minute) != 1 {
		t.Fatal("stale heartbeat must be unhealthy")
	}
}
