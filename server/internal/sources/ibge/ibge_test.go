package ibge

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseMunicipalities(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("testdata", "municipios.json"))
	if err != nil {
		t.Fatal(err)
	}
	m, err := ParseMunicipalities(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(m) != 3 || m[0].Code != "1100015" || m[0].Name != "Alta Floresta D'Oeste" || m[0].UF != "RO" {
		t.Fatalf("municipalities = %+v", m)
	}
	if _, err := ParseMunicipalities([]byte(`[{"municipio-id":12,"municipio-nome":"X","UF-sigla":"RO"}]`)); err == nil {
		t.Fatal("short code accepted")
	}
	if _, err := ParseMunicipalities([]byte(`[{"municipio-id":1100015,"municipio-nome":"X","UF-sigla":"XX"}]`)); err == nil {
		t.Fatal("unknown UF accepted")
	}
}

func TestStates(t *testing.T) {
	if len(States) != 27 || StateName("SP") != "São Paulo" || StateName("DF") != "Distrito Federal" || StateName("ZZ") != "" {
		t.Fatal("states")
	}
}
