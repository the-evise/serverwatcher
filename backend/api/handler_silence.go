package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"
)

func CreateSilenceHandler(w http.ResponseWriter, r *http.Request) {
	var in struct {
		ServiceID *int   `json:"serviceId"`
		Tag       string `json:"tag"`
		Until     string `json:"until"` // RFC3339
		Reason    string `json:"reason"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "invalid json", 400)
		return
	}
	t, err := time.Parse(time.RFC3339, in.Until)
	if err != nil {
		http.Error(w, "invalid until", 400)
		return
	}

	s := store.NewSilence(in.ServiceID, in.Tag, t, in.Reason)
	json.NewEncoder(w).Encode(s)
}

func ListSilencesHandler(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(store.ListSilences())
}

func DeleteSilenceHandler(w http.ResponseWriter, r *http.Request) {
	idStr := r.URL.Query().Get("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "invalid id", 400)
		return
	}
	if !store.DeleteSilence(id) {
		http.Error(w, "not found", 404)
		return
	}
	w.WriteHeader(204)
}
