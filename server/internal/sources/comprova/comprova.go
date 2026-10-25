package comprova

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	SiteURL      = "https://projetocomprova.com.br"
	APIURL       = SiteURL + "/wp-json/wp/v2/publicacoes"
	Name         = "Projeto Comprova"
	License      = "CC BY-ND 4.0"
	LicenseURL   = "https://creativecommons.org/licenses/by-nd/4.0/deed.pt-br"
	DefaultSince = "2022-01-01"
	siteHost     = "projetocomprova.com.br"
	perPage      = 100
	maxPages     = 200
	fields       = "id,date,modified_gmt,link,title,content,tags,image-masked,yoast_head_json"
	overlap      = time.Hour
	gmtLayout    = "2006-01-02T15:04:05"
)

type Getter interface {
	JSONHeader(ctx context.Context, rawURL string, v any) (http.Header, error)
}

type Check struct {
	ID           int64    `json:"id"`
	Date         string   `json:"date"`
	Modified     string   `json:"modified"`
	URL          string   `json:"url"`
	Title        string   `json:"title"`
	Verdict      *string  `json:"verdict"`
	Conflict     []string `json:"conflict,omitempty"`
	Explanations []string `json:"explanations,omitempty"`
}

type Store struct {
	Since      string  `json:"since"`
	CompleteAt string  `json:"completeAt,omitempty"`
	Checks     []Check `json:"checks"`
}

type Stats struct {
	Full    bool
	Pages   int
	Fetched int
	Skipped int
}

type Client struct {
	Get      Getter
	Base     string
	Since    string
	MaxPages int
	Refresh  time.Duration
	Now      func() time.Time
}

func (c Client) base() string {
	if c.Base != "" {
		return c.Base
	}
	return APIURL
}

func (c Client) since() string {
	if c.Since != "" {
		return c.Since
	}
	return DefaultSince
}

func (c Client) now() time.Time {
	if c.Now != nil {
		return c.Now()
	}
	return time.Now()
}

func (c Client) refresh() time.Duration {
	if c.Refresh > 0 {
		return c.Refresh
	}
	return 7 * 24 * time.Hour
}

func (c Client) needsFull(prev *Store) bool {
	if prev == nil || prev.Since != c.since() || prev.CompleteAt == "" {
		return true
	}
	t, err := time.Parse(time.RFC3339, prev.CompleteAt)
	return err != nil || c.now().Sub(t) >= c.refresh()
}

func (c Client) Update(ctx context.Context, prev *Store) (Store, Stats, error) {
	if _, err := time.Parse("2006-01-02", c.since()); err != nil {
		return Store{}, Stats{}, fmt.Errorf("comprova: invalid start date %q", c.since())
	}
	full := c.needsFull(prev)
	q := url.Values{}
	q.Set("per_page", strconv.Itoa(perPage))
	q.Set("orderby", "id")
	q.Set("order", "asc")
	q.Set("after", c.since()+"T00:00:00")
	q.Set("_fields", fields)
	if !full {
		if after := latestModified(prev.Checks); !after.IsZero() {
			q.Set("modified_after", after.Add(-overlap).Format(gmtLayout))
			q.Set("dates_are_gmt", "true")
		}
	}
	st := Stats{Full: full}
	byID := map[int64]Check{}
	if !full {
		for _, ch := range prev.Checks {
			byID[ch.ID] = ch
		}
	}
	limit := c.MaxPages
	if limit <= 0 || limit > maxPages {
		limit = maxPages
	}
	complete := false
	for page := 1; page <= limit; page++ {
		q.Set("page", strconv.Itoa(page))
		var posts []json.RawMessage
		header, err := c.Get.JSONHeader(ctx, c.base()+"?"+q.Encode(), &posts)
		if err != nil {
			return Store{}, st, err
		}
		st.Pages++
		for _, raw := range posts {
			ch, ok, err := Parse(raw)
			if err != nil {
				return Store{}, st, err
			}
			st.Fetched++
			if !ok {
				st.Skipped++
				delete(byID, ch.ID)
				continue
			}
			byID[ch.ID] = ch
		}
		total, err := strconv.Atoi(strings.TrimSpace(header.Get("X-WP-TotalPages")))
		if err != nil {
			return Store{}, st, errors.New("comprova: response without X-WP-TotalPages")
		}
		if page >= total || len(posts) == 0 {
			complete = true
			break
		}
	}
	out := Store{Since: c.since()}
	if full && complete {
		out.CompleteAt = c.now().UTC().Format(time.RFC3339)
	} else if !full {
		out.CompleteAt = prev.CompleteAt
	}
	for _, ch := range byID {
		out.Checks = append(out.Checks, ch)
	}
	sort.Slice(out.Checks, func(i, j int) bool { return out.Checks[i].ID < out.Checks[j].ID })
	return out, st, nil
}

