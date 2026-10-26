package publicdata

const (
	MandateFederalDeputy = "federalDeputy"
	MandateSenator       = "senator"
	MandatePresident     = "president"
	MandateVicePresident = "vicePresident"
	MandateMinister      = "minister"
	MandateSalary        = "salary"
	MandateQuota         = "quota"
	MandateStaff         = "staff"
	MandateHousing       = "housing"
)

type MandateAct struct {
	Name  string  `json:"name"`
	URL   string  `json:"url"`
	Since *string `json:"since"`
}

type MandateStateCents struct {
	UF           string `json:"uf"`
	MonthlyCents int64  `json:"monthlyCents"`
}

type MandateItem struct {
	Kind         string              `json:"kind"`
	MonthlyCents *int64              `json:"monthlyCents"`
	ByState      []MandateStateCents `json:"byState"`
	Act          MandateAct          `json:"act"`
}

type MandateRole struct {
	Role        string        `json:"role"`
	Items       []MandateItem `json:"items"`
	Unpublished []string      `json:"unpublished"`
}

type MandateReference struct {
	MonthlyCents int64      `json:"monthlyCents"`
	Period       *string    `json:"period"`
	Act          MandateAct `json:"act"`
}

type MandateCost struct {
	CheckedAt   string            `json:"checkedAt"`
	Roles       []MandateRole     `json:"roles"`
	MinimumWage *MandateReference `json:"minimumWage"`
	LaborIncome *MandateReference `json:"laborIncome"`
	Sources     []Source          `json:"sources"`
}

func (b *builder) mandate() {
	m := b.ds.Mandate
	if m == nil || len(m.Roles) == 0 {
		return
	}
	out := *m
	out.Roles = make([]MandateRole, len(m.Roles))
	for i, role := range m.Roles {
		if role.Unpublished == nil {
			role.Unpublished = []string{}
		}
		out.Roles[i] = role
	}
	out.Sources = b.sources(b.ds.MandateSources...)
	b.add("money/mandate-cost.json", out)
}
