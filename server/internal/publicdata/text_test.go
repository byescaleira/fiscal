package publicdata

import (
	"reflect"
	"testing"
)

func TestFoldAndSlugify(t *testing.T) {
	if got := Fold("  Acácio   FAVACHO-Neto! "); got != "acacio favacho neto" {
		t.Fatalf("fold = %q", got)
	}
	if got := Slugify("Coronel Chrisóstomo"); got != "coronel chrisostomo" && got != "coronel-chrisostomo" {
		t.Fatalf("slug = %q", got)
	}
	if got := Slugify("Dr. Zacharias Calil"); got != "dr-zacharias-calil" {
		t.Fatalf("slug = %q", got)
	}
	if got := Slugify("Pr. Marco Feliciano"); got != "pr-marco-feliciano" {
		t.Fatalf("slug = %q", got)
	}
}

func TestTitleName(t *testing.T) {
	cases := map[string]string{
		"MAILZA ASSIS":                 "Mailza Assis",
		"ACÁCIO DA SILVA FAVACHO NETO": "Acácio da Silva Favacho Neto",
		"JOÃO DE DEUS-FILHO":           "João de Deus-Filho",
		"DOM PEDRO II":                 "Dom Pedro II",
		"DA SILVA":                     "Da Silva",
	}
	for in, want := range cases {
		if got := TitleName(in); got != want {
			t.Errorf("TitleName(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestClassify(t *testing.T) {
	cases := []struct {
		text string
		want []string
	}{
		{"Altera a Lei nº 8.080 para garantir vacinação no SUS", []string{"saude"}},
		{"Dispõe sobre o ensino de robótica e tecnologia nas escolas públicas", []string{"educacao", "tecnologia"}},
		{"Aumenta a pena do crime de feminicídio", []string{"seguranca", "mulheres"}},
		{"Institui o Dia Nacional do Fusca", []string{"homenagens"}},
		{"Proíbe a veiculação de peças publicitárias com imagens sexuais", []string{"consumidor"}},
		{"Requer a escolha de relator para a matéria", []string{}},
		{"Acrescenta o art. 68-A no Ato das Disposições Constitucionais Transitórias", []string{}},
		{"Isenta do IPVA os veículos de pessoas com deficiência", []string{"impostos", "transporte", "direitos"}},
		{"Reduz a escala 6x1 e a jornada de trabalho", []string{"economia"}},
		{"Altera o limite de receita bruta do Microempreendedor Individual", []string{"economia"}},
		{"", []string{}},
	}
	for _, c := range cases {
		got := Classify(c.text)
		if !reflect.DeepEqual(got, c.want) {
			t.Errorf("Classify(%q) = %v, want %v", c.text, got, c.want)
		}
	}
	if len(ThemeKeys()) != 17 {
		t.Fatalf("themes = %d", len(ThemeKeys()))
	}
	seen := map[string]bool{}
	for _, k := range ThemeKeys() {
		if seen[k] {
			t.Fatalf("duplicate %s", k)
		}
		seen[k] = true
	}
	for _, k := range []string{"saude", "educacao", "seguranca", "economia", "impostos", "ambiente", "cidade", "transporte", "social", "mulheres", "campo", "cultura", "direitos", "consumidor", "tecnologia", "politica", "homenagens"} {
		if !seen[k] {
			t.Fatalf("missing theme %s", k)
		}
	}
}

func TestPlainSummary(t *testing.T) {
	cases := map[string]string{
		"Altera a Lei nº 9.394, de 20 de dezembro de 1996, para incluir a educação financeira no currículo; e dá outras providências.": "Muda uma lei para incluir a educação financeira no currículo.",
		"Altera o Decreto-Lei nº 2.848, de 7 de dezembro de 1940 (Código Penal), para aumentar a pena do crime de furto.":              "Muda o Código Penal para aumentar a pena do crime de furto.",
		"Altera as Leis nºs 8.080, de 19 de setembro de 1990, e 8.142, de 28 de dezembro de 1990, para dispor sobre o SUS.":            "Muda leis para dispor sobre o SUS.",
		"Altera o art. 7º da Constituição Federal para reduzir a duração máxima semanal do trabalho e dá outras providências.":         "Muda a Constituição para reduzir a duração máxima semanal do trabalho.",
		"Altera a Lei Complementar nº 123, de 14 de dezembro de 2006, para dispor sobre o limite de receita bruta anual.":              "Muda uma lei complementar para dispor sobre o limite de receita bruta anual.",
		"Altera a Consolidação das Leis do Trabalho para prever folga aos domingos.":                                                   "Muda a Consolidação das Leis do Trabalho para prever folga aos domingos.",
		"Institui o Dia Nacional do Fusca.": "Cria o Dia Nacional do Fusca.",
		"Dispõe sobre a criação de Varas do Trabalho na jurisdição do Tribunal Regional do Trabalho da 4ª Região e dá outras providências.": "Trata da criação de Varas do Trabalho na jurisdição do Tribunal Regional do Trabalho da 4ª Região.",
		"Requer a realização de audiência pública.":                                                                    "Pede a realização de audiência pública.",
		"Eleva a dez anos a responsabilidade do empreiteiro pela solidez e segurança de edifícios":                     "Eleva a dez anos a responsabilidade do empreiteiro pela solidez e segurança de edifícios.",
		"Altera a Lei nº 8.069, de 13 de julho de 1990 (Estatuto da Criança e do Adolescente), para proibir castigos.": "Muda o Estatuto da Criança e do Adolescente para proibir castigos.",
		"Altera o Código Civil para dispor sobre a herança digital.":                                                   "Muda o Código Civil para dispor sobre a herança digital.",
		"": "",
	}
	for in, want := range cases {
		if got := PlainSummary(in); got != want {
			t.Errorf("PlainSummary(%q)\n got %q\nwant %q", in, got, want)
		}
	}
}
