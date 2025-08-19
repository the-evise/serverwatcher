package main

import (
	"log"
	"net/http"
	"os"
	"serverwatcher/api"
)

var api_key = os.Getenv("SERVERWATCHER_API_KEY")

func withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, PUT, OPTIONS")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func requireAPIKey(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if api_key == "" {
			h.ServeHTTP(w, r)
			return
			// dev mode
		}
		got := r.Header.Get("X-API-Key")
		if got == "" || got != api_key {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		h.ServeHTTP(w, r)
	}
}

func main() {

	log.Println("Serverwatcher starting... API key set:", api_key != "")

	// Read-only
	http.HandleFunc("/ping", withCORS(api.PingHandler))
	http.HandleFunc("/status", withCORS(api.StatusHandler))
	http.HandleFunc("/services/history", withCORS(api.ServiceHistoryHandler))

	http.HandleFunc("/services/incidents", withCORS(api.ServiceIncidentHandler))
	http.HandleFunc("/services/analytics", withCORS(api.ServiceAnalyticsHandler))
	http.HandleFunc("/incidents/open", withCORS(api.OpenIncidentsHandler))
	http.HandleFunc("/policy", withCORS(api.PolicyHandler)) // GET allowed w/o key

	// Mutations (protected)
	http.HandleFunc("/services/add", withCORS(requireAPIKey(api.AddServiceHandler)))
	http.HandleFunc("/services/update", withCORS(requireAPIKey(api.UpdateServiceHandler)))
	http.HandleFunc("/services/delete", withCORS(requireAPIKey(api.DeleteServiceHandler)))
	// Policy updates protected
	http.HandleFunc("/policy/update", withCORS(requireAPIKey(api.PolicyHandler))) // PUT handled in PolicyHandler

	log.Fatal(http.ListenAndServe(":8080", nil))
}
