package camara

import (
	"context"
	"fmt"
	"net/url"
	"strconv"
)

type Getter interface {
	JSON(ctx context.Context, rawURL string, v any) error
}

type API struct {
	Get  Getter
	Base string
}

const pageSize = 100
const maxPages = 200

func (a API) base() string {
	if a.Base != "" {
		return a.Base
	}
	return APIBase
}

type deputyJSON struct {
	ID            int64  `json:"id"`
	Nome          string `json:"nome"`
	SiglaPartido  string `json:"siglaPartido"`
	SiglaUf       string `json:"siglaUf"`
	IDLegislatura int    `json:"idLegislatura"`
	URLFoto       string `json:"urlFoto"`
	Email         string `json:"email"`
}

func (d deputyJSON) deputy() Deputy {
	return Deputy{ID: d.ID, Name: d.Nome, Party: d.SiglaPartido, UF: d.SiglaUf, Photo: d.URLFoto, Email: d.Email, Legislature: d.IDLegislatura}
}

func pages[T any](ctx context.Context, a API, path string, q url.Values) ([]T, error) {
	var out []T
	for page := 1; page <= maxPages; page++ {
		q.Set("pagina", strconv.Itoa(page))
		q.Set("itens", strconv.Itoa(pageSize))
		var body struct {
			Dados []T `json:"dados"`
		}
		if err := a.Get.JSON(ctx, a.base()+path+"?"+q.Encode(), &body); err != nil {
			return nil, err
		}
		out = append(out, body.Dados...)
		if len(body.Dados) < pageSize {
			return out, nil
		}
	}
	return nil, fmt.Errorf("camara: %s has more than %d pages", path, maxPages)
}

func (a API) Deputies(ctx context.Context) ([]Deputy, error) {
	rows, err := pages[deputyJSON](ctx, a, "/deputados", url.Values{"ordem": {"ASC"}, "ordenarPor": {"nome"}})
	if err != nil {
		return nil, err
	}
	out := make([]Deputy, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.deputy())
	}
	return out, nil
}

func ParseDeputies(data []byte) ([]Deputy, error) {
	var body struct {
		Dados []deputyJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return nil, err
	}
	out := make([]Deputy, 0, len(body.Dados))
	for _, r := range body.Dados {
		out = append(out, r.deputy())
	}
	return out, nil
}

type detailJSON struct {
	Dados struct {
		ID           int64  `json:"id"`
		NomeCivil    string `json:"nomeCivil"`
		CPF          string `json:"cpf"`
		DataNasc     string `json:"dataNascimento"`
		UfNasc       string `json:"ufNascimento"`
		MunNasc      string `json:"municipioNascimento"`
		Escolaridade string `json:"escolaridade"`
		UltimoStatus struct {
			deputyJSON
			NomeEleitoral     string `json:"nomeEleitoral"`
			Situacao          string `json:"situacao"`
			CondicaoEleitoral string `json:"condicaoEleitoral"`
			Gabinete          struct {
				Predio   string `json:"predio"`
				Sala     string `json:"sala"`
				Telefone string `json:"telefone"`
				Email    string `json:"email"`
			} `json:"gabinete"`
		} `json:"ultimoStatus"`
	} `json:"dados"`
}

func (d detailJSON) detail() Detail {
	s := d.Dados.UltimoStatus
	dep := s.deputyJSON.deputy()
	if dep.ID == 0 {
		dep.ID = d.Dados.ID
	}
	return Detail{
		Deputy:        dep,
		CivilName:     d.Dados.NomeCivil,
		ElectoralName: s.NomeEleitoral,
		CPF:           d.Dados.CPF,
		BirthDate:     d.Dados.DataNasc,
		BirthCity:     d.Dados.MunNasc,
		BirthUF:       d.Dados.UfNasc,
		Education:     d.Dados.Escolaridade,
		Situation:     s.Situacao,
		Condition:     s.CondicaoEleitoral,
		Building:      s.Gabinete.Predio,
		Room:          s.Gabinete.Sala,
		Phone:         s.Gabinete.Telefone,
		OfficeEmail:   s.Gabinete.Email,
	}
}

