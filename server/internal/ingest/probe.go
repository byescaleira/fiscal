package ingest

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"

	"liveresults/internal/history"
	"liveresults/internal/sources/anp"
	"liveresults/internal/sources/comprova"
	"liveresults/internal/sources/ibge"
	"liveresults/internal/sources/receita"
	"liveresults/internal/sources/sidra"
	"liveresults/internal/sources/tse"
)

type header interface {
	Head(ctx context.Context, rawURL string) (http.Header, error)
}

const probeDownloadLimit = 64 << 20

var ErrNoProbe = errors.New("no probe for this job")

type ProbeTarget struct {
	Files []string
	APIs  []string
	Extra []string
}

func (in *Ingest) ProbeTargets(j Job) (ProbeTarget, error) {
	var t ProbeTarget
	switch j.Name {
	case "checagens":
		t.APIs = []string{comprova.APIURL + "?per_page=1&orderby=modified&order=desc&_fields=id,modified_gmt"}
	case "sidra":
		t.APIs = []string{sidra.API + "/t/" + sidra.TableIndex + "/n1/all/v/" + sidra.VarIndex + "/p/last%201", sidra.IncomeURL()}
	case "anp":
		t.Files = append(t.Files, anp.Files...)
	case "receita":
		t.Files = []string{receita.RevenueURL}
	case "tse":
		for _, y := range in.cfg.TSEYears {
			t.Files = append(t.Files, tse.CandidatesURL(y), tse.AssetsURL(y), tse.VotesURL(y), tse.AccountsURL(y))
		}
		for _, y := range in.cfg.TSECandidateYears {
			t.Files = append(t.Files, tse.CandidatesURL(y), tse.AssetsURL(y))
		}
	case "cidades":
		y := in.cfg.CityYear
		t.Files = []string{tse.CandidatesURL(y), tse.AssetsURL(y), tse.VotesURL(y), ibge.MunicipalitiesURL}
	case "historia":
		for _, y := range in.cfg.HistoryYears {
			if y < tse.FirstMunZoneYear {
				t.Files = append(t.Files, tse.UFVotesURL(y), tse.UFTurnoutURL(y))
				continue
			}
			t.Files = append(t.Files, tse.VotesURL(y), tse.TurnoutURL(y))
		}
		t.Extra = []string{"content:" + history.ContentVersion()}
	default:
		return t, ErrNoProbe
	}
	return t, nil
}

func (in *Ingest) Probe(ctx context.Context, j Job) (string, error) {
	t, err := in.ProbeTargets(j)
	if err != nil {
		return "", err
	}
	var parts []string
	for _, u := range t.Files {
		p, err := in.probeFile(ctx, u)
		if err != nil {
			return "", err
		}
		parts = append(parts, u+"="+p)
	}
	for _, u := range t.APIs {
		var raw json.RawMessage
		if err := in.get.JSON(ctx, u, &raw); err != nil {
			return "", err
		}
		sum := sha256.Sum256(raw)
		parts = append(parts, u+"=sha256:"+hex.EncodeToString(sum[:]))
	}
	parts = append(parts, t.Extra...)
	sort.Strings(parts)
	sum := sha256.Sum256([]byte(strings.Join(parts, "\n")))
	return hex.EncodeToString(sum[:]), nil
}

func (in *Ingest) probeFile(ctx context.Context, rawURL string) (string, error) {
	if h, ok := in.get.(header); ok {
		hd, err := h.Head(ctx, rawURL)
		if err == nil {
			etag, mod, size := hd.Get("ETag"), hd.Get("Last-Modified"), hd.Get("Content-Length")
			if etag != "" || mod != "" {
				return fmt.Sprintf("etag:%s|modified:%s|size:%s", etag, mod, size), nil
			}
		}
	}
	c, err := in.get.Cache(ctx, rawURL, probeDownloadLimit)
	if err != nil {
		return "", err
	}
	f, err := os.Open(c.Path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	sum := sha256.New()
	if _, err := io.Copy(sum, f); err != nil {
		return "", err
	}
	return "sha256:" + hex.EncodeToString(sum.Sum(nil)), nil
}
