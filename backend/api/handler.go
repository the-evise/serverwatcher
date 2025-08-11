package api

import (
	"encoding/json"
	"log"
	"net/http"
	"serverwatcher/service"
	"strconv"
)

var store = service.NewStore()

func init() {
	if err := store.LoadFromFile(); err != nil {
		log.Println("failed to load persisted data:", err)
	}

	services := store.GetAllServices()
	log.Printf("Loaded %d services from file", len(services))

	for _, svc := range services {
		store.RestartChecker(svc)
	}
}

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

	store.SaveToFile()
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

	store.SaveToFile()
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

func UpdateServiceHandler(w http.ResponseWriter, r *http.Request) {
	var data struct {
		ID       int    `json:"id"`
		Name     string `json:"name"`
		URL      string `json:"url"`
		Interval int    `json:"interval"`
	}
	if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
		http.Error(w, "invalid data", 400)
		return
	}
	err := store.UpdateService(data.ID, data.Name, data.URL, data.Interval)
	if err != nil {
		http.Error(w, err.Error(), 400)
		return
	}
	store.SaveToFile()
	w.WriteHeader(http.StatusNoContent)
}
