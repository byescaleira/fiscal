package publicdata

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

var testPseudonymKey = bytes.Repeat([]byte{0x5a}, PseudonymKeyBytes)

func TestMain(m *testing.M) {
	if err := SetPseudonymKey(testPseudonymKey); err != nil {
		panic(err)
	}
	os.Exit(m.Run())
}

func withPseudonymKey(t *testing.T, key []byte) {
	t.Helper()
	if err := SetPseudonymKey(key); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { SetPseudonymKey(testPseudonymKey) })
}

func TestCPFKeyIsAKeyedHMAC(t *testing.T) {
	const cpf = "74287028287"
	k := CPFKey(cpf)
	if !strings.HasPrefix(k, "cpf:") || len(k) != len("cpf:")+32 || IsLegacyCPFKey(k) {
		t.Fatalf("key = %q", k)
	}
	if k == legacyCPFKey(cpf) || !IsLegacyCPFKey(legacyCPFKey(cpf)) {
		t.Fatal("the keyed pseudonym must differ from the unkeyed SHA-256")
	}
	if CPFKey(cpf) != k || CPFKey(k) != k {
		t.Fatal("the pseudonym must be stable and idempotent")
	}
	withPseudonymKey(t, bytes.Repeat([]byte{0x01}, PseudonymKeyBytes))
	if CPFKey(cpf) == k {
		t.Fatal("another key must give another pseudonym")
	}
}

func TestCPFKeyFailsClosedWithoutTheKey(t *testing.T) {
	saved := pseudonymKey.Load()
	pseudonymKey.Store(nil)
	defer pseudonymKey.Store(saved)
	defer func() {
		if r := recover(); r != ErrNoPseudonymKey {
			t.Fatalf("recover = %v", r)
		}
	}()
	CPFKey("74287028287")
	t.Fatal("CPFKey without a key must not return")
}

func TestReadPseudonymKey(t *testing.T) {
	dir := t.TempDir()
	good := filepath.Join(dir, "good")
	os.WriteFile(good, []byte(strings.Repeat("ab", PseudonymKeyBytes)+"\n"), 0o600)
	if key, err := ReadPseudonymKey(good); err != nil || len(key) != PseudonymKeyBytes {
		t.Fatalf("good = %d %v", len(key), err)
	}
	short := filepath.Join(dir, "short")
	os.WriteFile(short, []byte("abcd"), 0o600)
	bad := filepath.Join(dir, "bad")
	os.WriteFile(bad, []byte(strings.Repeat("zz", PseudonymKeyBytes)), 0o600)
	for _, p := range []string{short, bad, filepath.Join(dir, "missing")} {
		if _, err := ReadPseudonymKey(p); err == nil || !strings.Contains(err.Error(), p) || !strings.Contains(err.Error(), "openssl rand -hex 32") {
			t.Errorf("%s: err = %v", p, err)
		}
	}
	if _, err := ReadPseudonymKey(""); !errors.Is(err, ErrNoPseudonymKey) {
		t.Errorf("empty path = %v", err)
	}
	if SetPseudonymKey([]byte("short")) == nil {
		t.Error("a short key must be refused")
	}
}

func slugList(m map[*Person]string, people []*Person) []string {
	out := make([]string, len(people))
	for i, p := range people {
		out[i] = m[p]
	}
	return out
}

func TestPublicSlugsSurviveTheKeyedPseudonym(t *testing.T) {
	path := filepath.Join(t.TempDir(), "slugs.json")
	before, err := LoadSlugs(path)
	if err != nil {
		t.Fatal(err)
	}
	legacy := []*Person{
		{Keys: []string{"camara:204379"}, Name: "Acácio Favacho", Roles: []Role{{Office: OfficeFederalDeputy, UF: "ap", Status: StatusInOffice}}},
		{Keys: []string{legacyCPFKey("1")}, Name: "Acácio Favacho", Roles: []Role{{Office: OfficeStateDeputy, UF: "ac", Status: StatusElected}}},
		{Keys: []string{legacyCPFKey("2")}, Name: "Mailza Assis", Roles: []Role{{Office: OfficeGovernor, UF: "ac", Status: StatusInOffice}}},
	}
	want := slugList(before.Assign(legacy), legacy)
	if err := before.Save(); err != nil {
		t.Fatal(err)
	}
	m := NewPseudonyms()
	keyed := []*Person{
		{Keys: []string{"camara:204379"}, Name: "Acácio Favacho", Roles: []Role{{Office: OfficeFederalDeputy, UF: "ap", Status: StatusInOffice}}},
		{Keys: []string{m.CPF("1")}, Name: "Acácio Favacho", Roles: []Role{{Office: OfficeStateDeputy, UF: "ac", Status: StatusElected}}},
		{Keys: []string{m.CPF("2")}, Name: "Mailza Assis", Roles: []Role{{Office: OfficeGovernor, UF: "ac", Status: StatusInOffice}}},
	}
	unmigrated, _ := LoadSlugs(path)
	if got := slugList(unmigrated.Assign(keyed), keyed); got[1] == want[1] {
		t.Fatalf("the test needs a slug that depends on the key: %v", got)
	}
	after, _ := LoadSlugs(path)
	if moved := after.Migrate(m); moved != 2 {
		t.Fatalf("moved = %d", moved)
	}
	if got := slugList(after.Assign(keyed), keyed); strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("slugs changed: %v, want %v", got, want)
	}
	for k := range after.byKey {
		if IsLegacyCPFKey(k) {
			t.Fatalf("legacy pseudonym %s left in the slug file", k)
		}
	}
}

func TestPseudonymsTranslateRestoredLegacyData(t *testing.T) {
	m := NewPseudonyms()
	current := m.CPF("74287028287")
	old := legacyCPFKey("74287028287")
	stranger := legacyCPFKey("99999999999")
	p := &Person{CPF: old, Keys: []string{"camara:1", old, current}, Candidacies: []Candidacy{{CPF: old}, {CPF: stranger}}}
	m.Person(p)
	if p.CPF != current || p.Candidacies[0].CPF != current || p.Candidacies[1].CPF != stranger {
		t.Fatalf("person = %+v", p)
	}
	if strings.Join(p.Keys, ",") != "camara:1,"+current {
		t.Fatalf("keys = %v", p.Keys)
	}
	if m.CPF("") != "" || m.CPF(stranger) != stranger {
		t.Fatal("unknown legacy pseudonyms stay as they are")
	}
}

func TestPseudonymsStayOutOfThePublicFiles(t *testing.T) {
	ds := sampleDataset()
	m := NewPseudonyms()
	for _, p := range ds.People {
		m.Person(p)
	}
	out := Build(ds, &Slugs{byKey: map[string]string{}})
	for _, f := range out.Files {
		data, err := json.Marshal(f.Value)
		if err != nil {
			t.Fatal(err)
		}
		if bytes.Contains(data, []byte("cpf:")) || bytes.Contains(data, []byte("74287028287")) {
			t.Fatalf("%s publishes a CPF or its pseudonym: %s", f.Path, data)
		}
	}
	for p, slug := range out.Slugs {
		if strings.Contains(slug, "cpf") || slug == "" {
			t.Fatalf("slug of %s = %q", p.Name, slug)
		}
	}
}