func latestModified(checks []Check) time.Time {
	var best time.Time
	for _, ch := range checks {
		t, err := time.Parse(gmtLayout, ch.Modified)
		if err == nil && t.After(best) {
			best = t
		}
	}
	return best
}

type rawPost struct {
	ID       int64           `json:"id"`
	Date     string          `json:"date"`
	Modified string          `json:"modified_gmt"`
	Link     string          `json:"link"`
	Title    rendered        `json:"title"`
	Content  rendered        `json:"content"`
	Tags     json.RawMessage `json:"tags"`
	Image    json.RawMessage `json:"image-masked"`
	Yoast    json.RawMessage `json:"yoast_head_json"`
}

type rendered struct {
	Rendered string `json:"rendered"`
}

type rawTag struct {
	Tag         string `json:"tag"`
	Explanation string `json:"explanation"`
}

func Parse(data []byte) (Check, bool, error) {
	var p rawPost
	if err := json.Unmarshal(data, &p); err != nil {
		return Check{}, false, fmt.Errorf("comprova: %w", err)
	}
	ch := Check{ID: p.ID, Modified: p.Modified}
	if p.ID <= 0 {
		return ch, false, nil
	}
	link, ok := CanonicalURL(p.Link)
	if !ok {
		return ch, false, nil
	}
	day, err := time.Parse(gmtLayout, p.Date)
	if err != nil {
		return ch, false, nil
	}
	ch.URL = link
	ch.Date = day.Format("2006-01-02")
	ch.Title = PlainText(p.Title.Rendered)
	if ch.Title == "" {
		return ch, false, nil
	}
	tags := parseTags(p.Tags)
	images := imageURLs(p.Image, p.Yoast)
	if institutional(tags, images) {
		return ch, false, nil
	}
	for _, t := range tags {
		if e := PlainText(t.Explanation); e != "" {
			ch.Explanations = append(ch.Explanations, e)
		}
	}
	labels := Verdicts(tags, p.Content.Rendered, images)
	switch len(labels) {
	case 0:
	case 1:
		ch.Verdict = &labels[0]
	default:
		ch.Conflict = labels
	}
	return ch, true, nil
}

func CanonicalURL(raw string) (string, bool) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u.Scheme != "https" || u.Host != siteHost || u.User != nil || u.Path == "" || u.Path == "/" {
		return "", false
	}
	u.RawQuery, u.Fragment, u.RawFragment = "", "", ""
	return u.String(), true
}

func parseTags(raw json.RawMessage) []rawTag {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] != '[' {
		return nil
	}
	var items []json.RawMessage
	if json.Unmarshal(raw, &items) != nil {
		return nil
	}
	var out []rawTag
	for _, it := range items {
		var t rawTag
		if json.Unmarshal(it, &t) == nil {
			out = append(out, t)
		}
	}
	return out
}

func imageURLs(masked, yoast json.RawMessage) []string {
	var out []string
	var s string
	if json.Unmarshal(masked, &s) == nil && s != "" {
		out = append(out, s)
	}
	var y struct {
		OGImage json.RawMessage `json:"og_image"`
	}
	if json.Unmarshal(yoast, &y) == nil {
		var imgs []struct {
			URL string `json:"url"`
		}
		if json.Unmarshal(y.OGImage, &imgs) == nil {
			for _, im := range imgs {
				if im.URL != "" {
					out = append(out, im.URL)
				}
			}
		}
	}
	return out
}

var institutionalTags = map[string]bool{
	"comunicado": true, "lancamento": true, "relatorio": true, "minicurso": true, "+ redacoes": true,
	"app do comprova": true, "#checkbr": true, "comprova 2024": true, "programa de residencia": true,
	"recursos para jornalistas": true, "latamchequea": true, "latam chequea": true,
	"consulte o comprova": true, "pesquisa": true,
}

var institutionalImages = []string{"Comunicado", "COMUNICADO", "Release", "RELEASE", "Retorno", "RETORNO", "Vozes", "VOZES"}

