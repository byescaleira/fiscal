package repercussion

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	"liveresults/internal/sources/fetch"
)

const (
	WikiAPIURL   = "https://pt.wikipedia.org/w/api.php"
	PageviewsURL = "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/pt.wikipedia/all-access/user"
	WikiName     = "Wikipédia em português (Wikimedia Pageviews)"
	WikiSite     = "https://wikimedia.org/api/rest_v1/"
	ViewsDays    = 30
	ViewsTTL     = 24 * time.Hour
	TitleTTL     = 30 * 24 * time.Hour
	titleBatch   = 50
)

var politicalWords = []string{"politic", "deputad", "senador", "governador", "president", "vereador", "prefeit", "ministr", "parlamentar", "sindicalist", "vice-"}

type Wiki struct {
	Get   Getter
	API   string
	Views string
}

type queryResponse struct {
	Query struct {
		Normalized []struct {
			From string `json:"from"`
			To   string `json:"to"`
		} `json:"normalized"`
		Redirects []struct {
			From string `json:"from"`
			To   string `json:"to"`
		} `json:"redirects"`
		Pages []struct {
			Title       string `json:"title"`
			Missing     bool   `json:"missing"`
			Invalid     bool   `json:"invalid"`
			Description string `json:"description"`
			PageProps   struct {
				Disambiguation *string `json:"disambiguation"`
			} `json:"pageprops"`
		} `json:"pages"`
	} `json:"query"`
}

func (w Wiki) api() string {
	if w.API != "" {
		return w.API
	}
	return WikiAPIURL
}

func (w Wiki) views() string {
	if w.Views != "" {
		return w.Views
	}
	return PageviewsURL
}

func political(description string) bool {
	d := strings.ToLower(description)
	d = strings.NewReplacer("í", "i", "á", "a", "é", "e", "ó", "o", "ê", "e").Replace(d)
	for _, w := range politicalWords {
		if strings.Contains(d, w) {
			return true
		}
	}
	return false
}

func (w Wiki) Resolve(ctx context.Context, names []string, people bool) (map[string]string, error) {
	out := map[string]string{}
	for start := 0; start < len(names); start += titleBatch {
		end := min(start+titleBatch, len(names))
		batch := names[start:end]
		v := url.Values{}
		v.Set("action", "query")
		v.Set("format", "json")
		v.Set("formatversion", "2")
		v.Set("redirects", "1")
		v.Set("prop", "pageprops|description")
		v.Set("ppprop", "disambiguation")
		v.Set("titles", strings.Join(batch, "|"))
		var r queryResponse
		if err := w.Get.JSON(ctx, w.api()+"?"+v.Encode(), &r); err != nil {
			return out, err
		}
		hop := map[string]string{}
		for _, n := range r.Query.Normalized {
			hop[n.From] = n.To
		}
		for _, n := range r.Query.Redirects {
			hop[n.From] = n.To
		}
		accepted := map[string]bool{}
		for _, p := range r.Query.Pages {
			if p.Missing || p.Invalid || p.PageProps.Disambiguation != nil {
				continue
			}
			if people && !political(p.Description) {
				continue
			}
			accepted[p.Title] = true
		}
		for _, name := range batch {
			t := name
			for i := 0; i < 3; i++ {
				next, ok := hop[t]
				if !ok {
					break
				}
				t = next
			}
			if accepted[t] {
				out[name] = t
			} else {
				out[name] = ""
			}
		}
	}
	return out, nil
}

type pageviews struct {
	Items []struct {
		Views int64 `json:"views"`
	} `json:"items"`
}

func (w Wiki) ViewsURL(title string, end time.Time) string {
	from := end.AddDate(0, 0, -(ViewsDays - 1))
	article := url.PathEscape(strings.ReplaceAll(title, " ", "_"))
	return fmt.Sprintf("%s/%s/daily/%s00/%s00", w.views(), article, from.Format("20060102"), end.Format("20060102"))
}

func (w Wiki) Count(ctx context.Context, title string, end time.Time) (int64, error) {
	var p pageviews
	if err := w.Get.JSON(ctx, w.ViewsURL(title, end), &p); err != nil {
		if fetch.IsNotFound(err) {
			return 0, nil
		}
		return 0, err
	}
	var sum int64
	for _, it := range p.Items {
		sum += it.Views
	}
	return sum, nil
}
