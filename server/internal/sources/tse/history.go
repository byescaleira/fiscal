package tse

import (
	"fmt"
	"io"
	"strings"

	"liveresults/internal/sources/table"
)

const (
	FirstMunZoneYear = 1994
	UFOnlyYear       = 1989
)

func TurnoutURL(year int) string {
	return fmt.Sprintf("%s/detalhe_votacao_munzona/detalhe_votacao_munzona_%d.zip", Base, year)
}

func UFVotesURL(year int) string {
	return fmt.Sprintf("%s/votacao_candidato_uf/votacao_candidato_uf_%d.zip", Base, year)
}

func UFTurnoutURL(year int) string {
	return fmt.Sprintf("%s/detalhe_votacao_uf/detalhe_votacao_uf_%d.zip", Base, year)
}

func Majoritarian(office int) bool {
	return office == President || office == Governor || office == Senator
}

type VoteRow struct {
	Round      int
	Date       string
	Office     int
	UF         string
	Unit       string
	SQ         string
	Number     string
	Name       string
	BallotName string
	Party      string
	Coalition  string
	Members    string
	Result     string
	Valid      int64
	Nominal    int64
}

type TurnoutRow struct {
	Round       int
	Office      int
	UF          string
	Unit        string
	Electorate  int64
	Turnout     int64
	Abstentions int64
	Blank       int64
	Null        int64
}

func count(row table.Row, col string) int64 {
	n, ok := row.Int(col)
	if !ok || n < 0 {
		return 0
	}
	return n
}

func ReadMajoritarianVotes(r io.Reader, fn func(VoteRow)) error {
	t, err := open(r, "NR_TURNO", "CD_CARGO", "SG_UF", "SG_UE", "SQ_CANDIDATO", "NR_CANDIDATO", "NM_CANDIDATO", "NM_URNA_CANDIDATO", "SG_PARTIDO", "QT_VOTOS_NOMINAIS_VALIDOS", "DS_SIT_TOT_TURNO")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		office := atoi(row.Raw("CD_CARGO"))
		if !Majoritarian(office) {
			return nil
		}
		fn(VoteRow{
			Round:      atoi(row.Raw("NR_TURNO")),
			Date:       isoDate(row.Raw("DT_ELEICAO")),
			Office:     office,
			UF:         strings.ToUpper(row.Str("SG_UF")),
			Unit:       strings.ToUpper(row.Str("SG_UE")),
			SQ:         row.Str("SQ_CANDIDATO"),
			Number:     row.Str("NR_CANDIDATO"),
			Name:       row.Str("NM_CANDIDATO"),
			BallotName: row.Str("NM_URNA_CANDIDATO"),
			Party:      row.Str("SG_PARTIDO"),
			Coalition:  row.Str("NM_COLIGACAO"),
			Members:    row.Str("DS_COMPOSICAO_COLIGACAO"),
			Result:     row.Str("DS_SIT_TOT_TURNO"),
			Valid:      count(row, "QT_VOTOS_NOMINAIS_VALIDOS"),
			Nominal:    count(row, "QT_VOTOS_NOMINAIS"),
		})
		return nil
	})
}

func ReadTurnout(r io.Reader, fn func(TurnoutRow)) error {
	t, err := open(r, "NR_TURNO", "CD_CARGO", "SG_UF", "SG_UE", "QT_APTOS", "QT_COMPARECIMENTO", "QT_ABSTENCOES", "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		office := atoi(row.Raw("CD_CARGO"))
		if !Majoritarian(office) {
			return nil
		}
		null := count(row, "QT_TOTAL_VOTOS_NULOS")
		if null == 0 {
			null = count(row, "QT_VOTOS_NULOS") + count(row, "QT_VOTOS_NULOS_TECNICOS")
		}
		fn(TurnoutRow{
			Round:       atoi(row.Raw("NR_TURNO")),
			Office:      office,
			UF:          strings.ToUpper(row.Str("SG_UF")),
			Unit:        strings.ToUpper(row.Str("SG_UE")),
			Electorate:  count(row, "QT_APTOS"),
			Turnout:     count(row, "QT_COMPARECIMENTO"),
			Abstentions: count(row, "QT_ABSTENCOES"),
			Blank:       count(row, "QT_VOTOS_BRANCOS"),
			Null:        null,
		})
		return nil
	})
}

