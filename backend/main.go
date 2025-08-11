package main

import (
	"log"
	"net/http"
	"serverwatcher/api"
)

func main() {

	http.HandleFunc("/ping", withCORS(api.PingHandler))
	http.HandleFunc("/status", withCORS(api.StatusHandler))
	http.HandleFunc("/services/add", withCORS(api.AddServiceHandler))
	http.HandleFunc("/services/delete", withCORS(api.DeleteServiceHandler))
	http.HandleFunc("/services/history", withCORS(api.ServiceHistoryHandler))
	http.HandleFunc("/services/update", withCORS(api.UpdateServiceHandler))

	// Add CORS headers if calling from Flutter web

	log.Println("Serverwatcher backend running on http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal("Server failed:", err)
	}
}

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
