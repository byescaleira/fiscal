package senado

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"
)

const (
	APIBase       = "https://legis.senado.leg.br/dadosabertos"
	ADMBase       = "https://adm.senado.gov.br/adm-dadosabertos/api/v1"
	SiteURL       = "https://legis.senado.leg.br/dadosabertos"
	ADMSite       = "https://adm.senado.gov.br/adm-dadosabertos"
	MatterURLBase = "https://www25.senado.leg.br/web/atividade/materias/-/materia/"
)

type Getter interface {
	JSON(ctx context.Context, rawURL string, v any) error
}

type API struct {
	Get     Getter
	Base    string
	ADMBase string
}

func (a API) base() string {
	if a.Base != "" {
		return a.Base
	}
	return APIBase
}

func (a API) adm() string {
	if a.ADMBase != "" {
		return a.ADMBase
	}
	return ADMBase
}

type many[T any] []T

func (m *many[T]) UnmarshalJSON(b []byte) error {
	b = bytes.TrimSpace(b)
	if len(b) == 0 || string(b) == "null" {
		*m = nil
		return nil
	}
	if b[0] == '[' {
		var arr []T
		if err := json.Unmarshal(b, &arr); err != nil {
			return err
		}
		*m = arr
		return nil
	}
	var one T
	if err := json.Unmarshal(b, &one); err != nil {
		return err
	}
	*m = []T{one}
	return nil
}

type Senator struct {
	Code          int64
	Name          string
	FullName      string
	Party         string
	UF            string
	Photo         string
	Email         string
	Phone         string
	Participation string
	MandateStart  string
	MandateEnd    string
	BirthDate     string
	BirthPlace    string
	BirthUF       string
	Address       string
}

type identJSON struct {
	CodigoParlamentar       string `json:"CodigoParlamentar"`
	NomeParlamentar         string `json:"NomeParlamentar"`
	NomeCompletoParlamentar string `json:"NomeCompletoParlamentar"`
	UrlFotoParlamentar      string `json:"UrlFotoParlamentar"`
	EmailParlamentar        string `json:"EmailParlamentar"`
	SiglaPartidoParlamentar string `json:"SiglaPartidoParlamentar"`
	UfParlamentar           string `json:"UfParlamentar"`
	Telefones               struct {
		Telefone many[struct {
			NumeroTelefone string `json:"NumeroTelefone"`
		}] `json:"Telefone"`
	} `json:"Telefones"`
}

type legJSON struct {
	DataInicio string `json:"DataInicio"`
	DataFim    string `json:"DataFim"`
}

type mandateJSON struct {
	CodigoMandato         string  `json:"CodigoMandato"`
	UfParlamentar         string  `json:"UfParlamentar"`
	Primeira              legJSON `json:"PrimeiraLegislaturaDoMandato"`
	Segunda               legJSON `json:"SegundaLegislaturaDoMandato"`
	DescricaoParticipacao string  `json:"DescricaoParticipacao"`
}

func (m mandateJSON) bounds() (string, string) {
	end := m.Segunda.DataFim
	if end == "" {
		end = m.Primeira.DataFim
	}
	return m.Primeira.DataInicio, end
}

func phone(i identJSON) string {
	if len(i.phones()) == 0 {
		return ""
	}
	return i.phones()[0]
}

func (i identJSON) phones() []string {
	var out []string
	for _, t := range i.Telefones.Telefone {
		if t.NumeroTelefone != "" {
			out = append(out, t.NumeroTelefone)
		}
	}
	return out
}

func FormatPhone(n string) string {
	d := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, n)
	if len(d) == 8 {
		return "(61) " + d[:4] + "-" + d[4:]
	}
	return n
}

func secure(u string) string {
	return strings.Replace(u, "http://", "https://", 1)
}

