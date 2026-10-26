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
		"/api/parlamentares/legislatura/":      "legislaturas.json",
		"/api/parlamentares/mandato/":          "mandatos.json",
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
	d, err := Load(context.Background(), g, h, 2026, "2026-10-25")
	if err != nil {
		t.Fatal(err)
	}
	if len(d.Members) != 2 || !d.CurrentKnown || !d.Current[248] || d.Current[79] {
		t.Fatalf("members = %+v current = %v", d.Members, d.Current)
	}
	cur := d.CurrentMembers()
	if len(cur) != 1 || cur[0].ID != 248 || cur[0].Name != "ADAILTON CRUZ" || !strings.HasPrefix(cur[0].Photo, "https://") || cur[0].Email == "" {
		t.Fatalf("current members = %+v", cur)
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
	joined := strings.Join(g.calls, " ")
	if !strings.Contains(joined, "legislatura=17") || !strings.Contains(joined, "ano=2026") {
		t.Fatalf("filters = %v", g.calls)
	}
}

func TestCurrentMembersSkipsLeavesAndOtherLegislatures(t *testing.T) {
	legs := []legislatureJSON{{ID: 1, DataInicio: "2019-02-01", DataFim: "2023-01-31"}, {ID: 2, DataInicio: "2023-02-01", DataFim: "2027-01-31"}}
	ms := []mandateJSON{
		{Parlamentar: 10, DataInicio: "2023-02-01", DataFim: "2027-01-31"},
		{Parlamentar: 11, DataInicio: "2023-02-01", DataFim: "2025-03-01"},
		{Parlamentar: 12, DataInicio: "2025-03-02", DataFim: ""},
		{Parlamentar: 13, DataInicio: "2023-02-01", DataFim: "2027-01-31", TipoAfastamento: []byte("3")},
	}
	var asked int64
	cur, known, err := currentMembers(legs, func(id int64) ([]mandateJSON, error) { asked = id; return ms, nil }, "2026-10-25")
	if err != nil || !known || asked != 2 || !cur[10] || cur[11] || !cur[12] || cur[13] {
		t.Fatalf("current = %v known=%v asked=%d err=%v", cur, known, asked, err)
	}
	if _, known, _ := currentMembers(legs[:1], func(int64) ([]mandateJSON, error) { return ms, nil }, "2026-10-25"); known {
		t.Fatal("no current legislature means unknown membership")
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
