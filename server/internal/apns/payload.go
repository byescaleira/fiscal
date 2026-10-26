package apns

import (
	"encoding/json"
	"time"

	"liveresults/internal/tse"
)

const (
	staleAfter   = 10 * time.Minute
	dismissAfter = 4 * time.Hour
	PriorityLow  = 5
	PriorityHigh = 10
)

type candidateState struct {
	Number  string  `json:"number"`
	Votes   int64   `json:"votes"`
	Percent float64 `json:"percent"`
	Elected bool    `json:"elected"`
}

type contentState struct {
	SectionsPercent float64          `json:"sectionsPercent"`
	Candidates      []candidateState `json:"candidates"`
	Final           bool             `json:"final"`
	UpdatedAt       float64          `json:"updatedAt"`
}

type alert struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type aps struct {
	Timestamp     int64        `json:"timestamp"`
	Event         string       `json:"event"`
	ContentState  contentState `json:"content-state"`
	StaleDate     int64        `json:"stale-date,omitempty"`
	DismissalDate int64        `json:"dismissal-date,omitempty"`
	Alert         *alert       `json:"alert,omitempty"`
}

type Message struct {
	Payload  []byte
	Priority int
	End      bool
}

func BuildMessage(r tse.Race, now time.Time) (Message, error) {
	updated := now
	if t, ok := r.GeneratedAt(); ok {
		updated = t
	}
	state := contentState{
		SectionsPercent: r.Sections.Percent,
		Candidates:      make([]candidateState, 0, len(r.Candidates)),
		Final:           r.Final,
		UpdatedAt:       float64(updated.Unix()),
	}
	for _, c := range r.Candidates {
		state.Candidates = append(state.Candidates, candidateState{Number: c.Number, Votes: c.Votes, Percent: c.Percent, Elected: c.Elected})
	}
	body := aps{Timestamp: now.Unix(), Event: "update", ContentState: state}
	msg := Message{Priority: PriorityLow}
	if r.Final {
		body.Event = "end"
		body.DismissalDate = now.Add(dismissAfter).Unix()
		text := "Apuração encerrada"
		if c, ok := r.Elected(); ok {
			text = c.Name + " foi eleito(a)"
		}
		body.Alert = &alert{Title: "Resultado", Body: text}
		msg.Priority = PriorityHigh
		msg.End = true
	} else {
		body.StaleDate = now.Add(staleAfter).Unix()
	}
	payload, err := json.Marshal(map[string]aps{"aps": body})
	if err != nil {
		return Message{}, err
	}
	msg.Payload = payload
	return msg, nil
}
