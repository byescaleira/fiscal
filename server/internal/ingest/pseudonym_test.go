package ingest

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"liveresults/internal/publicdata"
)

func TestMain(m *testing.M) {
	if err := publicdata.SetPseudonymKey(bytes.Repeat([]byte{0x5a}, publicdata.PseudonymKeyBytes)); err != nil {
		panic(err)
	}
	os.Exit(m.Run())
}

func legacyKey(cpf string) string {
	sum := sha256.Sum256([]byte("fiscal-person:" + cpf))
	return "cpf:" + hex.EncodeToString(sum[:10])
}

func TestSlugFileMovesToTheKeyedPseudonymBeforeLinking(t *testing.T) {
	in := testIngest(t, Config{}, nil, time.Date(2026, 10, 26, 12, 0, 0, 0, time.UTC))
	if err := os.MkdirAll(in.cfg.DataDir, 0o700); err != nil {
		t.Fatal(err)
	}
	old := legacyKey("12345678901")
	stranger := legacyKey("99999999999")
	data, _ := json.Marshal(map[string]any{"version": 1, "slugs": map[string]string{old: "acacio-favacho-ac", stranger: "outra-pessoa", "camara:204379": "acacio-favacho-ap"}})
	if err := os.WriteFile(in.slugsPath(), data, 0o600); err != nil {
		t.Fatal(err)
	}
	m := publicdata.NewPseudonyms()
	if err := in.migrateSlugs(m); err != nil {
		t.Fatal(err)
	}
	people := []*publicdata.Person{{CPF: "12345678901"}}
	cands := []publicdata.Candidacy{{CPF: old}, {CPF: "12345678901"}}
	pseudonymizePeople(m, people)
	pseudonymizeCandidacies(m, cands)
	current := publicdata.CPFKey("12345678901")
	if people[0].CPF != current || cands[0].CPF != current || cands[1].CPF != current {
		t.Fatalf("restored and fresh CPFs must meet on one pseudonym: %s %s %s", people[0].CPF, cands[0].CPF, cands[1].CPF)
	}
	if err := in.migrateSlugs(m); err != nil {
		t.Fatal(err)
	}
	var f struct {
		Slugs map[string]string `json:"slugs"`
	}
	readJSON(t, in.slugsPath(), &f)
	if f.Slugs[current] != "acacio-favacho-ac" || f.Slugs["camara:204379"] != "acacio-favacho-ap" || f.Slugs[stranger] != "outra-pessoa" {
		t.Fatalf("slugs = %v", f.Slugs)
	}
	if _, ok := f.Slugs[old]; ok {
		t.Fatal("the unkeyed pseudonym must leave the slug file once its CPF is seen")
	}
	if info, err := os.Stat(filepath.Join(in.cfg.DataDir, "slugs.json")); err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("slug file mode = %v %v", info, err)
	}
}
