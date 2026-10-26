package sidra

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strconv"
	"strings"
)

const (
	IncomeName    = "IBGE, PNAD Contínua trimestral (tabela 5436)"
	IncomeSiteURL = "https://sidra.ibge.gov.br/tabela/5436"
	IncomeTable   = "5436"
	IncomeVar     = "5933"
	incomeTotal   = "6794"
)

type Income struct {
	Quarter string `json:"quarter"`
	Name    string `json:"name"`
	Cents   int64  `json:"cents"`
}

func IncomeURL() string {
	return API + "/t/" + IncomeTable + "/n1/all/v/" + IncomeVar + "/p/last%201/c2/" + incomeTotal
}

func ParseIncome(data []byte) (Income, error) {
	var raw []map[string]string
	if err := json.Unmarshal(data, &raw); err != nil {
		return Income{}, fmt.Errorf("sidra income: %w", err)
	}
	if len(raw) < 2 {
		return Income{}, errors.New("sidra income: empty table")
	}
	head := raw[0]
	period := ""
	for k, v := range head {
		if strings.HasPrefix(v, "Trimestre (Código)") {
			period = k
		}
	}
	if period == "" {
		return Income{}, errors.New("sidra income: header without quarter")
	}
	nameKey := strings.TrimSuffix(period, "C") + "N"
	var best Income
	for _, r := range raw[1:] {
		code := r[period]
		v, err := strconv.ParseFloat(strings.TrimSpace(r["V"]), 64)
		if len(code) != 6 || err != nil || v <= 0 {
			continue
		}
		q := code[:4] + "-Q" + strings.TrimLeft(code[4:], "0")
		if q > best.Quarter {
			best = Income{Quarter: q, Name: r[nameKey], Cents: int64(math.Round(v * 100))}
		}
	}
	if best.Quarter == "" {
		return Income{}, errors.New("sidra income: no value")
	}
	return best, nil
}