func (a API) Deputy(ctx context.Context, id int64) (Detail, error) {
	var body detailJSON
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/deputados/%d", a.base(), id), &body); err != nil {
		return Detail{}, err
	}
	return body.detail(), nil
}

func ParseDetail(data []byte) (Detail, error) {
	var body detailJSON
	if err := decode(data, &body); err != nil {
		return Detail{}, err
	}
	return body.detail(), nil
}

type statusJSON struct {
	DataHora          string `json:"dataHora"`
	Situacao          string `json:"situacao"`
	CondicaoEleitoral string `json:"condicaoEleitoral"`
	DescricaoStatus   string `json:"descricaoStatus"`
	SiglaPartido      string `json:"siglaPartido"`
	IDLegislatura     int    `json:"idLegislatura"`
}

func (s statusJSON) status() Status {
	return Status{Time: s.DataHora, Situation: s.Situacao, Condition: s.CondicaoEleitoral, Description: s.DescricaoStatus, Party: s.SiglaPartido, Legislature: s.IDLegislatura}
}

func (a API) History(ctx context.Context, id int64) ([]Status, error) {
	var body struct {
		Dados []statusJSON `json:"dados"`
	}
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/deputados/%d/historico", a.base(), id), &body); err != nil {
		return nil, err
	}
	out := make([]Status, 0, len(body.Dados))
	for _, s := range body.Dados {
		out = append(out, s.status())
	}
	return out, nil
}

func ParseHistory(data []byte) ([]Status, error) {
	var body struct {
		Dados []statusJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return nil, err
	}
	out := make([]Status, 0, len(body.Dados))
	for _, s := range body.Dados {
		out = append(out, s.status())
	}
	return out, nil
}

type speechJSON struct {
	DataHoraInicio string `json:"dataHoraInicio"`
	TipoDiscurso   string `json:"tipoDiscurso"`
	Sumario        string `json:"sumario"`
	Keywords       string `json:"keywords"`
	URLTexto       string `json:"urlTexto"`
	URLVideo       string `json:"urlVideo"`
	URLAudio       string `json:"urlAudio"`
}

func (s speechJSON) speech() Speech {
	u := s.URLTexto
	if u == "" {
		u = s.URLVideo
	}
	if u == "" {
		u = s.URLAudio
	}
	return Speech{Start: s.DataHoraInicio, Kind: s.TipoDiscurso, Summary: CleanText(s.Sumario), Keywords: s.Keywords, URL: u}
}

func (a API) Speeches(ctx context.Context, id int64, from, to string) ([]Speech, error) {
	rows, err := pages[speechJSON](ctx, a, fmt.Sprintf("/deputados/%d/discursos", id), url.Values{"dataInicio": {from}, "dataFim": {to}, "ordem": {"ASC"}, "ordenarPor": {"dataHoraInicio"}})
	if err != nil {
		return nil, err
	}
	out := make([]Speech, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.speech())
	}
	return out, nil
}

func ParseSpeeches(data []byte) ([]Speech, error) {
	var body struct {
		Dados []speechJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return nil, err
	}
	out := make([]Speech, 0, len(body.Dados))
	for _, r := range body.Dados {
		out = append(out, r.speech())
	}
	return out, nil
}

type eventJSON struct {
	ID             int64  `json:"id"`
	DataHoraInicio string `json:"dataHoraInicio"`
	DataHoraFim    string `json:"dataHoraFim"`
	Situacao       string `json:"situacao"`
	DescricaoTipo  string `json:"descricaoTipo"`
	Descricao      string `json:"descricao"`
	URLRegistro    string `json:"urlRegistro"`
}

func (e eventJSON) event() Event {
	return Event{ID: e.ID, Start: e.DataHoraInicio, End: e.DataHoraFim, Situation: e.Situacao, Type: e.DescricaoTipo, Description: CleanText(e.Descricao), URL: e.URLRegistro}
}

