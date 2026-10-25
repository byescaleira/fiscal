package assembleias

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
)

type House struct {
	UF   string
	Name string
	Base string
}

var Houses = []House{
	{UF: "ac", Name: "Assembleia Legislativa do Acre", Base: "https://sapl.al.ac.leg.br"},
	{UF: "am", Name: "Assembleia Legislativa do Amazonas", Base: "https://sapl.al.am.leg.br"},
	{UF: "pb", Name: "Assembleia Legislativa da Paraíba", Base: "https://sapl.al.pb.leg.br"},
	{UF: "pi", Name: "Assembleia Legislativa do Piauí", Base: "https://sapl.al.pi.leg.br"},
	{UF: "ro", Name: "Assembleia Legislativa de Rondônia", Base: "https://sapl.al.ro.leg.br"},
}

func HouseFor(uf string) (House, bool) {
	for _, h := range Houses {
		if h.UF == strings.ToLower(uf) {
			return h, true
		}
	}
	return House{}, false
}

type Getter interface {
	JSON(ctx context.Context, rawURL string, v any) error
}

type Member struct {
	ID       int64
	Name     string
	FullName string
	Email    string
	Phone    string
	Photo    string
	Active   bool
}

type Matter struct {
	ID        int64
	KindID    int64
	Kind      string
	KindName  string
	Number    int
	Year      int
	Ementa    string
	Presented string
	AuthorIDs []int64
	URL       string
}

type Data struct {
	House   House
	Members []Member
	Authors map[int64]int64
	Matters []Matter
}

const pageSize = 100
const maxPages = 100

type page[T any] struct {
	Pagination struct {
		NextPage *int `json:"next_page"`
	} `json:"pagination"`
	Results []T `json:"results"`
}

func list[T any](ctx context.Context, g Getter, base, path string, q url.Values) ([]T, error) {
	var out []T
	for p := 1; p <= maxPages; p++ {
		q.Set("page", strconv.Itoa(p))
		q.Set("page_size", strconv.Itoa(pageSize))
		var body page[T]
		if err := g.JSON(ctx, base+path+"?"+q.Encode(), &body); err != nil {
			return nil, err
		}
		out = append(out, body.Results...)
		if body.Pagination.NextPage == nil || len(body.Results) == 0 {
			return out, nil
		}
	}
	return nil, fmt.Errorf("sapl: %s has more than %d pages", path, maxPages)
}

type memberJSON struct {
	ID              int64  `json:"id"`
	NomeParlamentar string `json:"nome_parlamentar"`
	NomeCompleto    string `json:"nome_completo"`
	Email           string `json:"email"`
	Telefone        string `json:"telefone"`
	Fotografia      string `json:"fotografia"`
	Ativo           bool   `json:"ativo"`
}

func (m memberJSON) member() Member {
	photo := strings.Replace(m.Fotografia, "http://", "https://", 1)
	return Member{ID: m.ID, Name: strings.TrimSpace(m.NomeParlamentar), FullName: strings.TrimSpace(m.NomeCompleto), Email: strings.TrimSpace(m.Email), Phone: strings.TrimSpace(m.Telefone), Photo: photo, Active: m.Ativo}
}

type authorJSON struct {
	ID       int64  `json:"id"`
	Nome     string `json:"nome"`
	ObjectID *int64 `json:"object_id"`
}

type kindJSON struct {
	ID        int64  `json:"id"`
	Sigla     string `json:"sigla"`
	Descricao string `json:"descricao"`
}

type matterJSON struct {
	ID               int64   `json:"id"`
	Numero           int     `json:"numero"`
	Ano              int     `json:"ano"`
	DataApresentacao string  `json:"data_apresentacao"`
	Ementa           string  `json:"ementa"`
	Tipo             int64   `json:"tipo"`
	Autores          []int64 `json:"autores"`
}

func Load(ctx context.Context, g Getter, h House, year int) (Data, error) {
	members, err := list[memberJSON](ctx, g, h.Base, "/api/parlamentares/parlamentar/", url.Values{"ativo": {"True"}})
	if err != nil {
		return Data{}, err
	}
	authors, err := list[authorJSON](ctx, g, h.Base, "/api/base/autor/", url.Values{})
	if err != nil {
		return Data{}, err
	}
	kinds, err := list[kindJSON](ctx, g, h.Base, "/api/materia/tipomaterialegislativa/", url.Values{})
	if err != nil {
		return Data{}, err
	}
	matters, err := list[matterJSON](ctx, g, h.Base, "/api/materia/materialegislativa/", url.Values{"ano": {strconv.Itoa(year)}})
	if err != nil {
		return Data{}, err
	}
	return assemble(h, members, authors, kinds, matters), nil
}

func assemble(h House, members []memberJSON, authors []authorJSON, kinds []kindJSON, matters []matterJSON) Data {
	d := Data{House: h, Authors: map[int64]int64{}}
	byID := map[int64]Member{}
	for _, m := range members {
		mm := m.member()
		if !mm.Active {
			continue
		}
		d.Members = append(d.Members, mm)
		byID[mm.ID] = mm
	}
	sort.Slice(d.Members, func(i, j int) bool { return d.Members[i].ID < d.Members[j].ID })
	for _, a := range authors {
		if a.ObjectID == nil {
			continue
		}
		m, ok := byID[*a.ObjectID]
		if !ok || !sameName(m.Name, a.Nome) {
			continue
		}
		d.Authors[a.ID] = m.ID
	}
	kindByID := map[int64]kindJSON{}
	for _, k := range kinds {
		kindByID[k.ID] = k
	}
	for _, m := range matters {
		k := kindByID[m.Tipo]
		var ids []int64
		for _, a := range m.Autores {
			if p, ok := d.Authors[a]; ok {
				ids = append(ids, p)
			}
		}
		d.Matters = append(d.Matters, Matter{
			ID: m.ID, KindID: m.Tipo, Kind: strings.TrimSpace(k.Sigla), KindName: strings.TrimSpace(k.Descricao),
			Number: m.Numero, Year: m.Ano, Ementa: strings.Join(strings.Fields(m.Ementa), " "),
			Presented: m.DataApresentacao, AuthorIDs: ids, URL: fmt.Sprintf("%s/materia/%d", h.Base, m.ID),
		})
	}
	return d
}

func sameName(a, b string) bool {
	return strings.EqualFold(strings.Join(strings.Fields(a), " "), strings.Join(strings.Fields(b), " "))
}

func parseMembers(data []byte) ([]memberJSON, error) {
	var p page[memberJSON]
	err := json.Unmarshal(data, &p)
	return p.Results, err
}

func parseAuthors(data []byte) ([]authorJSON, error) {
	var p page[authorJSON]
	err := json.Unmarshal(data, &p)
	return p.Results, err
}

func parseKinds(data []byte) ([]kindJSON, error) {
	var p page[kindJSON]
	err := json.Unmarshal(data, &p)
	return p.Results, err
}

func parseMatters(data []byte) ([]matterJSON, error) {
	var p page[matterJSON]
	err := json.Unmarshal(data, &p)
	return p.Results, err
}

func CanBecomeLaw(kind string) bool {
	switch strings.ToUpper(strings.TrimSpace(kind)) {
	case "PL", "PLC", "PLO", "PEC", "PDL", "PLE":
		return true
	}
	return false
}
