package tse

import (
	"archive/zip"
	"fmt"
	"io"
	"sort"
	"strconv"
	"strings"

	"liveresults/internal/sources/table"
)

const (
	Base    = "https://cdn.tse.jus.br/estatistica/sead/odsele"
	SiteURL = "https://dadosabertos.tse.jus.br"
)

const (
	President      = 1
	VicePresident  = 2
	Governor       = 3
	ViceGovernor   = 4
	Senator        = 5
	FederalDeputy  = 6
	StateDeputy    = 7
	DistrictDeputy = 8
)

func CandidatesURL(year int) string {
	return fmt.Sprintf("%s/consulta_cand/consulta_cand_%d.zip", Base, year)
}

func AssetsURL(year int) string {
	return fmt.Sprintf("%s/bem_candidato/bem_candidato_%d.zip", Base, year)
}

func VotesURL(year int) string {
	return fmt.Sprintf("%s/votacao_candidato_munzona/votacao_candidato_munzona_%d.zip", Base, year)
}

func AccountsURL(year int) string {
	return fmt.Sprintf("%s/prestacao_contas/prestacao_de_contas_eleitorais_candidatos_%d.zip", Base, year)
}

func InScope(office int) bool {
	return office >= President && office <= DistrictDeputy
}

func Elected(result string) bool {
	switch strings.ToUpper(strings.TrimSpace(result)) {
	case "ELEITO", "ELEITO POR QP", "ELEITO POR MÉDIA", "ELEITO POR MEDIA":
		return true
	}
	return false
}

type Candidate struct {
	Year       int
	Round      int
	Office     int
	OfficeName string
	UF         string
	Unit       string
	SQ         string
	Number     string
	Name       string
	BallotName string
	CPF        string
	Party      string
	BirthDate  string
	BirthUF    string
	Gender     string
	Education  string
	Occupation string
	Result     string
}

type Asset struct {
	Year  int
	SQ    string
	Kind  string
	Cents int64
}

func open(r io.Reader, cols ...string) (*table.Reader, error) {
	t, err := table.NewReader(r, table.Latin1, ';')
	if err != nil {
		return nil, err
	}
	if err := t.Require(cols...); err != nil {
		return nil, err
	}
	return t, nil
}

func isoDate(s string) string {
	parts := strings.Split(strings.TrimSpace(s), "/")
	if len(parts) != 3 || len(parts[2]) != 4 {
		return ""
	}
	return parts[2] + "-" + pad2(parts[1]) + "-" + pad2(parts[0])
}

func pad2(s string) string {
	if len(s) == 1 {
		return "0" + s
	}
	return s
}

func atoi(s string) int {
	n, _ := strconv.Atoi(strings.TrimSpace(s))
	return n
}

func cpf(s string) string {
	d := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, s)
	if len(d) != 11 || strings.Trim(d, "0") == "" {
		return ""
	}
	return d
}

func ReadCandidates(r io.Reader, fn func(Candidate)) error {
	t, err := open(r, "ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF", "SQ_CANDIDATO", "NM_CANDIDATO", "NM_URNA_CANDIDATO", "NR_CPF_CANDIDATO", "SG_PARTIDO", "DS_SIT_TOT_TURNO")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		office := atoi(row.Raw("CD_CARGO"))
		if !InScope(office) {
			return nil
		}
		fn(Candidate{
			Year:       atoi(row.Raw("ANO_ELEICAO")),
			Round:      atoi(row.Raw("NR_TURNO")),
			Office:     office,
			OfficeName: row.Str("DS_CARGO"),
			UF:         row.Str("SG_UF"),
			Unit:       row.Str("SG_UE"),
			SQ:         row.Str("SQ_CANDIDATO"),
			Number:     row.Str("NR_CANDIDATO"),
			Name:       row.Str("NM_CANDIDATO"),
			BallotName: row.Str("NM_URNA_CANDIDATO"),
			CPF:        cpf(row.Raw("NR_CPF_CANDIDATO")),
			Party:      row.Str("SG_PARTIDO"),
			BirthDate:  isoDate(row.Raw("DT_NASCIMENTO")),
			BirthUF:    row.Str("SG_UF_NASCIMENTO"),
			Gender:     row.Str("DS_GENERO"),
			Education:  row.Str("DS_GRAU_INSTRUCAO"),
			Occupation: row.Str("DS_OCUPACAO"),
			Result:     row.Str("DS_SIT_TOT_TURNO"),
		})
		return nil
	})
}

