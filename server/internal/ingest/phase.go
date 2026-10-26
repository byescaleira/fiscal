package ingest

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"

	"liveresults/internal/sources/assembleias"
)

type Phase struct {
	Name    string
	Sources []string
	Note    string
}

var Phases = []Phase{
	{Name: "camara", Sources: []string{"camara"}, Note: "deputados federais, votos, presença, propostas, discursos e a cota (CEAP) da Câmara"},
	{Name: "senado", Sources: []string{"senado"}, Note: "senadores, votos, propostas, discursos e a cota (CEAPS) do Senado"},
	{Name: "assembleias", Sources: []string{"assembleias"}, Note: "assembleias com SAPL (AC, AM, PB, PI e RO)"},
	{Name: "tse", Sources: []string{"tse"}, Note: "candidaturas, bens, votos e contas das eleições gerais"},
	{Name: "cidades", Sources: []string{"ibge", "cidades"}, Note: "municípios do IBGE e prefeitos, vices e vereadores"},
	{Name: "checagens", Sources: []string{"comprova"}, Note: "checagens do Projeto Comprova"},
	{Name: "indicadores", Sources: []string{"anp", "sidra"}, Note: "preços da ANP e IPCA do SIDRA"},
	{Name: "receita", Sources: []string{"receita"}, Note: "arrecadação federal por estado"},
	{Name: "repercussao", Sources: []string{"repercussao"}, Note: "contagens do GDELT e da Wikipédia"},
	{Name: "memoria", Note: "reconstrução completa a partir do banco, sem ler nenhuma fonte"},
}

func PhaseByName(name string) (Phase, bool) {
	for _, p := range Phases {
		if p.Name == name {
			return p, true
		}
	}
	return Phase{}, false
}

func (p Phase) Refresh() map[string]bool {
	out := map[string]bool{"none": true}
	for _, s := range p.Sources {
		out[s] = true
	}
	return out
}

func (c Config) refresh(source string) bool {
	return len(c.Refresh) == 0 || c.Refresh[source]
}

const pastAssemblyTTL = 30 * 24 * time.Hour

func (in *Ingest) recent(path string, ttl time.Duration) bool {
	info, err := os.Stat(path)
	return err == nil && in.now().Sub(info.ModTime()) < ttl
}

func (in *Ingest) assemblyCache(h assembleias.House, year int) string {
	return filepath.Join(in.cfg.DataDir, "cache", "assembleias", h.UF+"-"+strconv.Itoa(year)+".json")
}

func (in *Ingest) assembly(ctx context.Context, h assembleias.House, year int) (assembleias.Data, string, error) {
	path := in.assemblyCache(h, year)
	readCache := func() (assembleias.Data, bool) {
		var d assembleias.Data
		raw, err := os.ReadFile(path)
		if err != nil || json.Unmarshal(raw, &d) != nil || len(d.Members) == 0 {
			return d, false
		}
		return d, true
	}
	refresh := in.cfg.refresh("assembleias")
	if !refresh || (year < in.currentYear() && in.recent(path, pastAssemblyTTL)) {
		if d, ok := readCache(); ok {
			return d, "", nil
		}
		if !refresh {
			return assembleias.Data{}, "", fmt.Errorf("%s %d is not cached yet; only the assembleias job reads the SAPL", h.UF, year)
		}
	}
	d, err := assembleias.Load(ctx, in.get, h, year, in.today())
	if err != nil {
		if cached, ok := readCache(); ok {
			return cached, err.Error() + " (using the last good read)", nil
		}
		return d, "", err
	}
	if raw, err := json.Marshal(d); err == nil {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err == nil {
			tmp := path + ".tmp"
			if os.WriteFile(tmp, raw, 0o600) == nil {
				os.Rename(tmp, path)
			}
		}
	}
	return d, "", nil
}

func PhaseNames() []string {
	out := make([]string, 0, len(Phases))
	for _, p := range Phases {
		out = append(out, p.Name)
	}
	sort.Strings(out)
	return out
}
