package ingest

import (
	"fmt"
	"strings"
	"time"
)

type JobKind string

const (
	JobHot      JobKind = "hot"
	JobDerived  JobKind = "derived"
	JobSources  JobKind = "sources"
	JobRebuild  JobKind = "rebuild"
	JobExternal JobKind = "external"
)

type ProbeKind string

const (
	ProbeNone  ProbeKind = "none"
	ProbeFiles ProbeKind = "files"
	ProbeAPI   ProbeKind = "api"
	ProbeSelf  ProbeKind = "self"
)

type Window struct {
	Weekdays []time.Weekday
	From     int
	To       int
}

func (w Window) Contains(t time.Time) bool {
	day := false
	for _, d := range w.Weekdays {
		day = day || d == t.Weekday()
	}
	return day && t.Hour() >= w.From && t.Hour() < w.To
}

type Schedule struct {
	Every    time.Duration
	Off      time.Duration
	Window   *Window
	At       [2]int
	Weekday  *time.Weekday
	MonthDay int
}

type Job struct {
	Name     string
	Theme    string
	Kind     JobKind
	Sources  []string
	Schedule Schedule
	Probe    ProbeKind
	MaxAge   time.Duration
	Overlay  bool
	Reason   string
}

var (
	weekdays    = []time.Weekday{time.Monday, time.Tuesday, time.Wednesday, time.Thursday, time.Friday}
	sessionDays = &Window{Weekdays: weekdays, From: 9, To: 24}
	daytime     = &Window{Weekdays: []time.Weekday{time.Sunday, time.Monday, time.Tuesday, time.Wednesday, time.Thursday, time.Friday, time.Saturday}, From: 7, To: 24}
)

func weekday(d time.Weekday) *time.Weekday {
	return &d
}

const retryAfter = 30 * time.Minute

var ElectionDays = []string{"2026-10-04", "2026-10-25"}

