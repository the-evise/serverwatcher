package service

import (
	"bytes"
	"fmt"
	"net/http"
)

const telegramBotToken = "8396998324:AAEscq2rXYteRXxA4qmuD9RBftrRWSsn3v0"
const telegramChatID = "277355330"

func SendTelegramNotification(message string) error {
	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", telegramBotToken)
	payload := []byte(fmt.Sprintf(`{"chat_id":"%s","text":"%s"}`, telegramChatID, message))
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(payload))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}