type listJSON struct {
	ListaParlamentarEmExercicio struct {
		Parlamentares struct {
			Parlamentar many[struct {
				IdentificacaoParlamentar identJSON   `json:"IdentificacaoParlamentar"`
				Mandato                  mandateJSON `json:"Mandato"`
			}] `json:"Parlamentar"`
		} `json:"Parlamentares"`
	} `json:"ListaParlamentarEmExercicio"`
}

func (l listJSON) senators() []Senator {
	var out []Senator
	for _, p := range l.ListaParlamentarEmExercicio.Parlamentares.Parlamentar {
		id := p.IdentificacaoParlamentar
		code, _ := strconv.ParseInt(id.CodigoParlamentar, 10, 64)
		start, end := p.Mandato.bounds()
		out = append(out, Senator{
			Code:          code,
			Name:          id.NomeParlamentar,
			FullName:      id.NomeCompletoParlamentar,
			Party:         id.SiglaPartidoParlamentar,
			UF:            id.UfParlamentar,
			Photo:         secure(id.UrlFotoParlamentar),
			Email:         id.EmailParlamentar,
			Phone:         FormatPhone(phone(id)),
			Participation: p.Mandato.DescricaoParticipacao,
			MandateStart:  start,
			MandateEnd:    end,
		})
	}
	return out
}

func (a API) Current(ctx context.Context) ([]Senator, error) {
	var body listJSON
	if err := a.Get.JSON(ctx, a.base()+"/senador/lista/atual.json", &body); err != nil {
		return nil, err
	}
	return body.senators(), nil
}

func ParseCurrent(data []byte) ([]Senator, error) {
	var body listJSON
	if err := json.Unmarshal(data, &body); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return body.senators(), nil
}

type detailJSON struct {
	DetalheParlamentar struct {
		Parlamentar struct {
			DadosBasicosParlamentar struct {
				DataNascimento      string `json:"DataNascimento"`
				Naturalidade        string `json:"Naturalidade"`
				UfNaturalidade      string `json:"UfNaturalidade"`
				EnderecoParlamentar string `json:"EnderecoParlamentar"`
			} `json:"DadosBasicosParlamentar"`
		} `json:"Parlamentar"`
	} `json:"DetalheParlamentar"`
}

type Detail struct {
	BirthDate  string
	BirthPlace string
	BirthUF    string
	Address    string
}

func (d detailJSON) detail() Detail {
	b := d.DetalheParlamentar.Parlamentar.DadosBasicosParlamentar
	return Detail{BirthDate: b.DataNascimento, BirthPlace: b.Naturalidade, BirthUF: b.UfNaturalidade, Address: strings.Join(strings.Fields(b.EnderecoParlamentar), " ")}
}

func (a API) Detail(ctx context.Context, code int64) (Detail, error) {
	var body detailJSON
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/senador/%d.json", a.base(), code), &body); err != nil {
		return Detail{}, err
	}
	return body.detail(), nil
}

func ParseDetail(data []byte) (Detail, error) {
	var body detailJSON
	if err := json.Unmarshal(data, &body); err != nil {
		return Detail{}, fmt.Errorf("senado: %w", err)
	}
	return body.detail(), nil
}

type Mandate struct {
	UF            string
	Start         string
	End           string
	Participation string
}

type mandatesJSON struct {
	MandatoParlamentar struct {
		Parlamentar struct {
			Mandatos struct {
				Mandato many[mandateJSON] `json:"Mandato"`
			} `json:"Mandatos"`
		} `json:"Parlamentar"`
	} `json:"MandatoParlamentar"`
}

func (m mandatesJSON) mandates() []Mandate {
	var out []Mandate
	for _, x := range m.MandatoParlamentar.Parlamentar.Mandatos.Mandato {
		s, e := x.bounds()
		out = append(out, Mandate{UF: x.UfParlamentar, Start: s, End: e, Participation: x.DescricaoParticipacao})
	}
	return out
}

func (a API) Mandates(ctx context.Context, code int64) ([]Mandate, error) {
	var body mandatesJSON
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/senador/%d/mandatos.json", a.base(), code), &body); err != nil {
		return nil, err
	}
	return body.mandates(), nil
}