var Catalog = []Job{
	{Name: "hot", Theme: "pauta e votações de hoje (Câmara e Senado)", Kind: JobHot, Sources: []string{"agenda"}, Schedule: Schedule{Every: 5 * time.Minute, Off: time.Hour, Window: sessionDays}, Probe: ProbeSelf, Reason: "o Plenário pauta e vota de segunda a sexta, das 9h à meia-noite; fora disso a pauta quase não muda, e uma checagem por hora basta"},
	{Name: "checagens", Theme: "checagens do Projeto Comprova", Kind: JobSources, Sources: []string{"comprova"}, Schedule: Schedule{Every: 45 * time.Minute, Window: daytime}, Probe: ProbeAPI, MaxAge: 24 * time.Hour, Overlay: true, Reason: "o Comprova publica poucas checagens por dia, em horário comercial; a sonda pede só a última publicação alterada"},
	{Name: "senado", Theme: "senadores, votos, propostas, discursos e CEAPS", Kind: JobSources, Sources: []string{"senado"}, Schedule: Schedule{At: [2]int{1, 10}}, Probe: ProbeNone, Reason: "a API do Senado não tem validadores; presença, cota e discursos mudam no máximo uma vez por dia"},
	{Name: "assembleias", Theme: "assembleias com SAPL (AC, AM, PB, PI e RO)", Kind: JobSources, Sources: []string{"assembleias"}, Schedule: Schedule{At: [2]int{2, 0}}, Probe: ProbeNone, Reason: "o SAPL não tem validadores e as matérias entram em dias úteis; uma leitura diária cobre"},
	{Name: "camara", Theme: "deputados, votos, presença, propostas, discursos e CEAP", Kind: JobSources, Sources: []string{"camara"}, Schedule: Schedule{At: [2]int{5, 0}}, Probe: ProbeNone, Reason: "a Câmara regera todos os arquivos anuais entre 0h e 4h (o Last-Modified muda todo dia mesmo sem conteúdo novo), então vale uma leitura diária depois disso"},
	{Name: "anp", Theme: "preços médios de combustíveis (ANP)", Kind: JobSources, Sources: []string{"anp"}, Schedule: Schedule{At: [2]int{3, 20}, Weekday: weekday(time.Monday)}, Probe: ProbeFiles, MaxAge: 35 * 24 * time.Hour, Overlay: true, Reason: "a série histórica da ANP é mensal e sai sem data fixa; uma sonda semanal das planilhas basta"},
	{Name: "sidra", Theme: "IPCA e rendimento (IBGE, SIDRA)", Kind: JobSources, Sources: []string{"sidra"}, Schedule: Schedule{At: [2]int{3, 30}}, Probe: ProbeAPI, MaxAge: 35 * 24 * time.Hour, Overlay: true, Reason: "o IPCA sai uma vez por mês, por volta do dia 10, em data do calendário do IBGE; a sonda diária lê só o último período"},
	{Name: "receita", Theme: "arrecadação federal por estado", Kind: JobSources, Sources: []string{"receita"}, Schedule: Schedule{At: [2]int{3, 40}, Weekday: weekday(time.Monday)}, Probe: ProbeFiles, MaxAge: 40 * 24 * time.Hour, Overlay: true, Reason: "a Receita publica a arrecadação uma vez por mês, sem dia fixo; a sonda semanal compara o arquivo"},
	{Name: "tse", Theme: "candidaturas, bens, votos e contas das eleições gerais", Kind: JobSources, Sources: []string{"tse"}, Schedule: Schedule{At: [2]int{0, 20}, Weekday: weekday(time.Sunday)}, Probe: ProbeFiles, MaxAge: 90 * 24 * time.Hour, Reason: "os ZIPs do TSE só mudam quando o tribunal republica; a sonda semanal faz HEAD e compara ETag e tamanho"},
	{Name: "cidades", Theme: "municípios do IBGE e prefeitos, vices e vereadores", Kind: JobSources, Sources: []string{"ibge", "cidades"}, Schedule: Schedule{At: [2]int{0, 20}, Weekday: weekday(time.Saturday)}, Probe: ProbeFiles, MaxAge: 90 * 24 * time.Hour, Overlay: true, Reason: "a lista de municípios e os eleitos de 2024 quase nunca mudam; só reconstrói os 75 mil arquivos de cidades quando o TSE ou o IBGE republicam"},
	{Name: "historia", Theme: "Memória: eleições anteriores e indicadores históricos", Kind: JobSources, Sources: []string{"historia"}, Schedule: Schedule{At: [2]int{3, 50}, MonthDay: 1}, Probe: ProbeFiles, MaxAge: 180 * 24 * time.Hour, Overlay: true, Reason: "resultados de eleições passadas são fechados; o conteúdo curado muda com o deploy e os ZIPs só quando o TSE corrige"},
	{Name: "repercussao", Theme: "contagens do GDELT e da Wikipédia", Kind: JobSources, Sources: []string{"repercussao"}, Schedule: Schedule{Every: 3 * time.Hour}, Probe: ProbeNone, Overlay: true, Reason: "as contagens são janelas de 30 dias e valem 72 h; o GDELT recusa rajadas, então cada leitura mede no máximo 15 min, com espera entre recusas, e oito leituras por dia renovam todas as contagens"},
	{Name: "memoria", Theme: "reconstrução completa e verificação de consistência", Kind: JobRebuild, Schedule: Schedule{At: [2]int{0, 20}, Weekday: weekday(time.Wednesday)}, Probe: ProbeNone, Reason: "uma vez por semana o site inteiro é refeito a partir do banco e comparado com o incremental; divergência vira alerta"},
	{Name: "destaques", Theme: "destaques, peso, fatos e listas de votos por pessoa", Kind: JobDerived, Schedule: Schedule{Every: 20 * time.Minute}, Probe: ProbeNone, Reason: "só quando a atualização quente achou votação nova; recalcular perfis, destaques e peso a cada 20 min acompanha a sessão sem refazer tudo a cada 5 min"},
	{Name: "apuracao", Theme: "apuração ao vivo (poller do fiscal-api)", Kind: JobExternal, Schedule: Schedule{Every: 20 * time.Second}, Probe: ProbeNone, Reason: "só em dia de eleição (ElectionDays); o fiscal-api lê o TSE a cada 20 s e o fiscal-pages.timer publica a cada minuto"},
}

func JobByName(name string) (Job, bool) {
	for _, j := range Catalog {
		if j.Name == name {
			return j, true
		}
	}
	return Job{}, false
}

