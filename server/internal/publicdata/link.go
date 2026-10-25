package publicdata

import (
	"sort"
	"strconv"
	"strings"
)

type LinkInput struct {
	People       []*Person
	Candidacies  []Candidacy
	PreviousYear int
	ElectionYear int
	StateNames   map[string]string
}

func Link(in LinkInput) []*Person {
	byCPF := map[string][]Candidacy{}
	for _, c := range in.Candidacies {
		if c.CPF == "" {
			continue
		}
		byCPF[c.CPF] = append(byCPF[c.CPF], c)
	}
	people := append([]*Person(nil), in.People...)
	index := map[string]*Person{}
	for _, p := range people {
		if p.CPF == "" && p.House == HouseSenado {
			if cpf, ok := FindSenatorCPF(p, in.Candidacies); ok {
				p.CPF = cpf
			}
		}
		if p.CPF == "" {
			continue
		}
		if _, dup := index[p.CPF]; dup {
			continue
		}
		index[p.CPF] = p
		p.AddKey(CPFKey(p.CPF))
		attach(p, byCPF[p.CPF])
	}
	get := func(c Candidacy) *Person {
		if c.CPF != "" {
			if p, ok := index[c.CPF]; ok {
				return p
			}
		}
		p := personFromCandidacy(c)
		if c.CPF != "" {
			index[c.CPF] = p
			attach(p, byCPF[c.CPF])
		} else {
			attach(p, []Candidacy{c})
		}
		people = append(people, p)
		return p
	}
	prev := filter(in.Candidacies, func(c Candidacy) bool { return c.Year == in.PreviousYear && c.Elected })
	next := filter(in.Candidacies, func(c Candidacy) bool { return c.Year == in.ElectionYear && c.Elected })
	ranAgain := func(cpf string, allowed ...string) bool {
		if cpf == "" {
			return false
		}
		for _, c := range byCPF[cpf] {
			if c.Year != in.ElectionYear {
				continue
			}
			ok := false
			for _, a := range allowed {
				if c.Office == a {
					ok = true
				}
			}
			if !ok {
				return true
			}
		}
		return false
	}
	for _, pair := range [][2]string{{OfficePresident, OfficeVicePresident}, {OfficeGovernor, OfficeViceGovernor}} {
		head, vice := pair[0], pair[1]
		heads := map[string]Candidacy{}
		vices := map[string]Candidacy{}
		for _, c := range prev {
			switch c.Office {
			case head:
				heads[c.UF] = c
			case vice:
				vices[c.UF] = c
			}
		}
		ufs := keys(heads, vices)
		for _, uf := range ufs {
			h, hasHead := heads[uf]
			v, hasVice := vices[uf]
			resigned := hasHead && ranAgain(h.CPF, head)
			start, end := MandateFor(head, in.PreviousYear)
			if hasHead && !resigned {
				p := get(h)
				addRole(p, Role{Office: head, UF: uf, Status: StatusInOffice, Party: h.Party, MandateStart: start, MandateEnd: end})
				if hasVice {
					pv := get(v)
					addRole(pv, Role{Office: vice, UF: uf, Status: StatusInOffice, Party: v.Party, MandateStart: start, MandateEnd: end})
				}
				continue
			}
			if hasVice && !ranAgain(v.CPF, head, vice) {
				pv := get(v)
				addRole(pv, Role{Office: head, UF: uf, Status: StatusInOffice, Party: v.Party, MandateEnd: end})
			}
		}
	}
	for _, c := range prev {
		if c.Office != OfficeStateDeputy {
			continue
		}
		p := get(c)
		addRole(p, Role{Office: OfficeStateDeputy, UF: c.UF, Status: StatusInOffice, Party: c.Party})
	}
	for _, c := range next {
		start, end := MandateFor(c.Office, c.Year)
		p := get(c)
		addRole(p, Role{Office: c.Office, UF: c.UF, Status: StatusElected, Party: c.Party, MandateStart: start, MandateEnd: end})
	}
	for _, p := range people {
		enrich(p, in.StateNames)
	}
	return people
}

func FindSenatorCPF(p *Person, cands []Candidacy) (string, bool) {
	role := p.Primary()
	year := 0
	if len(role.MandateStart) >= 4 {
		y, err := strconv.Atoi(role.MandateStart[:4])
		if err == nil {
			year = y - 1
		}
	}
	full, short := Fold(p.CivilName), Fold(p.Name)
	var found []string
	seen := map[string]bool{}
	for _, c := range cands {
		if c.Office != OfficeSenator || c.UF != role.UF || c.CPF == "" || (year != 0 && c.Year != year) {
			continue
		}
		if (full != "" && Fold(c.Name) == full) || (short != "" && Fold(c.BallotName) == short) {
			if !seen[c.CPF] {
				seen[c.CPF] = true
				found = append(found, c.CPF)
			}
		}
	}
	if len(found) != 1 {
		return "", false
	}
	return found[0], true
}

func MandateFor(office string, electionYear int) (string, string) {
	y := electionYear
	ys := func(n int) string { return strconv.Itoa(n) }
	switch office {
	case OfficePresident, OfficeVicePresident:
		if y == 2022 {
			return "2023-01-01", "2027-01-05"
		}
		if y >= 2026 {
			return ys(y+1) + "-01-05", ys(y+5) + "-01-05"
		}
	case OfficeGovernor, OfficeViceGovernor:
		if y == 2022 {
			return "2023-01-01", "2027-01-06"
		}
		if y >= 2026 {
			return ys(y+1) + "-01-06", ys(y+5) + "-01-06"
		}
	case OfficeSenator:
		return ys(y+1) + "-02-01", ys(y+9) + "-01-31"
	case OfficeFederalDeputy:
		return ys(y+1) + "-02-01", ys(y+5) + "-01-31"
	}
	return "", ""
}