func ParseMandates(data []byte) ([]Mandate, error) {
	var body mandatesJSON
	if err := json.Unmarshal(data, &body); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return body.mandates(), nil
}

type Committee struct {
	Acronym string
	Name    string
	Role    string
	Start   string
	End     string
}

type committeesJSON struct {
	MembroComissaoParlamentar struct {
		Parlamentar struct {
			MembroComissoes struct {
				Comissao many[struct {
					IdentificacaoComissao struct {
						SiglaComissao string `json:"SiglaComissao"`
						NomeComissao  string `json:"NomeComissao"`
					} `json:"IdentificacaoComissao"`
					DescricaoParticipacao string `json:"DescricaoParticipacao"`
					DataInicio            string `json:"DataInicio"`
					DataFim               string `json:"DataFim"`
				}] `json:"Comissao"`
			} `json:"MembroComissoes"`
		} `json:"Parlamentar"`
	} `json:"MembroComissaoParlamentar"`
}

func (c committeesJSON) committees() []Committee {
	var out []Committee
	for _, x := range c.MembroComissaoParlamentar.Parlamentar.MembroComissoes.Comissao {
		out = append(out, Committee{Acronym: x.IdentificacaoComissao.SiglaComissao, Name: x.IdentificacaoComissao.NomeComissao, Role: x.DescricaoParticipacao, Start: x.DataInicio, End: x.DataFim})
	}
	return out
}

func (a API) Committees(ctx context.Context, code int64) ([]Committee, error) {
	var body committeesJSON
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/senador/%d/comissoes.json?ativo=S", a.base(), code), &body); err != nil {
		return nil, err
	}
	return body.committees(), nil
}

func ParseCommittees(data []byte) ([]Committee, error) {
	var body committeesJSON
	if err := json.Unmarshal(data, &body); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return body.committees(), nil
}

type Speech struct {
	Code     string
	Date     string
	Kind     string
	Summary  string
	Keywords string
	URL      string
}

type speechesJSON struct {
	DiscursosParlamentar struct {
		Parlamentar struct {
			Pronunciamentos struct {
				Pronunciamento many[struct {
					CodigoPronunciamento string `json:"CodigoPronunciamento"`
					TipoUsoPalavra       struct {
						Descricao string `json:"Descricao"`
					} `json:"TipoUsoPalavra"`
					DataPronunciamento string `json:"DataPronunciamento"`
					TextoResumo        string `json:"TextoResumo"`
					Indexacao          string `json:"Indexacao"`
					UrlTexto           string `json:"UrlTexto"`
				}] `json:"Pronunciamento"`
			} `json:"Pronunciamentos"`
		} `json:"Parlamentar"`
	} `json:"DiscursosParlamentar"`
}

func (s speechesJSON) speeches() []Speech {
	var out []Speech
	for _, p := range s.DiscursosParlamentar.Parlamentar.Pronunciamentos.Pronunciamento {
		out = append(out, Speech{Code: p.CodigoPronunciamento, Date: p.DataPronunciamento, Kind: p.TipoUsoPalavra.Descricao, Summary: strings.TrimSpace(p.TextoResumo), Keywords: p.Indexacao, URL: p.UrlTexto})
	}
	return out
}

func (a API) Speeches(ctx context.Context, code int64, year int) ([]Speech, error) {
	var body speechesJSON
	u := fmt.Sprintf("%s/senador/%d/discursos.json?dataInicio=%d0101&dataFim=%d1231", a.base(), code, year, year)
	if err := a.Get.JSON(ctx, u, &body); err != nil {
		return nil, err
	}
	return body.speeches(), nil
}

func ParseSpeeches(data []byte) ([]Speech, error) {
	var body speechesJSON
	if err := json.Unmarshal(data, &body); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return body.speeches(), nil
}