var ufVoteColumns = []string{
	"DATA_GERACAO", "HORA_GERACAO", "ANO_ELEICAO", "NUM_TURNO", "DESCRICAO_ELEICAO", "SIGLA_UF", "SIGLA_UE",
	"CODIGO_CARGO", "NUMERO_CAND", "SQ_CANDIDATO", "NOME_CANDIDATO", "NOME_URNA_CANDIDATO", "DESCRICAO_CARGO",
	"COD_SIT_CAND_SUPERIOR", "DESC_SIT_CAND_SUPERIOR", "CODIGO_SIT_CANDIDATO", "DESC_SIT_CANDIDATO",
	"CODIGO_SIT_CAND_TOT", "DESC_SIT_CAND_TOT", "NUMERO_PARTIDO", "SIGLA_PARTIDO", "NOME_PARTIDO",
	"SEQUENCIAL_LEGENDA", "NOME_COLIGACAO", "COMPOSICAO_LEGENDA", "TOTAL_VOTOS",
}

var ufTurnoutColumns = []string{
	"DATA_GERACAO", "HORA_GERACAO", "ANO_ELEICAO", "NUM_TURNO", "DESCRICAO_ELEICAO", "SIGLA_UF", "SIGLA_UE",
	"CODIGO_CARGO", "DESCRICAO_CARGO", "QTD_APTOS", "QTD_COMPARECIMENTO", "QTD_ABSTENCOES", "QTD_VOTOS_NOMINAIS",
	"QTD_VOTOS_BRANCOS", "QTD_VOTOS_NULOS", "QTD_VOTOS_LEGENDA", "QTD_VOTOS_ANULADOS_APU_SEP", "QTD_SECOES_TOT",
	"QTD_SECOES_ANULADAS", "QTD_SECOES_SEM_FUNCION", "QTD_ZONAS_ELEITORAIS", "QTD_JUNTAS_APURADORAS",
}

func headed(r io.Reader, cols []string) io.Reader {
	return io.MultiReader(strings.NewReader(`"`+strings.Join(cols, `";"`)+`"`+"\n"), r)
}

func ReadUFVotes(r io.Reader, fn func(VoteRow)) error {
	t, err := open(headed(r, ufVoteColumns), "NUM_TURNO", "CODIGO_CARGO", "SIGLA_UF", "SQ_CANDIDATO", "TOTAL_VOTOS")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		office := atoi(row.Raw("CODIGO_CARGO"))
		if !Majoritarian(office) {
			return nil
		}
		votes := count(row, "TOTAL_VOTOS")
		fn(VoteRow{
			Round:      atoi(row.Raw("NUM_TURNO")),
			Office:     office,
			UF:         strings.ToUpper(row.Str("SIGLA_UF")),
			Unit:       strings.ToUpper(row.Str("SIGLA_UE")),
			SQ:         row.Str("SQ_CANDIDATO"),
			Number:     row.Str("NUMERO_CAND"),
			Name:       row.Str("NOME_CANDIDATO"),
			BallotName: row.Str("NOME_URNA_CANDIDATO"),
			Party:      row.Str("SIGLA_PARTIDO"),
			Coalition:  row.Str("NOME_COLIGACAO"),
			Members:    row.Str("COMPOSICAO_LEGENDA"),
			Result:     row.Str("DESC_SIT_CAND_TOT"),
			Valid:      votes,
			Nominal:    votes,
		})
		return nil
	})
}

func ReadUFTurnout(r io.Reader, fn func(TurnoutRow)) error {
	t, err := open(headed(r, ufTurnoutColumns), "NUM_TURNO", "CODIGO_CARGO", "SIGLA_UF", "QTD_APTOS", "QTD_COMPARECIMENTO")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		office := atoi(row.Raw("CODIGO_CARGO"))
		if !Majoritarian(office) {
			return nil
		}
		fn(TurnoutRow{
			Round:       atoi(row.Raw("NUM_TURNO")),
			Office:      office,
			UF:          strings.ToUpper(row.Str("SIGLA_UF")),
			Unit:        strings.ToUpper(row.Str("SIGLA_UE")),
			Electorate:  count(row, "QTD_APTOS"),
			Turnout:     count(row, "QTD_COMPARECIMENTO"),
			Abstentions: count(row, "QTD_ABSTENCOES"),
			Blank:       count(row, "QTD_VOTOS_BRANCOS"),
			Null:        count(row, "QTD_VOTOS_NULOS"),
		})
		return nil
	})
}
