package notify

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

type Webhook struct{ URL string }

func (w Webhook) Notify(title, text string) error {
	body := map[string]any{"title": title, "text": text}
	b, _ := json.Marshal(body)
	resp, err := http.Post(w.URL, "application/json", bytes.NewReader(b))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("webhook %d", resp.StatusCode)
	}
	return nil
}
