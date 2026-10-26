package ibge

import (
	"encoding/json"
	"fmt"
	"strconv"
)

const (
	MunicipalitiesURL = "https://servicodados.ibge.gov.br/api/v1/localidades/municipios?view=nivelado"
	SiteURL           = "https://servicodados.ibge.gov.br"
)

type Municipality struct {
	Code string
	Name string
	UF   string
}

type State struct {
	UF   string
	Name string
}

var States = []State{
	{"AC", "Acre"}, {"AL", "Alagoas"}, {"AP", "Amapá"}, {"AM", "Amazonas"}, {"BA", "Bahia"},
	{"CE", "Ceará"}, {"DF", "Distrito Federal"}, {"ES", "Espírito Santo"}, {"GO", "Goiás"},
	{"MA", "Maranhão"}, {"MT", "Mato Grosso"}, {"MS", "Mato Grosso do Sul"}, {"MG", "Minas Gerais"},
	{"PA", "Pará"}, {"PB", "Paraíba"}, {"PR", "Paraná"}, {"PE", "Pernambuco"}, {"PI", "Piauí"},
	{"RJ", "Rio de Janeiro"}, {"RN", "Rio Grande do Norte"}, {"RS", "Rio Grande do Sul"},
	{"RO", "Rondônia"}, {"RR", "Roraima"}, {"SC", "Santa Catarina"}, {"SP", "São Paulo"},
	{"SE", "Sergipe"}, {"TO", "Tocantins"},
}

func StateName(uf string) string {
	for _, s := range States {
		if s.UF == uf {
			return s.Name
		}
	}
	return ""
}

func ParseMunicipalities(data []byte) ([]Municipality, error) {
	var rows []struct {
		ID   json.Number `json:"municipio-id"`
		Nome string      `json:"municipio-nome"`
		UF   string      `json:"UF-sigla"`
	}
	if err := json.Unmarshal(data, &rows); err != nil {
		return nil, fmt.Errorf("ibge: %w", err)
	}
	out := make([]Municipality, 0, len(rows))
	for _, r := range rows {
		code := r.ID.String()
		if n, err := strconv.ParseInt(code, 10, 64); err != nil || n < 1000000 || n > 9999999 {
			return nil, fmt.Errorf("ibge: invalid municipality code %q", code)
		}
		if StateName(r.UF) == "" {
			return nil, fmt.Errorf("ibge: unknown UF %q", r.UF)
		}
		out = append(out, Municipality{Code: code, Name: r.Nome, UF: r.UF})
	}
	return out, nil
}
