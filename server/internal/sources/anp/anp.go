package anp

import (
	"errors"
	"fmt"
	"io"
	"math"
	"strconv"
	"strings"
	"time"

	"liveresults/internal/sources/xlsx"
)

const (
	Name    = "Agência Nacional do Petróleo, Gás Natural e Biocombustíveis (ANP)"
	SiteURL = "https://www.gov.br/anp/pt-br/assuntos/precos-e-defesa-da-concorrencia/precos/precos-revenda-e-de-distribuicao-combustiveis/serie-historica-do-levantamento-de-precos"
	base    = "https://www.gov.br/anp/pt-br/assuntos/precos-e-defesa-da-concorrencia/precos/precos-revenda-e-de-distribuicao-combustiveis/shlp/"
)

var Files = []string{
	base + "2001-2012/mensal-brasil-2001-a-2012.xlsx",
	base + "2001-2012/mensal-estados-2001-a-2012.xlsx",
	base + "mensal/mensal-brasil-desde-jan2013.xlsx",
	base + "mensal/mensal-estados-desde-jan2013.xlsx",
}

const (
	Gasoline  = "GASOLINA COMUM"
	Ethanol   = "ETANOL HIDRATADO"
	DieselS10 = "OLEO DIESEL S10"
	LPG       = "GLP"
)

type Row struct {
	Month   string
	Product string
	State   string
	Price   float64
}

var folder = strings.NewReplacer(
	"Á", "A", "À", "A", "Â", "A", "Ã", "A", "É", "E", "Ê", "E", "Í", "I", "Ó", "O", "Ô", "O", "Õ", "O", "Ú", "U", "Ç", "C",
	"á", "A", "à", "A", "â", "A", "ã", "A", "é", "E", "ê", "E", "í", "I", "ó", "O", "ô", "O", "õ", "O", "ú", "U", "ç", "C",
)

func Norm(s string) string {
	return strings.Join(strings.Fields(strings.ToUpper(folder.Replace(s))), " ")
}

func Parse(r io.ReaderAt, size int64) ([]Row, error) {
	rows, err := xlsx.FirstSheet(r, size)
	if err != nil {
		return nil, err
	}
	month, product, state, price := -1, -1, -1, -1
	var out []Row
	for _, row := range rows {
		if month < 0 {
			for c, v := range row {
				switch Norm(v) {
				case "MES":
					month = c
				case "PRODUTO":
					product = c
				case "ESTADO":
					state = c
				case "PRECO MEDIO REVENDA":
					price = c
				}
			}
			if month >= 0 && (product < 0 || price < 0) {
				return nil, errors.New("anp: header without PRODUTO or PREÇO MÉDIO REVENDA")
			}
			continue
		}
		m, ok := serialMonth(row[month])
		if !ok {
			continue
		}
		p, err := strconv.ParseFloat(strings.TrimSpace(row[price]), 64)
		if err != nil || p <= 0 || math.IsNaN(p) {
			continue
		}
		r := Row{Month: m, Product: Norm(row[product]), Price: p}
		if state >= 0 {
			r.State = Norm(row[state])
			if r.State == "" {
				continue
			}
		}
		out = append(out, r)
	}
	if month < 0 {
		return nil, errors.New("anp: header row not found")
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("anp: no price rows")
	}
	return out, nil
}

func serialMonth(v string) (string, bool) {
	f, err := strconv.ParseFloat(strings.TrimSpace(v), 64)
	if err != nil || f < 30000 || f > 80000 {
		return "", false
	}
	t := time.Date(1899, 12, 30, 0, 0, 0, 0, time.UTC).AddDate(0, 0, int(f))
	return t.Format("2006-01"), true
}
