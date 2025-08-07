package api

import (
	"encoding/json"
	"net/http"
	"serverwatcher/service"
	"strconv"
)

var store = service.NeweStore()

func PingHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func StatusHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	status := store.GetStatuses()
	json.NewEncoder(w).Encode(status)
}

func AddServiceHandler(w http.ResponseWriter, r *http.Request) {
	var data struct {
		Name     string `json:"name"`
		URL      string `json:"url"`
		Interval int    `json:"interval"` //seconds
	}
	if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
		http.Error(w, "invalid data", 400)
		return
	}
	id := store.AddService(data.Name, data.URL, data.Interval)
	json.NewEncoder(w).Encode(map[string]int{"id": id})
}

func DeleteServiceHandler(w http.ResponseWriter, r *http.Request) {
	idStr := r.URL.Query().Get("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "invalid id", 400)
		return
	}
	store.RemoveService(id)
	w.WriteHeader(http.StatusNoContent)
}

func ServiceHistoryHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	idStr := r.URL.Query().Get("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "invalid id", 400)
		return
	}
	history, ok := store.GetHistory(id)
	if !ok {
		http.Error(w, "service not found", 404)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(history)
}
