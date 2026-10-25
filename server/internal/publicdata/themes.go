package publicdata

import "strings"

type Theme struct {
	Key   string
	Stems []string
}

var Themes = []Theme{
	{"saude", []string{
		"saude", "hospita", "medico", "medica", "medicos!", "medicas!", "medicament", "medicina", "vacin", "enferm", "doenc", "sus!", "ubs!", "upa!", "farmac", "cancer", "oncolog",
		"sanitari", "epidem", "pandem", "obesi", "diabet", "dengue", "odontolog", "psiqui", "transplant", "cirurg",
		"leito", "leitos!", "ambulanc", "terapeut", "anvisa!", "fisioterap", "nutricion", "sangue", "hemoterap", "hemofil", "covid",
	}},
	{"educacao", []string{
		"educa", "escola", "escolar", "ensino", "professor", "aluno", "alunos!", "estudant", "universi", "faculdad", "creche",
		"aprendiz", "alfabetiz", "pedagog", "enem!", "fies!", "prouni!", "merenda", "bolsa de estudo", "magisterio",
		"didatic", "curricul", "pos graduacao", "mestrado", "doutorado",
	}},
	{"seguranca", []string{
		"seguranca publica", "polici", "crime", "crimes!", "crimin", "penal", "penais!", "pena!", "penas!", "prisao",
		"prisoes!", "prisional", "presidi", "carcer", "violencia", "homicid", "arma!", "armas!", "armament", "trafico",
		"droga", "entorpecent", "furto", "roubo", "estupro", "bombeir", "guarda municipal", "delito",
		"delegad", "milicia", "feminicid", "facc", "organizacao criminosa", "sistema prisional", "vigilant",
	}},
	{"economia", []string{
		"econom", "emprego", "desempreg", "trabalhador", "trabalhist", "salari", "empresa", "empresas!", "empresari",
		"microempre", "mei!", "industri", "comerci", "exporta", "importacao", "importacoes!", "importador", "credito", "financ", "banco", "bancos!",
		"bancari", "juros", "inflac", "investiment", "mercado", "concorrenc", "cooperativ", "startup", "cambi",
		"pib!", "consolidacao das leis do trabalho", "clt!", "jornada de trabalho", "escala 6x1",
	}},
	{"impostos", []string{
		"tribut", "impost", "fiscal!", "fiscais!", "arrecad", "icms!", "ipi!", "iss!", "ipva!", "iptu!", "irpf!",
		"imposto de renda", "contribuicao social", "isencao", "isent", "receita federal", "simples nacional",
		"orcament", "gasto publico", "gastos publicos", "despesa publica", "despesas publicas", "divida publica",
		"responsabilidade fiscal", "teto de gastos", "arcabouco fiscal", "taxa!", "taxas!",
	}},
	{"ambiente", []string{
		"ambient", "florest", "desmat", "clima", "climat", "polui", "reciclag", "residuos", "agua!", "aguas!",
		"hidric", "fauna", "flora", "animais!", "animal!", "biodivers", "sustentab", "carbono", "renovave", "solar!",
		"eolic", "queimad", "incendios florestais", "amazon", "pantanal", "cerrado", "caatinga", "mata atlantica",
		"mineracao", "garimp", "agrotox", "conservacao", "ibama!", "icmbio!", "maus tratos",
	}},
	{"cidade", []string{
		"urban", "cidade", "cidades!", "moradia", "habitac", "minha casa", "saneament", "esgoto", "iluminacao publica",
		"paviment", "loteament", "condomini", "aluguel", "locacao", "plano diretor", "favela", "regularizacao fundiaria urbana",
		"defesa civil", "enchent", "desastre", "calamidade", "imoveis urbanos",
	}},
	{"transporte", []string{
		"transport", "transito!", "rodovi", "ferrovi", "aeropor", "aviacao", "aereo", "aerea", "porto!", "portos!",
		"portuari", "onibus", "metro!", "metrovi", "veiculo", "motorist", "habilitacao", "cnh!", "estrada", "pedagio",
		"mobilidade", "bicicl", "ciclovi", "taxi", "frete", "caminhon", "hidrovi", "brt!",
	}},
	{"social", []string{
		"assistencia social", "pobreza", "fome!", "bolsa familia", "prestacao continuada", "bpc!", "vulnerab", "idoso",
		"idosa", "pessoa idosa", "aposent", "previdenc", "pensao", "pensoes!", "inss!", "renda basica", "programa social",
		"programas sociais", "cadastro unico", "cadunico", "crianca", "criancas!", "adolescent", "infancia", "infantil",
		"juventude", "jovens!", "familia", "familias!", "seguro desemprego", "seguro defeso", "seguranca alimentar",
		"situacao de rua",
	}},
	{"mulheres", []string{
		"mulher", "mulheres!", "feminin", "feminicid", "genero!", "igualdade de genero", "violencia de genero", "gestant", "matern", "violencia domestica",
		"maria da penha", "igualdade salarial", "mae!", "maes!", "lactant", "gravid", "parto", "misogin",
	}},
	{"campo", []string{
		"agro", "agricul", "rural", "rurais!", "pecuar", "produtor", "produtores!", "safra", "terra!", "terras!",
		"fundiari", "reforma agraria", "assentament", "irrigac", "pesca", "pescador", "aquicult", "leite", "cafe!",
		"soja", "gado", "bovin", "frigorif", "sement", "fertiliz", "embrapa", "agrotox", "defensivos agricolas",
	}},
	{"cultura", []string{
		"cultur", "arte!", "artes!", "artist", "musica", "musical", "musico", "cinema", "audiovisual", "teatro",
		"patrimonio historico", "patrimonio cultural", "museu", "bibliotec", "livro", "livros!", "leitura", "esporte",
		"esportiv", "desport", "futebol", "olimpi", "paralimpi", "turism", "carnaval", "folclor", "capoeira", "artesan",
	}},
	{"direitos", []string{
		"direitos humanos", "igualdade", "discrimina", "racis", "racial", "raciais!", "negro", "negra", "negros!",
		"indigen", "quilombol", "lgbt", "homofob", "transfob", "deficien", "acessibilid", "autis", "inclusao social", "inclusiv",
		"liberdade", "religi", "privacidade", "dados pessoais", "tortura", "trabalho escravo", "analogo ao de escravo",
		"refugi", "migrant", "povos tradicionais", "ciganos!",
	}},
	{"consumidor", []string{
		"consumidor", "consumidores!", "consumo", "procon", "fornecedor", "telefonia", "plano de saude",
		"planos de saude", "tarifa", "conta de luz", "energia eletrica", "cobranca", "publicidade", "publicitari", "rotulag",
		"garantia legal", "devolucao", "comercio eletronico", "servicos bancarios", "superendividamento",
	}},
	{"tecnologia", []string{
		"tecnolog", "digital", "digitais!", "internet", "inteligencia artificial", "protecao de dados", "ciberne",
		"software", "informatic", "telecomunic", "5g!", "inovac", "ciencia", "cientific", "computacao", "computador", "eletronic",
		"rede social", "redes sociais", "plataforma digital", "plataformas digitais", "algoritm", "criptoativ",
		"criptomoe", "satelit", "espacial", "startups!",
	}},
	{"politica", []string{
		"eleic", "eleitor", "partid", "mandato", "mandatos!", "parlamentar", "parlamentares!", "congresso nacional",
		"reforma politica", "corrupc", "improbidad", "transparencia", "ficha limpa", "emenda parlamentar",
		"emendas parlamentares", "fundo partidario", "fundo eleitoral", "propaganda eleitoral", "cpi!",
		"comissao parlamentar de inquerito", "impeachment", "tribunal de contas", "ministerio publico", "stf!",
		"supremo tribunal", "poder judiciario", "administracao publica", "servidor publico", "servidores publicos",
		"agentes publicos", "nepotismo", "lobby", "inelegib",
	}},
	{"homenagens", []string{
		"homenag", "denomina", "titulo de cidadao", "cidadao honorario", "dia nacional", "dia estadual", "dia municipal",
		"semana nacional", "inscreve o nome", "livro dos herois", "patrono", "patrona", "medalha", "comenda",
		"honra ao merito", "voto de louvor", "voto de aplauso", "voto de congratul", "voto de pesar", "congratul",
		"centenario", "sessao solene", "sessao especial", "comemorativ", "data comemorativa", "jubileu",
	}},
}

type matcher struct {
	key   string
	words []string
	heads []string
}

var matchers = func() []matcher {
	out := make([]matcher, 0, len(Themes))
	for _, t := range Themes {
		m := matcher{key: t.Key}
		for _, s := range t.Stems {
			if strings.HasSuffix(s, "!") {
				m.words = append(m.words, " "+Fold(strings.TrimSuffix(s, "!"))+" ")
				continue
			}
			m.heads = append(m.heads, " "+Fold(s))
		}
		out = append(out, m)
	}
	return out
}()

func ThemeKeys() []string {
	keys := make([]string, len(Themes))
	for i, t := range Themes {
		keys[i] = t.Key
	}
	return keys
}

func Classify(texts ...string) []string {
	padded := " " + Fold(strings.Join(texts, " ")) + " "
	out := []string{}
	if strings.TrimSpace(padded) == "" {
		return out
	}
	for _, m := range matchers {
		if matches(padded, m) {
			out = append(out, m.key)
		}
	}
	return out
}

func matches(padded string, m matcher) bool {
	for _, w := range m.words {
		if strings.Contains(padded, w) {
			return true
		}
	}
	for _, h := range m.heads {
		if strings.Contains(padded, h) {
			return true
		}
	}
	return false
}
