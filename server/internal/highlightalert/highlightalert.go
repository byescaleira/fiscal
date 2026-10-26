package highlightalert

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"io"
	"log"
	"os"
	"sync"
	"sync/atomic"
	"time"
	"unicode/utf8"

	"liveresults/internal/apns"
	"liveresults/internal/publicdata"
	"liveresults/internal/store"
)

const (
	Bucket         = "highlights"
	AttributesType = "HighlightActivityAttributes"
	Lifetime       = 8 * time.Hour
	SentFile       = "highlight-alerts.json"
	keepSent       = 14 * 24 * time.Hour
	maxFile        = 8 << 20
	maxPayload     = 4000
	titleLimit     = 320
	subtitleLimit  = 160
	bodyLimit      = 140
	relevance      = 50
)

var brasilia = time.FixedZone("BRT", -3*3600)

type Person struct {
	Name  string `json:"name"`
	Slug  string `json:"slug"`
	Party string `json:"party"`
}

type Item struct {
	ID       string  `json:"id"`
	Kind     string  `json:"kind"`
	Title    string  `json:"title"`
	Subtitle string  `json:"subtitle"`
	Weight   int     `json:"weight"`
	Route    string  `json:"route"`
	Person   *Person `json:"person"`
	Date     string  `json:"date"`
	publicdata.SignalCoverage
}

type highlightFile struct {
	Items []Item `json:"items"`
}

func day(date string) (time.Time, bool) {
	if len(date) > 10 {
		date = date[:10]
	}
	t, err := time.ParseInLocation("2006-01-02", date, brasilia)
	return t, err == nil
}

func Eligible(it Item, now time.Time) bool {
	if it.Weight < publicdata.AlertMinWeight || it.ID == "" {
		return false
	}
	start, ok := day(it.Date)
	if !ok || start.After(now) {
		return false
	}
	end := start.AddDate(0, 0, 1)
	return now.Sub(end) <= publicdata.AlertMaxAgeHours*time.Hour
}

func Pick(items []Item, sent map[string]time.Time, now time.Time) (Item, bool) {
	for _, it := range items {
		if _, done := sent[it.ID]; done {
			continue
		}
		if Eligible(it, now) {
			return it, true
		}
	}
	return Item{}, false
}

func clip(s string, limit int) string {
	if utf8.RuneCountInString(s) <= limit {
		return s
	}
	r := []rune(s)
	return string(r[:limit-1]) + "…"
}

type attributes struct {
	HighlightID string   `json:"highlightId"`
	Kind        string   `json:"kind"`
	Title       string   `json:"title"`
	Subtitle    string   `json:"subtitle"`
	Date        string   `json:"date"`
	Route       string   `json:"route"`
	PersonName  string   `json:"personName,omitempty"`
	PersonSlug  string   `json:"personSlug,omitempty"`
	Party       string   `json:"party,omitempty"`
	Confidence  string   `json:"confidence,omitempty"`
	Measured    []string `json:"measured,omitempty"`
	Missing     []string `json:"missing,omitempty"`
}

type contentState struct {
	Weight int     `json:"weight"`
	EndsAt float64 `json:"endsAt"`
}

type alert struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type aps struct {
	Timestamp      int64        `json:"timestamp"`
	Event          string       `json:"event"`
	ContentState   contentState `json:"content-state"`
	AttributesType string       `json:"attributes-type"`
	Attributes     attributes   `json:"attributes"`
	Alert          alert        `json:"alert"`
	StaleDate      int64        `json:"stale-date"`
	RelevanceScore int          `json:"relevance-score"`
}

func BuildStart(it Item, now time.Time) ([]byte, error) {
	date := it.Date
	if len(date) > 10 {
		date = date[:10]
	}
	ends := now.Add(Lifetime)
	attrs := attributes{HighlightID: it.ID, Kind: it.Kind, Title: clip(it.Title, titleLimit), Subtitle: clip(it.Subtitle, subtitleLimit), Date: date, Route: it.Route, Confidence: it.Confidence, Measured: it.Measured, Missing: it.Missing}
	if it.Person != nil {
		attrs.PersonName, attrs.PersonSlug, attrs.Party = it.Person.Name, it.Person.Slug, it.Person.Party
	}
	body := aps{
		Timestamp:      now.Unix(),
		Event:          "start",
		ContentState:   contentState{Weight: it.Weight, EndsAt: float64(ends.Unix())},
		AttributesType: AttributesType,
		Attributes:     attrs,
		Alert:          alert{Title: "Destaque do momento", Body: clip(it.Title, bodyLimit)},
		StaleDate:      ends.Unix(),
		RelevanceScore: relevance,
	}
	for limit := titleLimit; ; limit -= 60 {
		body.Attributes.Title = clip(it.Title, limit)
		data, err := json.Marshal(map[string]aps{"aps": body})
		if err != nil {
			return nil, err
		}
		if len(data) <= maxPayload || limit <= 60 {
			if len(data) > maxPayload {
				return nil, errors.New("payload too large")
			}
			return data, nil
		}
	}
}

type Registry interface {
	ForRace(raceID string) []store.Registration
	Delete(token string) bool
}

type Options struct {
	Path     string
	SentPath string
	Sender   apns.Sender
	Registry Registry
	Now      func() time.Time
	Workers  int
	Logger   *log.Logger
}

