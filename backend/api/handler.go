package api

import (
	"encoding/json"
	"log"
	"net/http"
	"serverwatcher/service"
	"sort"
	"strconv"
	"time"
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
		Name           string `json:"name"`
		URL            string `json:"url"`
		Interval       int    `json:"interval"`
		TimeoutMs      int    `json:"timeoutMs"`
		Retries        int    `json:"retries"`
		RetryBackoffMs int    `json:"retryBackoffMs"`
	}
	if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
		http.Error(w, "invalid data", http.StatusBadRequest)
		return
	}

	id := store.AddService(
		data.Name,
		data.URL,
		data.Interval,
		data.TimeoutMs,
		data.Retries,
		data.RetryBackoffMs,
	)

	_ = store.SaveToFile()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]int{"id": id})
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
		ID             int    `json:"id"`
		Name           string `json:"name"`
		URL            string `json:"url"`
		Interval       int    `json:"interval"`
		TimeoutMs      int    `json:"timeoutMs"`
		Retries        int    `json:"retries"`
		RetryBackoffMs int    `json:"retryBackoffMs"`
	}
	if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
		http.Error(w, "invalid data", 400)
		return
	}
	err := store.UpdateService(data.ID, data.Name, data.URL, data.Interval, data.TimeoutMs, data.Retries, data.RetryBackoffMs)
	if err != nil {
		http.Error(w, err.Error(), 400)
		return
	}
	store.SaveToFile()
	w.WriteHeader(http.StatusNoContent)
}

// GET /services/incidents?id=1&openOnly=true&since=2025-08-11T00:00:00Z
func ServiceIncidentHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	idStr := r.URL.Query().Get("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	// 404 only if the service truly doesn't exist
	if !store.HasService(id) {
		http.Error(w, "service not found", http.StatusNotFound)
		return
	}

	openOnly := r.URL.Query().Get("openOnly") == "true"

	// Parse optional since
	var since *time.Time
	if s := r.URL.Query().Get("since"); s != "" {
		// tolerate both RFC3339 and RFC3339Nano
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			since = &t
		} else if t2, err2 := time.Parse(time.RFC3339Nano, s); err2 == nil {
			since = &t2
		} else {
			http.Error(w, "invalid since (must be RFC3339)", http.StatusBadRequest)
			return
		}
	}

	// Optional limit (default 500, clamp sensible range)
	limit := 500
	if ls := r.URL.Query().Get("limit"); ls != "" {
		if l, err := strconv.Atoi(ls); err == nil && l > 0 && l <= 5000 {
			limit = l
		}
	}

	// Always get a slice (possibly empty)
	all := store.GetIncidentsOrEmpty(id)

	// Copy to avoid mutating store slice
	incs := make([]*service.Incident, len(all))
	copy(incs, all)

	// Filter
	out := make([]*service.Incident, 0, len(incs))
	for _, inc := range incs {
		if openOnly && inc.EndedAt != nil {
			continue
		}
		if since != nil {
			// keep if it overlaps the window [since, +inf):
			// i.e., starts after since OR ends after since OR is still open
			ended := time.Unix(1, 0) // dummy
			if inc.EndedAt != nil {
				ended = *inc.EndedAt
			}
			if inc.StartedAt.Before(*since) && (inc.EndedAt == nil || ended.Before(*since)) {
				continue
			}
		}
		out = append(out, inc)
	}

	// Newest first
	sort.Slice(out, func(i, j int) bool {
		return out[i].StartedAt.After(out[j].StartedAt)
	})

	// Apply limit
	if len(out) > limit {
		out = out[:limit]
	}

	_ = json.NewEncoder(w).Encode(out)
}

func GetPolicyHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(store.GetPolicy())
}

func UpdatePolicyHandler(w http.ResponseWriter, r *http.Request) {
	var p service.IncidentPolicy
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		http.Error(w, "invalid data", 400)
		return
	}
	store.UpdatePolicy(p)
	store.SaveToFile()
	json.NewEncoder(w).Encode(map[string]string{"status": "updated"})
}

func ServiceAnalyticsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	hours := 24
	if hStr := r.URL.Query().Get("hours"); hStr != "" {
		if h, err := strconv.Atoi(hStr); err == nil && h > 0 {
			hours = h
		}
	}

	a := store.ComputeAnalytics(id, hours)
	json.NewEncoder(w).Encode(a)
}

// GET /policy  |  PUT /policy
func PolicyHandler(w http.ResponseWriter, r *http.Request) {
	// CORS if you don't use withCORS:
	// w.Header().Set("Access-Control-Allow-Origin", "*")

	switch r.Method {
	case http.MethodGet:
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(store.GetPolicy())

	case http.MethodPut:
		var p service.IncidentPolicy
		if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
			http.Error(w, "invalid data", http.StatusBadRequest)
			return
		}
		store.SetPolicy(p)     // or UpdatePolicy depending on your name
		_ = store.SaveToFile() // persist policy with rest of store
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "updated"})

	case http.MethodOptions:
		w.WriteHeader(http.StatusNoContent)

	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

// GET /incidents/open
// Response: array of service.Incident (only open), no name/url added.
func OpenIncidentsHandler(w http.ResponseWriter, r *http.Request) {
	// CORS headers if you don't wrap globally
	// w.Header().Set("Access-Control-Allow-Origin", "*")
	// w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	// w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	w.Header().Set("Content-Type", "application/json")

	out := make([]*service.Incident, 0, 8)
	for _, svc := range store.GetAllServices() {
		incs, ok := store.GetIncidents(svc.ID)
		if !ok || len(incs) == 0 {
			continue
		}
		last := incs[len(incs)-1]
		if last.EndedAt == nil {
			out = append(out, last)
		}
	}
	_ = json.NewEncoder(w).Encode(out)
}
