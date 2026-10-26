package tse

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"sort"
	"strings"

	"liveresults/internal/sources/table"
)

const (
	Mayor      = 11
	ViceMayor  = 12
	Councilor  = 13
	firstMuniY = 2016
)

func Municipal(office int) bool {
	return office >= Mayor && office <= Councilor
}

func MunicipalYear(year int) bool {
	return year >= firstMuniY && year%4 == 0
}

type Official struct {
	Election   string
	Date       string
	Round      int
	Office     int
	UF         string
	Unit       string
	UnitName   string
	SQ         string
	Name       string
	BallotName string
	Key        string
	Party      string
	BirthDate  string
	BirthUF    string
	Gender     string
	Education  string
	Result     string
}

func ReadOfficials(r io.Reader, unit func(uf, code, name string), fn func(Official)) error {
	t, err := open(r, "CD_ELEICAO", "DT_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF", "SG_UE", "NM_UE", "SQ_CANDIDATO", "NM_CANDIDATO", "NM_URNA_CANDIDATO", "SG_PARTIDO", "DS_SIT_TOT_TURNO")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		office := atoi(row.Raw("CD_CARGO"))
		if !Municipal(office) {
			return nil
		}
		if unit != nil {
			unit(row.Str("SG_UF"), row.Str("SG_UE"), row.Str("NM_UE"))
		}
		result := row.Str("DS_SIT_TOT_TURNO")
		if !Elected(result) {
			return nil
		}
		fn(Official{
			Election:   row.Str("CD_ELEICAO"),
			Date:       isoDate(row.Raw("DT_ELEICAO")),
			Round:      atoi(row.Raw("NR_TURNO")),
			Office:     office,
			UF:         row.Str("SG_UF"),
			Unit:       row.Str("SG_UE"),
			UnitName:   row.Str("NM_UE"),
			SQ:         row.Str("SQ_CANDIDATO"),
			Name:       row.Str("NM_CANDIDATO"),
			BallotName: row.Str("NM_URNA_CANDIDATO"),
			Key:        TitleKey(digits(row.Raw("NR_TITULO_ELEITORAL_CANDIDATO"))),
			Party:      row.Str("SG_PARTIDO"),
			BirthDate:  isoDate(row.Raw("DT_NASCIMENTO")),
			BirthUF:    row.Str("SG_UF_NASCIMENTO"),
			Gender:     row.Str("DS_GENERO"),
			Education:  row.Str("DS_GRAU_INSTRUCAO"),
			Result:     result,
		})
		return nil
	})
}

func Seated(in []Official) []Official {
	type key struct {
		uf, unit string
		office   int
	}
	latest := map[key]string{}
	dates := map[key]string{}
	for _, o := range in {
		k := key{o.UF, o.Unit, o.Office}
		if d, ok := dates[k]; !ok || o.Date > d || (o.Date == d && o.Election > latest[k]) {
			dates[k] = o.Date
			latest[k] = o.Election
		}
	}
	seen := map[string]bool{}
	var out []Official
	for _, o := range in {
		k := key{o.UF, o.Unit, o.Office}
		if latest[k] != o.Election || seen[o.Election+":"+o.SQ] {
			continue
		}
		seen[o.Election+":"+o.SQ] = true
		out = append(out, o)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].UF != out[j].UF {
			return out[i].UF < out[j].UF
		}
		if out[i].Unit != out[j].Unit {
			return out[i].Unit < out[j].Unit
		}
		if out[i].Office != out[j].Office {
			return out[i].Office < out[j].Office
		}
		return out[i].SQ < out[j].SQ
	})
	return out
}

func ReadOfficialVotes(r io.Reader, fn func(sq string, round int, votes int64)) error {
	t, err := open(r, "NR_TURNO", "CD_CARGO", "SQ_CANDIDATO", "QT_VOTOS_NOMINAIS_VALIDOS", "DS_SIT_TOT_TURNO")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		if !Municipal(atoi(row.Raw("CD_CARGO"))) {
			return nil
		}
		n, ok := row.Int("QT_VOTOS_NOMINAIS_VALIDOS")
		if !ok || n < 0 {
			return nil
		}
		fn(row.Str("SQ_CANDIDATO"), atoi(row.Raw("NR_TURNO")), n)
		return nil
	})
}

func digits(s string) string {
	d := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, s)
	if strings.Trim(d, "0") == "" {
		return ""
	}
	return d
}

func TitleKey(title string) string {
	if title == "" {
		return ""
	}
	sum := sha256.Sum256([]byte("fiscal-title:" + title))
	return "titulo:" + hex.EncodeToString(sum[:10])
}