func (a API) PlenaryEvents(ctx context.Context, from, to string) ([]Event, error) {
	rows, err := pages[eventJSON](ctx, a, "/eventos", url.Values{"idOrgao": {strconv.Itoa(PlenaryID)}, "dataInicio": {from}, "dataFim": {to}, "ordem": {"ASC"}, "ordenarPor": {"dataHoraInicio"}})
	if err != nil {
		return nil, err
	}
	out := make([]Event, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.event())
	}
	return out, nil
}

func ParseEvents(data []byte) ([]Event, error) {
	var body struct {
		Dados []eventJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return nil, err
	}
	out := make([]Event, 0, len(body.Dados))
	for _, r := range body.Dados {
		out = append(out, r.event())
	}
	return out, nil
}

type flexInt int

func (f *flexInt) UnmarshalJSON(b []byte) error {
	s := string(b)
	if s == "null" {
		*f = 0
		return nil
	}
	if len(s) >= 2 && s[0] == '"' {
		s = s[1 : len(s)-1]
	}
	n, _ := strconv.Atoi(s)
	*f = flexInt(n)
	return nil
}

type propRefJSON struct {
	ID        int64   `json:"id"`
	SiglaTipo string  `json:"siglaTipo"`
	Numero    flexInt `json:"numero"`
	Ano       flexInt `json:"ano"`
	Ementa    string  `json:"ementa"`
}

type agendaJSON struct {
	Ordem       int          `json:"ordem"`
	Topico      string       `json:"topico"`
	Regime      string       `json:"regime"`
	Titulo      string       `json:"titulo"`
	Proposicao  propRefJSON  `json:"proposicao_"`
	Relacionada *propRefJSON `json:"proposicaoRelacionada_"`
}

func (j agendaJSON) item() AgendaItem {
	p := j.Proposicao
	if j.Relacionada != nil && j.Relacionada.ID != 0 {
		p = *j.Relacionada
	}
	return AgendaItem{Order: j.Ordem, Topic: j.Topico, Regime: j.Regime, Title: j.Titulo, PropositionID: p.ID, Kind: p.SiglaTipo, Number: int(p.Numero), Year: int(p.Ano), Ementa: CleanText(p.Ementa)}
}

func (a API) Agenda(ctx context.Context, eventID int64) ([]AgendaItem, error) {
	var body struct {
		Dados []agendaJSON `json:"dados"`
	}
	if err := a.Get.JSON(ctx, fmt.Sprintf("%s/eventos/%d/pauta", a.base(), eventID), &body); err != nil {
		return nil, err
	}
	out := make([]AgendaItem, 0, len(body.Dados))
	for _, r := range body.Dados {
		out = append(out, r.item())
	}
	return out, nil
}

func ParseAgenda(data []byte) ([]AgendaItem, error) {
	var body struct {
		Dados []agendaJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return nil, err
	}
	out := make([]AgendaItem, 0, len(body.Dados))
	for _, r := range body.Dados {
		out = append(out, r.item())
	}
	return out, nil
}

type voteJSON struct {
	ID                  string        `json:"id"`
	Data                string        `json:"data"`
	DataHoraRegistro    string        `json:"dataHoraRegistro"`
	SiglaOrgao          string        `json:"siglaOrgao"`
	IDOrgao             int64         `json:"idOrgao"`
	IDEvento            int64         `json:"idEvento"`
	URIEvento           string        `json:"uriEvento"`
	Descricao           string        `json:"descricao"`
	Aprovacao           *int          `json:"aprovacao"`
	ProposicoesAfetadas []propRefJSON `json:"proposicoesAfetadas"`
}

func (v voteJSON) vote() Vote {
	out := Vote{ID: v.ID, Date: v.Data, Registered: v.DataHoraRegistro, Organ: v.SiglaOrgao, OrganID: v.IDOrgao, EventID: v.IDEvento, Description: CleanText(v.Descricao)}
	if out.EventID == 0 && v.URIEvento != "" {
		out.EventID = idFromURI(v.URIEvento)
	}
	if out.OrganID == 0 && out.Organ == "PLEN" {
		out.OrganID = PlenaryID
	}
	if v.Aprovacao != nil {
		b := *v.Aprovacao == 1
		out.Approved = &b
	}
	return out
}