func MergeRounds(in []Candidate) []Candidate {
	best := map[string]int{}
	var out []Candidate
	for _, c := range in {
		key := strconv.Itoa(c.Year) + ":" + c.SQ
		i, ok := best[key]
		if !ok {
			best[key] = len(out)
			out = append(out, c)
			continue
		}
		cur := out[i]
		if c.Result != "" && (cur.Result == "" || c.Round > cur.Round) {
			out[i] = c
		}
	}
	return out
}

func ReadAssets(r io.Reader, keep func(string) bool, fn func(Asset)) error {
	t, err := open(r, "ANO_ELEICAO", "SQ_CANDIDATO", "DS_TIPO_BEM_CANDIDATO", "VR_BEM_CANDIDATO")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		sq := row.Str("SQ_CANDIDATO")
		if keep != nil && !keep(sq) {
			return nil
		}
		cents, ok := row.Cents("VR_BEM_CANDIDATO")
		if !ok {
			return nil
		}
		fn(Asset{Year: atoi(row.Raw("ANO_ELEICAO")), SQ: sq, Kind: row.Str("DS_TIPO_BEM_CANDIDATO"), Cents: cents})
		return nil
	})
}

func ReadVotes(r io.Reader, keep func(string) bool, fn func(sq string, round int, votes int64)) error {
	t, err := open(r, "NR_TURNO", "CD_CARGO", "SQ_CANDIDATO", "QT_VOTOS_NOMINAIS_VALIDOS")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		if !InScope(atoi(row.Raw("CD_CARGO"))) {
			return nil
		}
		sq := row.Str("SQ_CANDIDATO")
		if keep != nil && !keep(sq) {
			return nil
		}
		n, ok := row.Int("QT_VOTOS_NOMINAIS_VALIDOS")
		if !ok || n < 0 {
			return nil
		}
		fn(sq, atoi(row.Raw("NR_TURNO")), n)
		return nil
	})
}

func ReadRevenues(r io.Reader, keep func(string) bool, fn func(sq, origin string, cents int64)) error {
	t, err := open(r, "CD_CARGO", "SQ_CANDIDATO", "DS_ORIGEM_RECEITA", "VR_RECEITA")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		if !InScope(atoi(row.Raw("CD_CARGO"))) {
			return nil
		}
		sq := row.Str("SQ_CANDIDATO")
		if keep != nil && !keep(sq) {
			return nil
		}
		cents, ok := row.Cents("VR_RECEITA")
		if !ok {
			return nil
		}
		fn(sq, row.Str("DS_ORIGEM_RECEITA"), cents)
		return nil
	})
}

func ReadExpenses(r io.Reader, keep func(string) bool, fn func(sq string, cents int64)) error {
	t, err := open(r, "CD_CARGO", "SQ_CANDIDATO", "VR_DESPESA_CONTRATADA")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		if !InScope(atoi(row.Raw("CD_CARGO"))) {
			return nil
		}
		sq := row.Str("SQ_CANDIDATO")
		if keep != nil && !keep(sq) {
			return nil
		}
		cents, ok := row.Cents("VR_DESPESA_CONTRATADA")
		if !ok {
			return nil
		}
		fn(sq, cents)
		return nil
	})
}

func Entries(zr *zip.Reader, prefix string, year int, ufs []string) []*zip.File {
	want := map[string]bool{}
	for _, uf := range ufs {
		want[strings.ToUpper(uf)] = true
	}
	head := fmt.Sprintf("%s_%d_", prefix, year)
	var out []*zip.File
	for _, f := range zr.File {
		name := f.Name
		if i := strings.LastIndexByte(name, '/'); i >= 0 {
			name = name[i+1:]
		}
		if !strings.HasPrefix(name, head) || !strings.HasSuffix(strings.ToLower(name), ".csv") {
			continue
		}
		uf := strings.ToUpper(strings.TrimSuffix(strings.TrimPrefix(name, head), ".csv"))
		if uf == "BRASIL" || len(uf) != 2 {
			continue
		}
		if len(want) > 0 && !want[uf] {
			continue
		}
		out = append(out, f)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

func EachEntry(files []*zip.File, fn func(name string, r io.Reader) error) error {
	for _, f := range files {
		rc, err := f.Open()
		if err != nil {
			return fmt.Errorf("tse: open %s: %w", f.Name, err)
		}
		err = fn(f.Name, rc)
		rc.Close()
		if err != nil {
			return fmt.Errorf("tse: %s: %w", f.Name, err)
		}
	}
	return nil
}
