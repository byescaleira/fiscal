package sidra

import (
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
)

const (
	Name    = "IBGE, Sistema IBGE de Recuperação Automática (SIDRA)"
	SiteURL = "https://sidra.ibge.gov.br/pesquisa/snipc/ipca/tabelas"
	API     = "https://apisidra.ibge.gov.br/values"

	TableIndex = "1737"
	VarIndex   = "2266"
	VarMonthly = "63"
)

var MonthlyTables = []string{"2938", "1419", "7060"}

const (
	General     = "7169"
	FoodAtHome  = "7171"
	Rent        = "7448"
	Electricity = "7485"
	Gasoline    = "7657"
)

var Categories = []string{General, FoodAtHome, Rent, Electricity, Gasoline}

var Areas = map[string]string{
	"1":       "br",
	"1501":    "pa",
	"2301":    "ce",
	"2601":    "pe",
	"2901":    "ba",
	"3101":    "mg",
	"3201":    "es",
	"3301":    "rj",
	"3501":    "sp",
	"4101":    "pr",
	"4301":    "rs",
	"1200401": "ac",
	"2111300": "ma",
	"2800308": "se",
	"5002704": "ms",
	"5208707": "go",
	"5300108": "df",
}

var AreaNames = map[string]string{
	"br": "Brasil",
	"pa": "Região metropolitana de Belém",
	"ce": "Região metropolitana de Fortaleza",
	"pe": "Região metropolitana do Recife",
	"ba": "Região metropolitana de Salvador",
	"mg": "Região metropolitana de Belo Horizonte",
	"es": "Grande Vitória",
	"rj": "Região metropolitana do Rio de Janeiro",
	"sp": "Região metropolitana de São Paulo",
	"pr": "Região metropolitana de Curitiba",
	"rs": "Região metropolitana de Porto Alegre",
	"ac": "Rio Branco",
	"ma": "São Luís",
	"se": "Aracaju",
	"ms": "Campo Grande",
	"go": "Goiânia",
	"df": "Brasília",
}

func IndexURL() string {
	return API + "/t/" + TableIndex + "/n1/all/v/" + VarIndex + "/p/all"
}

func MonthlyURL(table string) string {
	return API + "/t/" + table + "/n1/all/n7/all/n6/all/v/" + VarMonthly + "/p/all/c315/" + strings.Join(Categories, ",")
}

type Row struct {
	Area     string
	AreaName string
	Month    string
	Category string
	Value    *float64
}

func Parse(data []byte) ([]Row, error) {
	var raw []map[string]string
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("sidra: %w", err)
	}
	if len(raw) < 2 {
		return nil, errors.New("sidra: empty table")
	}
	head := raw[0]
	area, month, cat := "", "", ""
	for k, v := range head {
		switch {
		case strings.HasPrefix(v, "Mês (Código)"):
			month = k
		case strings.Contains(v, "(Código)") && (strings.HasPrefix(v, "Brasil") || strings.HasPrefix(v, "Unidade da Federação")):
			area = k
		case strings.HasPrefix(v, "Geral, grupo") && strings.HasSuffix(v, "(Código)"):
			cat = k
		}
	}
	if area == "" || month == "" {
		return nil, errors.New("sidra: header without territory or month")
	}
	nameKey := strings.TrimSuffix(area, "C") + "N"
	out := make([]Row, 0, len(raw)-1)
	for _, r := range raw[1:] {
		m := r[month]
		if len(m) != 6 {
			continue
		}
		row := Row{Area: r[area], AreaName: r[nameKey], Month: m[:4] + "-" + m[4:], Category: r[cat]}
		if v, err := strconv.ParseFloat(strings.TrimSpace(r["V"]), 64); err == nil {
			row.Value = &v
		}
		out = append(out, row)
	}
	return out, nil
}