type Process struct {
	ID             int64
	MatterCode     int64
	Identification string
	Kind           string
	Number         int
	Year           int
	Ementa         string
	DocumentType   string
	Presented      string
	Situation      string
	URL            string
}

type processJSON struct {
	ID               int64  `json:"id"`
	CodigoMateria    int64  `json:"codigoMateria"`
	Identificacao    string `json:"identificacao"`
	Ementa           string `json:"ementa"`
	TipoDocumento    string `json:"tipoDocumento"`
	DataApresentacao string `json:"dataApresentacao"`
	SituacaoAtual    string `json:"situacaoAtual"`
	URLDocumento     string `json:"urlDocumento"`
}

func SplitIdentification(s string) (string, int, int) {
	s = strings.TrimSpace(s)
	sp := strings.LastIndexByte(s, ' ')
	if sp < 0 {
		return s, 0, 0
	}
	kind := strings.TrimSpace(s[:sp])
	num := s[sp+1:]
	slash := strings.IndexByte(num, '/')
	if slash < 0 {
		return kind, 0, 0
	}
	n, _ := strconv.Atoi(num[:slash])
	y, _ := strconv.Atoi(num[slash+1:])
	return kind, n, y
}

func processes(rows []processJSON) []Process {
	out := make([]Process, 0, len(rows))
	for _, r := range rows {
		kind, n, y := SplitIdentification(r.Identificacao)
		u := r.URLDocumento
		if r.CodigoMateria != 0 {
			u = MatterURLBase + strconv.FormatInt(r.CodigoMateria, 10)
		}
		out = append(out, Process{ID: r.ID, MatterCode: r.CodigoMateria, Identification: r.Identificacao, Kind: kind, Number: n, Year: y, Ementa: strings.TrimSpace(r.Ementa), DocumentType: r.TipoDocumento, Presented: r.DataApresentacao, Situation: r.SituacaoAtual, URL: u})
	}
	return out
}

func (a API) Authored(ctx context.Context, code int64) ([]Process, error) {
	var rows []processJSON
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/processo?codigoParlamentarAutor=%d", a.base(), code), &rows); err != nil {
		return nil, err
	}
	return processes(rows), nil
}

func ParseProcesses(data []byte) ([]Process, error) {
	var rows []processJSON
	if err := json.Unmarshal(data, &rows); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return processes(rows), nil
}

type Ballot struct {
	Code  int64
	Name  string
	Party string
	UF    string
	Vote  string
}

type Vote struct {
	Code           int64
	SessionCode    int64
	Date           string
	Identification string
	Kind           string
	Number         int
	Year           int
	Description    string
	Ementa         string
	Result         string
	Secret         bool
	Yes            *int
	No             *int
	Abstention     *int
	MatterCode     int64
	Ballots        []Ballot
}

type voteJSON struct {
	CodigoSessaoVotacao int64  `json:"codigoSessaoVotacao"`
	CodigoSessao        int64  `json:"codigoSessao"`
	CodigoMateria       int64  `json:"codigoMateria"`
	DataSessao          string `json:"dataSessao"`
	Identificacao       string `json:"identificacao"`
	DescricaoVotacao    string `json:"descricaoVotacao"`
	Ementa              string `json:"ementa"`
	ResultadoVotacao    string `json:"resultadoVotacao"`
	VotacaoSecreta      string `json:"votacaoSecreta"`
	TotalVotosSim       *int   `json:"totalVotosSim"`
	TotalVotosNao       *int   `json:"totalVotosNao"`
	TotalVotosAbstencao *int   `json:"totalVotosAbstencao"`
	Votos               []struct {
		CodigoParlamentar       int64  `json:"codigoParlamentar"`
		NomeParlamentar         string `json:"nomeParlamentar"`
		SiglaPartidoParlamentar string `json:"siglaPartidoParlamentar"`
		SiglaUFParlamentar      string `json:"siglaUFParlamentar"`
		SiglaVotoParlamentar    string `json:"siglaVotoParlamentar"`
	} `json:"votos"`
}

