package notify

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

type Slack struct{ WebhookURL string }

func (s Slack) Notify(title, text string) error {
	body := map[string]any{
		"text": "*" + title + "*\n" + text,
	}
	b, _ := json.Marshal(body)
	resp, err := http.Post(s.WebhookURL, "application/json", bytes.NewReader(b))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("slack %d", resp.StatusCode)
	}
	return nil
}