func attach(p *Person, cands []Candidacy) {
	have := map[string]bool{}
	for _, c := range p.Candidacies {
		have[strconv.Itoa(c.Year)+":"+c.SQ] = true
	}
	for _, c := range cands {
		k := strconv.Itoa(c.Year) + ":" + c.SQ
		if have[k] {
			continue
		}
		have[k] = true
		p.Candidacies = append(p.Candidacies, c)
	}
	sort.SliceStable(p.Candidacies, func(i, j int) bool { return p.Candidacies[i].Year > p.Candidacies[j].Year })
	if len(p.Candidacies) > 0 {
		p.AddSource("tse")
	}
}

func addRole(p *Person, r Role) {
	if p.HasRole(r.Office, r.UF, r.Status) {
		return
	}
	p.Roles = append(p.Roles, r)
}

func personFromCandidacy(c Candidacy) *Person {
	p := &Person{Name: TitleName(c.BallotName), CivilName: TitleName(c.Name), CPF: c.CPF}
	if p.Name == "" {
		p.Name = p.CivilName
	}
	if c.CPF != "" {
		p.AddKey(CPFKey(c.CPF))
	} else {
		p.AddKey("tse:" + strconv.Itoa(c.Year) + ":" + c.SQ)
	}
	return p
}

func enrich(p *Person, states map[string]string) {
	if len(p.Candidacies) == 0 {
		return
	}
	latest := p.Candidacies[0]
	if p.BirthDate == "" {
		p.BirthDate = latest.BirthDate
	}
	if p.BirthPlace == "" && latest.BirthUF != "" {
		if n := states[strings.ToLower(latest.BirthUF)]; n != "" {
			p.BirthPlace = n
		}
	}
	if p.Education == "" && latest.Education != "" {
		p.Education = Sentence(strings.ToLower(latest.Education))
		p.Education = strings.TrimSuffix(p.Education, ".")
	}
	if p.CivilName == "" {
		p.CivilName = TitleName(latest.Name)
	}
}

func filter(in []Candidacy, keep func(Candidacy) bool) []Candidacy {
	var out []Candidacy
	for _, c := range in {
		if keep(c) {
			out = append(out, c)
		}
	}
	return out
}

func keys(maps ...map[string]Candidacy) []string {
	set := map[string]bool{}
	for _, m := range maps {
		for k := range m {
			set[k] = true
		}
	}
	out := make([]string, 0, len(set))
	for k := range set {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

type AssemblyMember struct {
	ID       int64
	Name     string
	FullName string
	Email    string
	Phone    string
	Photo    string
}

func LinkAssembly(people []*Person, cands []Candidacy, uf string, year int, members []AssemblyMember, house string, states map[string]string) ([]*Person, map[int64]*Person) {
	matched := map[int64]*Person{}
	elected := map[*Person]bool{}
	for _, p := range people {
		if p.HasRole(OfficeStateDeputy, uf, StatusInOffice) {
			elected[p] = true
		}
	}
	match := func(m AssemblyMember, c Candidacy) bool {
		return (m.Name != "" && Fold(m.Name) == Fold(c.BallotName)) || (m.FullName != "" && Fold(m.FullName) == Fold(c.Name))
	}
	for _, m := range members {
		var hit *Person
		for p := range elected {
			for _, c := range p.Candidacies {
				if c.Year == year && c.Office == OfficeStateDeputy && c.UF == uf && match(m, c) {
					hit = p
				}
			}
		}
		if hit != nil {
			matched[m.ID] = hit
		}
	}
	enough := len(elected) > 0 && len(matched)*5 >= len(elected)*4
	byCPF := map[string]*Person{}
	for _, p := range people {
		if p.CPF != "" {
			byCPF[p.CPF] = p
		}
	}
	for _, m := range members {
		if _, ok := matched[m.ID]; ok {
			continue
		}
		var found []Candidacy
		for _, c := range cands {
			if c.Year == year && c.Office == OfficeStateDeputy && c.UF == uf && match(m, c) {
				found = append(found, c)
			}
		}
		if len(found) != 1 {
			continue
		}
		c := found[0]
		p := byCPF[c.CPF]
		if p == nil {
			p = personFromCandidacy(c)
			for _, x := range cands {
				if x.CPF != "" && x.CPF == c.CPF {
					attach(p, []Candidacy{x})
				}
			}
			attach(p, []Candidacy{c})
			enrich(p, states)
			people = append(people, p)
			if c.CPF != "" {
				byCPF[c.CPF] = p
			}
		}
		addRole(p, Role{Office: OfficeStateDeputy, UF: uf, Status: StatusInOffice, Party: c.Party})
		matched[m.ID] = p
	}
	if enough {
		active := map[*Person]bool{}
		for _, p := range matched {
			active[p] = true
		}
		for p := range elected {
			if active[p] {
				continue
			}
			for i, r := range p.Roles {
				if r.Office == OfficeStateDeputy && r.UF == uf && r.Status == StatusInOffice {
					p.Roles[i].Status = StatusOnLeave
				}
			}
		}
	}
	for _, m := range members {
		p, ok := matched[m.ID]
		if !ok {
			continue
		}
		p.Assembly = house
		p.AddKey(house + ":" + strconv.FormatInt(m.ID, 10))
		p.AddSource(house)
		if p.Photo == "" {
			p.Photo = m.Photo
		}
		if p.Contact == nil && (m.Email != "" || m.Phone != "") {
			p.Contact = &Contact{Email: strPtr(m.Email), Phone: strPtr(m.Phone)}
		}
	}
	return people, matched
}
