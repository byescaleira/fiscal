package receita

import (
	"errors"
	"io"
	"sort"
	"strconv"
	"strings"

	"liveresults/internal/sources/table"
)

const (
	RevenueURL = "https://www.gov.br/receitafederal/dados/arrecadacao-estado.csv"
	SiteURL    = "https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/dados-abertos"
)

type Year struct {
	Year   int
	Months map[string]bool
	ByUF   map[string]int64
}

func (y Year) TotalCents() int64 {
	var t int64
	for _, c := range y.ByUF {
		t += c
	}
	return t
}

type Revenue struct {
	Years map[int]*Year
}

func Parse(r io.Reader) (Revenue, error) {
	t, err := table.NewReader(r, table.Latin1, ';')
	if err != nil {
		return Revenue{}, err
	}
	if err := t.Require("Ano", "Mês", "UF"); err != nil {
		return Revenue{}, err
	}
	header := t.Header()
	children := map[int][]int{}
	var values []int
	for i := range header {
		if i < 3 {
			continue
		}
		values = append(values, i)
	}
	for _, i := range values {
		parent := strings.TrimSpace(header[i])
		for _, j := range values {
			if j != i && strings.HasPrefix(strings.TrimSpace(header[j]), parent+" - ") {
				children[i] = append(children[i], j)
			}
		}
	}
	out := Revenue{Years: map[int]*Year{}}
	err = t.Each(func(row table.Row) error {
		year, err := strconv.Atoi(row.Raw("Ano"))
		if err != nil {
			return nil
		}
		uf := strings.ToUpper(row.Raw("UF"))
		if len(uf) != 2 {
			return nil
		}
		var sum int64
		for _, i := range values {
			if kids := children[i]; len(kids) > 0 {
				filled := false
				for _, k := range kids {
					if row.At(k) != "" {
						filled = true
						break
					}
				}
				if filled {
					continue
				}
			}
			if c, ok := table.ParseCents(row.At(i)); ok {
				sum += c
			}
		}
		y := out.Years[year]
		if y == nil {
			y = &Year{Year: year, Months: map[string]bool{}, ByUF: map[string]int64{}}
			out.Years[year] = y
		}
		y.Months[strings.ToLower(row.Raw("Mês"))] = true
		y.ByUF[uf] += sum
		return nil
	})
	if err != nil {
		return Revenue{}, err
	}
	if len(out.Years) == 0 {
		return Revenue{}, errors.New("receita: no rows")
	}
	return out, nil
}

func (r Revenue) LatestComplete() (*Year, bool) {
	var years []int
	for y := range r.Years {
		years = append(years, y)
	}
	sort.Sort(sort.Reverse(sort.IntSlice(years)))
	for _, y := range years {
		if len(r.Years[y].Months) == 12 {
			return r.Years[y], true
		}
	}
	return nil, false
}