func JobNames() []string {
	var out []string
	for _, j := range Catalog {
		if j.Kind != JobExternal {
			out = append(out, j.Name)
		}
	}
	return out
}

func IsElectionDay(local time.Time) bool {
	day := local.Format("2006-01-02")
	for _, d := range ElectionDays {
		if d == day {
			return true
		}
	}
	return false
}

func (s Schedule) anchor(local time.Time) time.Time {
	t := time.Date(local.Year(), local.Month(), local.Day(), s.At[0], s.At[1], 0, 0, local.Location())
	switch {
	case s.MonthDay > 0:
		t = time.Date(local.Year(), local.Month(), s.MonthDay, s.At[0], s.At[1], 0, 0, local.Location())
		if t.After(local) {
			t = t.AddDate(0, -1, 0)
		}
	case s.Weekday != nil:
		back := (int(local.Weekday()) - int(*s.Weekday) + 7) % 7
		t = t.AddDate(0, 0, -back)
		if t.After(local) {
			t = t.AddDate(0, 0, -7)
		}
	default:
		if t.After(local) {
			t = t.AddDate(0, 0, -1)
		}
	}
	return t
}

const tickSlack = time.Minute

func (j Job) Due(now time.Time, loc *time.Location, st JobState) (bool, string) {
	local := now.In(loc)
	switch j.Kind {
	case JobExternal:
		return false, "roda fora do fiscal-ingest"
	case JobDerived:
		if !st.Pending {
			return false, "sem votação nova desde a última reconstrução"
		}
		if !st.LastAttempt.IsZero() && now.Sub(st.LastAttempt) < j.Schedule.Every-tickSlack {
			return false, fmt.Sprintf("votação nova na fila; próxima reconstrução em %s", (j.Schedule.Every - now.Sub(st.LastAttempt)).Round(time.Minute))
		}
		return true, "votação nova na fila"
	}
	s := j.Schedule
	if s.Every > 0 {
		step := s.Every
		if s.Window != nil && !s.Window.Contains(local) {
			step = s.Off
			if step == 0 {
				return false, "fora da janela"
			}
		}
		if st.LastAttempt.IsZero() || now.Sub(st.LastAttempt) >= step-tickSlack {
			return true, "intervalo de " + step.String()
		}
		return false, "última execução há " + now.Sub(st.LastAttempt).Round(time.Second).String()
	}
	anchor := s.anchor(local)
	if !st.LastOK.Before(anchor) {
		return false, "já rodou desde " + anchor.Format("02/01 15:04")
	}
	if !st.LastAttempt.Before(anchor) && now.Sub(st.LastAttempt) < retryAfter {
		return false, "falhou há pouco; tenta de novo em " + (retryAfter - now.Sub(st.LastAttempt)).Round(time.Minute).String()
	}
	return true, "horário de " + anchor.Format("02/01 15:04")
}

func (j Job) Cadence() string {
	s := j.Schedule
	switch j.Kind {
	case JobExternal:
		return "a cada " + s.Every.String() + " em dia de eleição"
	case JobDerived:
		return "a cada " + s.Every.String() + " quando há votação nova"
	}
	if s.Every > 0 {
		out := "a cada " + s.Every.String()
		if s.Window != nil {
			out += fmt.Sprintf(" das %02dh às %02dh (%s)", s.Window.From, s.Window.To, dayNames(s.Window.Weekdays))
			if s.Off > 0 {
				out += ", senão a cada " + s.Off.String()
			}
		}
		return out
	}
	at := fmt.Sprintf("%02d:%02d", s.At[0], s.At[1])
	switch {
	case s.MonthDay > 0:
		return fmt.Sprintf("todo dia %d às %s", s.MonthDay, at)
	case s.Weekday != nil:
		return dayNames([]time.Weekday{*s.Weekday}) + " às " + at
	}
	return "todo dia às " + at
}

func dayNames(days []time.Weekday) string {
	names := []string{"dom", "seg", "ter", "qua", "qui", "sex", "sáb"}
	if len(days) == 7 {
		return "todos os dias"
	}
	if len(days) == 5 && days[0] == time.Monday && days[4] == time.Friday {
		return "seg–sex"
	}
	var out []string
	for _, d := range days {
		out = append(out, names[d])
	}
	return strings.Join(out, ", ")
}