func (a API) PlenaryVotes(ctx context.Context, from, to string) ([]Vote, error) {
	rows, err := pages[voteJSON](ctx, a, "/votacoes", url.Values{"idOrgao": {strconv.Itoa(PlenaryID)}, "dataInicio": {from}, "dataFim": {to}, "ordem": {"DESC"}, "ordenarPor": {"dataHoraRegistro"}})
	if err != nil {
		return nil, err
	}
	out := make([]Vote, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.vote())
	}
	return out, nil
}

func (a API) VoteDetail(ctx context.Context, id string) (Vote, []VoteProposition, error) {
	var body struct {
		Dados voteJSON `json:"dados"`
	}
	if err := a.Get.JSON(ctx, a.base()+"/votacoes/"+url.PathEscape(id), &body); err != nil {
		return Vote{}, nil, err
	}
	return splitVote(body.Dados)
}

func ParseVoteDetail(data []byte) (Vote, []VoteProposition, error) {
	var body struct {
		Dados voteJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return Vote{}, nil, err
	}
	return splitVote(body.Dados)
}

func splitVote(v voteJSON) (Vote, []VoteProposition, error) {
	var props []VoteProposition
	for _, p := range v.ProposicoesAfetadas {
		props = append(props, VoteProposition{VoteID: v.ID, PropositionID: p.ID, Kind: p.SiglaTipo, Number: int(p.Numero), Year: int(p.Ano), Ementa: CleanText(p.Ementa), Title: fmt.Sprintf("%s %d/%d", p.SiglaTipo, p.Numero, p.Ano)})
	}
	return v.vote(), props, nil
}

type ballotJSON struct {
	TipoVoto string     `json:"tipoVoto"`
	Deputado deputyJSON `json:"deputado_"`
}

func (a API) Ballots(ctx context.Context, id string) ([]Ballot, error) {
	var body struct {
		Dados []ballotJSON `json:"dados"`
	}
	if err := a.Get.JSON(ctx, a.base()+"/votacoes/"+url.PathEscape(id)+"/votos", &body); err != nil {
		return nil, err
	}
	return ballots(id, body.Dados), nil
}

func ParseBallots(id string, data []byte) ([]Ballot, error) {
	var body struct {
		Dados []ballotJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return nil, err
	}
	return ballots(id, body.Dados), nil
}

func ballots(id string, rows []ballotJSON) []Ballot {
	out := make([]Ballot, 0, len(rows))
	for _, r := range rows {
		out = append(out, Ballot{VoteID: id, DeputyID: r.Deputado.ID, Name: r.Deputado.Nome, Party: r.Deputado.SiglaPartido, UF: r.Deputado.SiglaUf, Vote: r.TipoVoto})
	}
	return out
}

type guidanceJSON struct {
	OrientacaoVoto    string `json:"orientacaoVoto"`
	SiglaPartidoBloco string `json:"siglaPartidoBloco"`
}

func (a API) Guidance(ctx context.Context, id string) ([]Guidance, error) {
	var body struct {
		Dados []guidanceJSON `json:"dados"`
	}
	if err := a.Get.JSON(ctx, a.base()+"/votacoes/"+url.PathEscape(id)+"/orientacoes", &body); err != nil {
		return nil, err
	}
	return guidance(id, body.Dados), nil
}

func ParseGuidance(id string, data []byte) ([]Guidance, error) {
	var body struct {
		Dados []guidanceJSON `json:"dados"`
	}
	if err := decode(data, &body); err != nil {
		return nil, err
	}
	return guidance(id, body.Dados), nil
}

func guidance(id string, rows []guidanceJSON) []Guidance {
	var out []Guidance
	for _, r := range rows {
		if r.OrientacaoVoto == "" {
			continue
		}
		out = append(out, Guidance{VoteID: id, Bloc: r.SiglaPartidoBloco, Guidance: r.OrientacaoVoto})
	}
	return out
}
