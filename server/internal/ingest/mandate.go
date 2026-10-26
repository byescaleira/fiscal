package ingest

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"

	"liveresults/internal/publicdata"
	"liveresults/internal/sources/sidra"
)

const (
	mandateCheckedAt   = "2026-10-25"
	camaraGuideID      = "camara-guia"
	camaraGuideName    = "Câmara dos Deputados, Guia para jornalistas"
	camaraGuideURL     = "https://www2.camara.leg.br/comunicacao/assessoria-de-imprensa/guia-para-jornalistas"
	quotaAct           = "Ato da Mesa nº 43/2009, valores em vigor"
	quotaURL           = camaraGuideURL + "/cota-parlamentar"
	staffAct           = "Ato da Mesa nº 243/2026"
	staffURL           = "https://www2.camara.leg.br/legin/int/atomes/2026/atodamesa-243-20-fevereiro-2026-798719-norma-cd-mesa.html"
	staffSince         = "2026-02-20"
	staffCents         = 16580607
	housingAct         = "Ato da Mesa nº 3/2015"
	housingURL         = camaraGuideURL + "/auxilio-moradia-e-apartamento-funcional"
	housingCents       = 425300
	salarySince        = "2025-02-01"
	minimumWageID      = "planalto"
	minimumWageName    = "Presidência da República, Planalto"
	minimumWageAct     = "Decreto nº 12.797/2025"
	minimumWageURL     = "https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/decreto/D12797.htm"
	minimumWageSince   = "2026-01-01"
	minimumWageCents   = 162100
	laborIncomeID      = "sidra-rendimento"
	laborIncomeAct     = "PNAD Contínua, rendimento médio mensal real habitual de todos os trabalhos"
	laborIncomeStore   = "labor-income.json"
	laborIncomeMaxSize = 1 << 20
)

var deputyQuotaCents = map[string]int64{
	"ac": 5735987, "al": 5316436, "am": 5615146, "ap": 5592926, "ba": 5096529,
	"ce": 5487934, "df": 4161255, "es": 4916015, "go": 4697973, "ma": 5453799,
	"mg": 4764591, "ms": 5270793, "mt": 5143983, "pa": 5462417, "pb": 5440248,
	"pe": 5399781, "pi": 5319584, "pr": 5080719, "rj": 4726741, "rn": 5519809,
	"ro": 5626790, "rr": 5847470, "rs": 5308678, "sc": 5195142, "se": 5224886,
	"sp": 4872746, "to": 5152580,
}

func (in *Ingest) loadMandate(ctx context.Context, rep *Report, srcs *sourceSet) (*publicdata.MandateCost, []string) {
	salary := func() publicdata.MandateItem {
		return publicdata.MandateItem{Kind: publicdata.MandateSalary, MonthlyCents: pointer(int64(federalPay)), Act: publicdata.MandateAct{Name: salaryLaw, URL: salaryLawURL, Since: pointer(salarySince)}}
	}
	quota := make([]publicdata.MandateStateCents, 0, len(deputyQuotaCents))
	for uf, cents := range deputyQuotaCents {
		quota = append(quota, publicdata.MandateStateCents{UF: uf, MonthlyCents: cents})
	}
	sort.Slice(quota, func(i, j int) bool { return quota[i].UF < quota[j].UF })
	deputy := publicdata.MandateRole{
		Role: publicdata.MandateFederalDeputy,
		Items: []publicdata.MandateItem{
			salary(),
			{Kind: publicdata.MandateQuota, ByState: quota, Act: publicdata.MandateAct{Name: quotaAct, URL: quotaURL}},
			{Kind: publicdata.MandateStaff, MonthlyCents: pointer(int64(staffCents)), Act: publicdata.MandateAct{Name: staffAct, URL: staffURL, Since: pointer(staffSince)}},
			{Kind: publicdata.MandateHousing, MonthlyCents: pointer(int64(housingCents)), Act: publicdata.MandateAct{Name: housingAct, URL: housingURL}},
		},
		Unpublished: []string{},
	}
	roles := []publicdata.MandateRole{deputy}
	roles = append(roles, publicdata.MandateRole{
		Role: publicdata.MandateSenator, Items: []publicdata.MandateItem{salary()},
		Unpublished: []string{publicdata.MandateQuota, publicdata.MandateStaff, publicdata.MandateHousing},
	})
	for _, r := range []string{publicdata.MandatePresident, publicdata.MandateVicePresident, publicdata.MandateMinister} {
		roles = append(roles, publicdata.MandateRole{Role: r, Items: []publicdata.MandateItem{salary()}, Unpublished: []string{}})
	}
	out := &publicdata.MandateCost{
		CheckedAt: mandateCheckedAt,
		Roles:     roles,
		MinimumWage: &publicdata.MandateReference{
			MonthlyCents: minimumWageCents,
			Act:          publicdata.MandateAct{Name: minimumWageAct, URL: minimumWageURL, Since: pointer(minimumWageSince)},
		},
	}
	srcs.add(camaraGuideID, camaraGuideName, camaraGuideURL, deputy)
	srcs.add(minimumWageID, minimumWageName, minimumWageURL, out.MinimumWage)
	ids := []string{"legislacao", camaraGuideID, minimumWageID}
	if in.cfg.Enabled("sidra") {
		if inc, ok := in.laborIncome(ctx, rep); ok {
			out.LaborIncome = &publicdata.MandateReference{
				MonthlyCents: inc.Cents,
				Period:       pointer(inc.Name),
				Act:          publicdata.MandateAct{Name: laborIncomeAct, URL: sidra.IncomeSiteURL},
			}
			srcs.add(laborIncomeID, sidra.IncomeName, sidra.IncomeSiteURL, inc)
			ids = append(ids, laborIncomeID)
		}
	}
	return out, ids
}

func (in *Ingest) laborIncome(ctx context.Context, rep *Report) (sidra.Income, bool) {
	path := filepath.Join(in.cfg.DataDir, laborIncomeStore)
	var prev sidra.Income
	if data, err := os.ReadFile(path); err == nil {
		json.Unmarshal(data, &prev)
	}
	inc, err := in.fetchLaborIncome(ctx)
	if err != nil {
		in.warn(rep, "sidra income: %v (kept the last quarter loaded)", err)
		return prev, prev.Cents > 0
	}
	if data, err := json.Marshal(inc); err == nil {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err == nil {
			tmp := path + ".tmp"
			if os.WriteFile(tmp, data, 0o600) == nil {
				os.Rename(tmp, path)
			}
		}
	}
	return inc, true
}

func (in *Ingest) fetchLaborIncome(ctx context.Context) (sidra.Income, error) {
	c, err := in.get.Cache(ctx, sidra.IncomeURL(), laborIncomeMaxSize)
	if err != nil {
		return sidra.Income{}, err
	}
	data, err := os.ReadFile(c.Path)
	if err != nil {
		return sidra.Income{}, err
	}
	return sidra.ParseIncome(data)
}

func pointer[T any](v T) *T {
	return &v
}