func votes(rows []voteJSON) []Vote {
	out := make([]Vote, 0, len(rows))
	for _, r := range rows {
		kind, n, y := SplitIdentification(r.Identificacao)
		v := Vote{Code: r.CodigoSessaoVotacao, SessionCode: r.CodigoSessao, MatterCode: r.CodigoMateria, Date: r.DataSessao, Identification: r.Identificacao, Kind: kind, Number: n, Year: y, Description: strings.TrimSpace(r.DescricaoVotacao), Ementa: strings.TrimSpace(r.Ementa), Result: r.ResultadoVotacao, Secret: r.VotacaoSecreta == "S", Yes: r.TotalVotosSim, No: r.TotalVotosNao, Abstention: r.TotalVotosAbstencao}
		for _, b := range r.Votos {
			v.Ballots = append(v.Ballots, Ballot{Code: b.CodigoParlamentar, Name: b.NomeParlamentar, Party: b.SiglaPartidoParlamentar, UF: b.SiglaUFParlamentar, Vote: b.SiglaVotoParlamentar})
		}
		out = append(out, v)
	}
	return out
}

func (a API) Votes(ctx context.Context, from, to string) ([]Vote, error) {
	var rows []voteJSON
	q := url.Values{"dataInicio": {from}, "dataFim": {to}}
	if err := a.Get.JSON(ctx, a.base()+"/votacao?"+q.Encode(), &rows); err != nil {
		return nil, err
	}
	return votes(rows), nil
}

func ParseVotes(data []byte) ([]Vote, error) {
	var rows []voteJSON
	if err := json.Unmarshal(data, &rows); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return votes(rows), nil
}

var voteLabels = map[string]string{
	"Sim":                       "Sim",
	"Não":                       "Não",
	"Abstenção":                 "Abstenção",
	"Obstrução":                 "Obstrução",
	"Votou":                     "Votou",
	"P-NRV":                     "Presente sem voto",
	"Presidente (art. 51 RISF)": "Presidente",
	"AP":                        "Em atividade parlamentar",
	"LS":                        "Licença de saúde",
	"LP":                        "Licença particular",
	"NCom":                      "Não compareceu",
	"AUS":                       "Ausente",
	"MIS":                       "Em missão",
}

func VoteLabel(code string) string {
	if l, ok := voteLabels[code]; ok {
		return l
	}
	return code
}

func Present(code string) bool {
	switch code {
	case "Sim", "Não", "Abstenção", "Obstrução", "Votou", "P-NRV", "Presidente (art. 51 RISF)":
		return true
	}
	return false
}

type Expense struct {
	ID          int64
	SenatorCode int64
	Year        int
	Month       int
	Category    string
	Supplier    string
	SupplierID  string
	Document    string
	Date        string
	Cents       int64
}

type expenseJSON struct {
	ID               int64       `json:"id"`
	Ano              int         `json:"ano"`
	Mes              int         `json:"mes"`
	CodSenador       int64       `json:"codSenador"`
	TipoDespesa      string      `json:"tipoDespesa"`
	CpfCnpj          string      `json:"cpfCnpj"`
	Fornecedor       string      `json:"fornecedor"`
	Documento        string      `json:"documento"`
	Data             string      `json:"data"`
	ValorReembolsado json.Number `json:"valorReembolsado"`
}

func expenses(rows []expenseJSON) []Expense {
	out := make([]Expense, 0, len(rows))
	for _, r := range rows {
		cents, ok := numberCents(string(r.ValorReembolsado))
		if !ok || r.CodSenador == 0 {
			continue
		}
		out = append(out, Expense{ID: r.ID, SenatorCode: r.CodSenador, Year: r.Ano, Month: r.Mes, Category: r.TipoDespesa, Supplier: r.Fornecedor, SupplierID: r.CpfCnpj, Document: r.Documento, Date: r.Data, Cents: cents})
	}
	return out
}

