package api

import (
	"encoding/json"
	"net/http"
	"strconv"
)

func ServiceSLOHandler(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.Atoi(r.URL.Query().Get("id"))
	hours := 720 // default 30d
	if s := r.URL.Query().Get("hours"); s != "" {
		if v, err := strconv.Atoi(s); err == nil && v > 0 {
			hours = v
		}
	}

	a := store.ComputeAnalytics(id, hours)  // you already have analytics
	target := store.GetServiceSLOTarget(id) // returns default if unset (e.g., 99.9)

	// error budget math
	// budget = allowed-downtime = (1 - target/100) * window_seconds
	windowSec := hours * 3600
	allowedDown := float64(windowSec) * (1 - target/100.0)

	// observed down (approx): failCount * intervalSec (rough)
	observedDown := store.EstimateDowntimeSeconds(id, hours)

	// burn rate = observedDown / allowedDown
	br := 0.0
	if allowedDown > 0 {
		br = observedDown / allowedDown
	}

	out := map[string]any{
		"serviceId":           id,
		"target":              target,
		"windowHours":         hours,
		"analytics":           a,
		"allowedDowntimeSec":  int(allowedDown),
		"observedDowntimeSec": int(observedDown),
		"burnRate":            br, // 1.0 == consuming budget at expected pace
		"breached":            a.UptimePercent < target,
	}
	json.NewEncoder(w).Encode(out)
}
