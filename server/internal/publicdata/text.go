package publicdata

import (
	"strings"
	"unicode"
)

var foldMap = map[rune]rune{
	'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
	'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
	'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
	'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
	'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
	'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
	'º': 'o', 'ª': 'a',
}

func Fold(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	space := true
	for _, r := range strings.ToLower(s) {
		if m, ok := foldMap[r]; ok {
			r = m
		}
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			space = false
			continue
		}
		if !space {
			b.WriteByte(' ')
			space = true
		}
	}
	return strings.TrimSpace(b.String())
}

func Slugify(s string) string {
	return strings.ReplaceAll(Fold(s), " ", "-")
}

var lowerParticles = map[string]bool{"da": true, "de": true, "do": true, "das": true, "dos": true, "e": true, "di": true, "du": true, "del": true, "van": true, "von": true}

func TitleName(s string) string {
	words := strings.Fields(strings.ToLower(s))
	for i, w := range words {
		if i > 0 && lowerParticles[w] {
			continue
		}
		words[i] = capitalizeWord(w)
	}
	return strings.Join(words, " ")
}

func capitalizeWord(w string) string {
	parts := strings.Split(w, "-")
	for i, p := range parts {
		if roman(p) {
			parts[i] = strings.ToUpper(p)
			continue
		}
		r := []rune(p)
		for j, c := range r {
			if unicode.IsLetter(c) {
				r[j] = unicode.ToUpper(c)
				break
			}
		}
		parts[i] = string(r)
	}
	return strings.Join(parts, "-")
}

func roman(w string) bool {
	switch w {
	case "ii", "iii", "iv", "vi", "vii", "viii", "ix", "xi", "xii":
		return true
	}
	return false
}

func Sentence(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return s
	}
	r := []rune(s)
	r[0] = unicode.ToUpper(r[0])
	s = string(r)
	if !strings.HasSuffix(s, ".") && !strings.HasSuffix(s, "?") && !strings.HasSuffix(s, "!") {
		s += "."
	}
	return s
}

func ptr[T any](v T) *T {
	return &v
}

func strPtr(s string) *string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return &s
}