type Watcher struct {
	path     string
	sentPath string
	sender   apns.Sender
	registry Registry
	now      func() time.Time
	workers  int
	logger   *log.Logger

	mu       sync.Mutex
	modTime  time.Time
	size     int64
	hash     [32]byte
	sent     map[string]time.Time
	reported bool
}

func New(o Options) *Watcher {
	if o.Now == nil {
		o.Now = time.Now
	}
	if o.Workers <= 0 {
		o.Workers = 8
	}
	if o.Logger == nil {
		o.Logger = log.Default()
	}
	return &Watcher{path: o.Path, sentPath: o.SentPath, sender: o.Sender, registry: o.Registry, now: o.Now, workers: o.Workers, logger: o.Logger, sent: map[string]time.Time{}}
}

type sentFile struct {
	Sent map[string]time.Time `json:"sent"`
}

func (w *Watcher) Load() error {
	if w.sentPath == "" {
		return nil
	}
	data, err := os.ReadFile(w.sentPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	var f sentFile
	if err := json.Unmarshal(data, &f); err != nil {
		return err
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	for id, at := range f.Sent {
		w.sent[id] = at
	}
	return nil
}

func (w *Watcher) saveLocked() {
	if w.sentPath == "" {
		return
	}
	cutoff := w.now().Add(-keepSent)
	for id, at := range w.sent {
		if at.Before(cutoff) {
			delete(w.sent, id)
		}
	}
	data, err := json.Marshal(sentFile{Sent: w.sent})
	if err == nil {
		err = store.WriteFileAtomic(w.sentPath, data)
	}
	if err != nil {
		w.logger.Printf("highlight alerts: save: %v", err)
	}
}

func (w *Watcher) read() ([]Item, bool) {
	info, err := os.Stat(w.path)
	if err != nil {
		if !w.reported {
			w.reported = true
			w.logger.Printf("highlight alerts: %v", err)
		}
		return nil, false
	}
	w.reported = false
	if info.ModTime().Equal(w.modTime) && info.Size() == w.size {
		return nil, false
	}
	f, err := os.Open(w.path)
	if err != nil {
		return nil, false
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, maxFile+1))
	if err != nil || len(data) > maxFile {
		w.logger.Printf("highlight alerts: read failed or file too large")
		return nil, false
	}
	w.modTime, w.size = info.ModTime(), info.Size()
	sum := sha256.Sum256(data)
	if sum == w.hash {
		return nil, false
	}
	w.hash = sum
	var hf highlightFile
	if err := json.Unmarshal(data, &hf); err != nil {
		w.logger.Printf("highlight alerts: decode: %v", err)
		return nil, false
	}
	return hf.Items, true
}

func (w *Watcher) CheckOnce(ctx context.Context) {
	w.mu.Lock()
	items, changed := w.read()
	if !changed {
		w.mu.Unlock()
		return
	}
	now := w.now()
	it, ok := Pick(items, w.sent, now)
	w.mu.Unlock()
	if !ok {
		return
	}
	payload, err := BuildStart(it, now)
	if err != nil {
		w.logger.Printf("highlight alerts: build %s: %v", it.ID, err)
		return
	}
	regs := w.registry.ForRace(Bucket)
	if len(regs) == 0 {
		w.logger.Printf("highlight alerts: %s eligible, no registrations", it.ID)
		return
	}
	sent, failed, removed := w.dispatch(ctx, regs, payload)
	w.mu.Lock()
	w.sent[it.ID] = now
	w.saveLocked()
	w.mu.Unlock()
	w.logger.Printf("highlight alerts: start id=%s weight=%d registrations=%d sent=%d failed=%d removed=%d", it.ID, it.Weight, len(regs), sent, failed, removed)
}

func (w *Watcher) dispatch(ctx context.Context, regs []store.Registration, payload []byte) (int64, int64, int64) {
	var sent, failed, removed atomic.Int64
	jobs := make(chan store.Registration)
	var wg sync.WaitGroup
	for range min(w.workers, len(regs)) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for reg := range jobs {
				res := w.sender.Send(ctx, apns.Notification{Token: reg.PushToken, Environment: reg.Environment, Priority: apns.PriorityHigh, Payload: payload})
				switch {
				case res.OK():
					sent.Add(1)
				case res.TokenInvalid():
					w.registry.Delete(reg.PushToken)
					removed.Add(1)
				default:
					failed.Add(1)
					if res.Err != nil {
						w.logger.Printf("highlight alerts: token=%s… error=%v", prefix(reg.PushToken), res.Err)
					} else {
						w.logger.Printf("highlight alerts: token=%s… status=%d reason=%s", prefix(reg.PushToken), res.Status, res.Reason)
					}
				}
			}
		}()
	}
	for _, reg := range regs {
		if ctx.Err() != nil {
			break
		}
		jobs <- reg
	}
	close(jobs)
	wg.Wait()
	return sent.Load(), failed.Load(), removed.Load()
}

func prefix(token string) string {
	if len(token) > 6 {
		return token[:6]
	}
	return token
}

func (w *Watcher) Run(ctx context.Context, interval time.Duration) {
	w.CheckOnce(ctx)
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			w.CheckOnce(ctx)
		}
	}
}