func institutional(tags []rawTag, images []string) bool {
	for _, t := range tags {
		if institutionalTags[fold(t.Tag)] {
			return true
		}
	}
	for _, im := range images {
		name := imageName(im)
		if strings.HasPrefix(name, "01-Site-") {
			return true
		}
		if rest, ok := strings.CutPrefix(name, "02-Site-"); ok {
			for _, p := range institutionalImages {
				if strings.HasPrefix(rest, p) {
					return true
				}
			}
		}
	}
	return false
}

const (
	Falso            = "Falso"
	Enganoso         = "Enganoso"
	Comprovado       = "Comprovado"
	Verdadeiro       = "Verdadeiro"
	Satira           = "Sátira"
	Contextualizando = "Contextualizando"
	ComprovaExplica  = "Comprova Explica"
	Golpe            = "Golpe"
)

var tagLabels = map[string]string{
	"falso": Falso, "enganoso": Enganoso, "comprovado": Comprovado, "verdadeiro": Verdadeiro,
	"satira": Satira, "contextualizando": Contextualizando, "comprova explica": ComprovaExplica,
}

var definitionLabels = map[string]string{
	"falso": Falso, "falsos": Falso, "falsa": Falso, "falsas": Falso,
	"enganoso": Enganoso, "enganosos": Enganoso, "enganosa": Enganoso, "enganosas": Enganoso,
	"comprovado": Comprovado, "comprovados": Comprovado, "comprovada": Comprovado, "comprovadas": Comprovado,
	"satira": Satira, "satiras": Satira,
}

var headerLabels = map[string]string{"contextualizando": Contextualizando, "comprova explica": ComprovaExplica}

var imageLabels = []struct{ token, label string }{
	{"CONTEXTUALIZANDO", Contextualizando}, {"COMPROVADO", Comprovado}, {"VERDADEIRO", Verdadeiro},
	{"ENGANOSO", Enganoso}, {"FALSO", Falso}, {"SÁTIRA", Satira}, {"SATIRA", Satira},
	{"EXPLICA", ComprovaExplica}, {"GOLPE", Golpe},
}

var (
	definition = regexp.MustCompile(`(?:^|[^\p{L}])(\p{L}+)\s*,\s*para o Comprova\s*,\s*(?:é|são)\s`)
	header     = regexp.MustCompile(`<(?:b|strong)>\s*([^<]{1,40}?)\s*:?\s*</(?:b|strong)>\s*(?:<span[^>]*>)?\s*:`)
	siteImage  = regexp.MustCompile(`^\d{2}-Site-(.+)$`)
)

func Verdicts(tags []rawTag, content string, images []string) []string {
	set := map[string]bool{}
	for _, t := range tags {
		if l, ok := tagLabels[fold(t.Tag)]; ok {
			set[l] = true
		}
	}
	for _, m := range definition.FindAllStringSubmatch(PlainText(content), -1) {
		if l, ok := definitionLabels[fold(m[1])]; ok {
			set[l] = true
		}
	}
	for _, m := range header.FindAllStringSubmatch(content, -1) {
		if l, ok := headerLabels[fold(html.UnescapeString(m[1]))]; ok {
			set[l] = true
		}
	}
	for _, im := range images {
		m := siteImage.FindStringSubmatch(imageName(im))
		if m == nil {
			continue
		}
		for _, il := range imageLabels {
			if strings.HasPrefix(m[1], il.token) {
				set[il.label] = true
				break
			}
		}
	}
	out := make([]string, 0, len(set))
	for l := range set {
		out = append(out, l)
	}
	sort.Strings(out)
	return out
}

func imageName(raw string) string {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return ""
	}
	return path.Base(u.Path)
}

var accents = strings.NewReplacer(
	"á", "a", "à", "a", "â", "a", "ã", "a", "é", "e", "ê", "e", "í", "i", "ó", "o", "ô", "o", "õ", "o",
	"ú", "u", "ü", "u", "ç", "c",
)

func fold(s string) string {
	return strings.Join(strings.Fields(accents.Replace(strings.ToLower(s))), " ")
}

func PlainText(s string) string {
	var b strings.Builder
	inTag := false
	for _, r := range s {
		switch {
		case r == '<':
			inTag = true
			b.WriteByte(' ')
		case r == '>' && inTag:
			inTag = false
		case !inTag:
			b.WriteRune(r)
		}
	}
	text := html.UnescapeString(b.String())
	return strings.Join(strings.Fields(strings.ReplaceAll(text, " ", " ")), " ")
}

func LoadStore(path string) (*Store, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var s Store
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, fmt.Errorf("comprova store: %w", err)
	}
	return &s, nil
}

func SaveStore(path string, s Store) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(s)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
