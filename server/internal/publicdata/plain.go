package publicdata

import (
	"regexp"
	"strings"
)

var (
	reSpaces      = regexp.MustCompile(`\s+`)
	reProvidences = regexp.MustCompile(`(?i)[,;]?\s*e\s+d[áa]\s+outras\s+provid[êe]ncias\.?\s*$`)
	reDate        = regexp.MustCompile(`(?i),?\s+de\s+\d{1,2}(º|o)?\s+de\s+[a-zç]+\s+de\s+\d{4}`)
	reConst       = regexp.MustCompile(`(?i)^(altera|acrescenta|modifica|d[áa] nova reda[çc][ãa]o)\b.*?\bconstitui[çc][ãa]o( federal| da rep[úu]blica)?\b`)
	reAlter       = regexp.MustCompile(`(?i)^(altera|modifica|acrescenta|inclui|d[áa] nova reda[çc][ãa]o)\b`)
	reNamed       = regexp.MustCompile(`(C[óo]digo [A-ZÀ-Úa-zà-ú ]+?|Consolida[çc][ãa]o das Leis do Trabalho|Estatuto d[aeo]s? [A-ZÀ-Úa-zà-ú ]+?|Lei Maria da Penha|Marco [A-ZÀ-Úa-zà-ú ]+?|Lei de [A-ZÀ-Úa-zà-ú ]+?|Lei Org[âa]nica [A-ZÀ-Úa-zà-ú ]+?)(\)|,|;| -| para| a fim|$)`)
	reLawRef      = regexp.MustCompile(`(?i)\b(lei complementar|decreto-lei|lei|leis|medida provis[óo]ria)\s+(n[ºo°.]*s?\s*)?[\d.]+`)
	rePurpose     = regexp.MustCompile(`(?i)\b(para|a fim de|com o objetivo de|com vistas a)\s+(.+)$`)
)

var verbs = []struct {
	from string
	to   string
}{
	{"institui ", "Cria "},
	{"cria ", "Cria "},
	{"dispõe sobre ", "Trata de "},
	{"dispoe sobre ", "Trata de "},
	{"revoga ", "Revoga "},
	{"susta ", "Suspende "},
	{"requer ", "Pede "},
	{"solicita ", "Pede "},
	{"requerem ", "Pedem "},
	{"autoriza ", "Autoriza "},
	{"proíbe ", "Proíbe "},
	{"obriga ", "Obriga "},
	{"estabelece ", "Define "},
	{"regulamenta ", "Define regras para "},
	{"concede ", "Concede "},
	{"declara ", "Declara "},
	{"aprova ", "Aprova "},
}

func cleanEmenta(s string) string {
	s = strings.TrimSpace(reSpaces.ReplaceAllString(s, " "))
	s = reProvidences.ReplaceAllString(s, "")
	return strings.TrimRight(strings.TrimSpace(s), ".;,")
}

func PlainSummary(ementa string) string {
	s := cleanEmenta(ementa)
	if s == "" {
		return ""
	}
	if reConst.MatchString(s) {
		return Sentence("Muda a Constituição" + purpose(s))
	}
	if reAlter.MatchString(s) {
		return Sentence(changeLaw(s))
	}
	lower := strings.ToLower(s)
	for _, v := range verbs {
		if strings.HasPrefix(lower, v.from) {
			rest := strings.TrimSpace(s[len(v.from):])
			return Sentence(contract(v.to + simplify(rest)))
		}
	}
	return Sentence(simplify(s))
}

var contractions = []struct{ from, to string }{
	{" de as ", " das "},
	{" de os ", " dos "},
	{" de a ", " da "},
	{" de o ", " do "},
}

func contract(s string) string {
	for _, c := range contractions {
		s = strings.Replace(s, c.from, c.to, 1)
	}
	return s
}

func purpose(s string) string {
	m := rePurpose.FindStringSubmatch(s)
	if m == nil {
		return ""
	}
	return " para " + simplify(strings.TrimSpace(m[2]))
}

func changeLaw(s string) string {
	head := s
	if loc := rePurpose.FindStringIndex(s); loc != nil {
		head = strings.TrimSpace(s[:loc[0]])
	}
	if name := namedLaw(head); name != "" {
		return "Muda " + article(name) + " " + name + purpose(s)
	}
	refs := reLawRef.FindAllStringSubmatch(head, -1)
	kinds := map[string]bool{}
	for _, r := range refs {
		kinds[strings.ToLower(r[1])] = true
	}
	plural := len(refs) > 1 || kinds["leis"] || strings.Contains(strings.ToLower(head), "leis n")
	switch {
	case plural:
		return "Muda leis" + purpose(s)
	case kinds["lei complementar"]:
		return "Muda uma lei complementar" + purpose(s)
	case kinds["decreto-lei"]:
		return "Muda um decreto-lei" + purpose(s)
	case kinds["medida provisória"], kinds["medida provisoria"]:
		return "Muda uma medida provisória" + purpose(s)
	case kinds["lei"]:
		return "Muda uma lei" + purpose(s)
	}
	return "Muda regras" + purpose(s)
}

func namedLaw(head string) string {
	m := reNamed.FindStringSubmatch(head)
	if m == nil {
		return ""
	}
	name := strings.TrimSpace(m[1])
	words := strings.Fields(name)
	for len(words) > 2 {
		last := strings.ToLower(words[len(words)-1])
		if last == "que" || last == "e" || last == "o" || last == "a" || last == "de" || last == "do" || last == "da" {
			words = words[:len(words)-1]
			continue
		}
		break
	}
	return strings.Join(words, " ")
}

func article(name string) string {
	l := strings.ToLower(name)
	switch {
	case strings.HasPrefix(l, "consolida"), strings.HasPrefix(l, "lei"):
		return "a"
	}
	return "o"
}

func simplify(s string) string {
	s = reDate.ReplaceAllString(s, "")
	s = strings.ReplaceAll(s, "  ", " ")
	return strings.TrimRight(strings.TrimSpace(s), ".;,")
}
