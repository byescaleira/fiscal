package assembleias

import (
	"context"
	"encoding/json"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fileGetter struct {
	t     *testing.T
	calls []string
}

func (f *fileGetter) JSON(_ context.Context, raw string, v any) error {
	f.calls = append(f.calls, raw)
	u, _ := url.Parse(raw)
	name := map[string]string{
		"/api/parlamentares/parlamentar/":      "parlamentares.json",
		"/api/base/autor/":                     "autores.json",
		"/api/materia/tipomaterialegislativa/": "tipos.json",
		"/api/materia/materialegislativa/":     "materias.json",
	}[u.Path]
	if name == "" {
		f.t.Fatalf("unexpected path %s", u.Path)
	}
	data, err := os.ReadFile(filepath.Join("testdata", name))
	if err != nil {
		f.t.Fatal(err)
	}
	return json.Unmarshal(data, v)
}

func TestLoadLinksMattersToActiveMembers(t *testing.T) {
	h, ok := HouseFor("AC")
	if !ok {
		t.Fatal("AC house")
	}
	g := &fileGetter{t: t}
	d, err := Load(context.Background(), g, h, 2026)
	if err != nil {
		t.Fatal(err)
	}
	if len(d.Members) != 1 || d.Members[0].ID != 248 || d.Members[0].Name != "ADAILTON CRUZ" || !strings.HasPrefix(d.Members[0].Photo, "https://") || d.Members[0].Email == "" {
		t.Fatalf("members = %+v", d.Members)
	}
	if d.Authors[146] != 248 || len(d.Authors) != 1 {
		t.Fatalf("authors = %v", d.Authors)
	}
	if len(d.Matters) != 3 {
		t.Fatalf("matters = %d", len(d.Matters))
	}
	pl := d.Matters[2]
	if pl.Kind != "PL" || pl.KindName != "Projeto de Lei" || pl.Number != 4 || pl.Year != 2026 || len(pl.AuthorIDs) != 1 || pl.AuthorIDs[0] != 248 || pl.URL != "https://sapl.al.ac.leg.br/materia/18735" || !CanBecomeLaw(pl.Kind) {
		t.Fatalf("pl = %+v", pl)
	}
	if len(d.Matters[0].AuthorIDs) != 0 || d.Matters[0].Kind != "IND" || CanBecomeLaw("IND") {
		t.Fatalf("indication = %+v", d.Matters[0])
	}
	for _, c := range g.calls {
		if !strings.HasPrefix(c, "https://sapl.al.ac.leg.br/api/") || !strings.Contains(c, "page_size=100") {
			t.Fatalf("call = %s", c)
		}
	}
	if !strings.Contains(g.calls[0], "ativo=True") || !strings.Contains(g.calls[3], "ano=2026") {
		t.Fatalf("filters = %v", g.calls)
	}
}

func TestHouses(t *testing.T) {
	if len(Houses) != 5 {
		t.Fatal("houses")
	}
	if _, ok := HouseFor("sp"); ok {
		t.Fatal("SP has no SAPL in the list")
	}
}