func numberCents(s string) (int64, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, false
	}
	neg := strings.HasPrefix(s, "-")
	s = strings.TrimPrefix(s, "-")
	whole, frac, _ := strings.Cut(s, ".")
	w, err := strconv.ParseInt(whole, 10, 64)
	if err != nil {
		return 0, false
	}
	frac += "000"
	f, err := strconv.ParseInt(frac[:2], 10, 64)
	if err != nil {
		return 0, false
	}
	c := w*100 + f
	if frac[2] >= '5' {
		c++
	}
	if neg {
		c = -c
	}
	return c, true
}

func (a API) Expenses(ctx context.Context, year int) ([]Expense, error) {
	var rows []expenseJSON
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/senadores/despesas_ceaps/%d", a.adm(), year), &rows); err != nil {
		return nil, err
	}
	return expenses(rows), nil
}

func ParseExpenses(data []byte) ([]Expense, error) {
	var rows []expenseJSON
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	if err := dec.Decode(&rows); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return expenses(rows), nil
}

type AgendaMatter struct {
	Code           int64
	Identification string
	Ementa         string
	Stage          string
	Label          string
}

type AgendaSession struct {
	Code      int64
	Date      string
	Hour      string
	Type      string
	Situation string
	Matters   []AgendaMatter
}

type agendaJSON struct {
	AgendaPlenario struct {
		Sessoes struct {
			Sessao many[struct {
				CodigoSessao   string `json:"CodigoSessao"`
				Data           string `json:"Data"`
				Hora           string `json:"Hora"`
				TipoSessao     string `json:"TipoSessao"`
				SituacaoSessao string `json:"SituacaoSessao"`
				Casa           string `json:"Casa"`
				Materias       struct {
					Materia many[struct {
						CodigoMateria                 string `json:"CodigoMateria"`
						DescricaoIdentificacaoMateria string `json:"DescricaoIdentificacaoMateria"`
						Ementa                        string `json:"Ementa"`
						Apreciacao                    string `json:"Apreciacao"`
						Cabecalho                     string `json:"Cabecalho"`
					}] `json:"Materia"`
				} `json:"Materias"`
			}] `json:"Sessao"`
		} `json:"Sessoes"`
	} `json:"AgendaPlenario"`
}

func (a agendaJSON) sessions() []AgendaSession {
	var out []AgendaSession
	for _, s := range a.AgendaPlenario.Sessoes.Sessao {
		if s.Casa != "" && s.Casa != "SF" {
			continue
		}
		code, _ := strconv.ParseInt(s.CodigoSessao, 10, 64)
		sess := AgendaSession{Code: code, Date: s.Data, Hour: strings.TrimSpace(s.Hora), Type: strings.TrimSpace(s.TipoSessao), Situation: strings.TrimSpace(s.SituacaoSessao)}
		for _, m := range s.Materias.Materia {
			mc, _ := strconv.ParseInt(m.CodigoMateria, 10, 64)
			sess.Matters = append(sess.Matters, AgendaMatter{Code: mc, Identification: strings.TrimSpace(m.DescricaoIdentificacaoMateria), Ementa: strings.TrimSpace(m.Ementa), Stage: strings.TrimSpace(m.Apreciacao), Label: strings.Trim(strings.TrimSpace(m.Cabecalho), "()")})
		}
		out = append(out, sess)
	}
	return out
}

func (a API) Agenda(ctx context.Context, day string) ([]AgendaSession, error) {
	var body agendaJSON
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/plenario/agenda/dia/%s.json", a.base(), strings.ReplaceAll(day, "-", "")), &body); err != nil {
		return nil, err
	}
	return body.sessions(), nil
}

func ParseAgenda(data []byte) ([]AgendaSession, error) {
	var body agendaJSON
	if err := json.Unmarshal(data, &body); err != nil {
		return nil, fmt.Errorf("senado: %w", err)
	}
	return body.sessions(), nil
}
