package service

import (
	"context"
	"net/http"
	"time"
)

func (s *Store) startChecker(svc *Service, stopChan chan struct{}) {
	ticker := time.NewTicker(svc.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			status := checkService(svc)
			now := time.Now().UTC()

			s.Lock()
			s.ensureMaps()

			// Update latest + history
			s.statuses[svc.ID] = status
			const maxHistory = 1000
			h := s.histories[svc.ID]
			h = append(h, status)
			if len(h) > maxHistory {
				h = h[len(h)-maxHistory:]
			}
			s.histories[svc.ID] = h

			// Update streaks
			if status.Status == "FAIL" {
				s.failStreak[svc.ID]++
				s.okStreak[svc.ID] = 0
				if s.failStreak[svc.ID] == 1 {
					s.firstFailAt[svc.ID] = now
				}
			} else {
				s.okStreak[svc.ID]++
				s.failStreak[svc.ID] = 0
				delete(s.firstFailAt, svc.ID)
			}

			prev := s.lastStatus[svc.ID]
			p := s.policy

			// --- Open logic (debounced)
			if prev != "FAIL" && status.Status == "FAIL" {
				openByConsec := s.failStreak[svc.ID] >= p.OpenConsecutiveFails
				openBySeconds := false
				if p.OpenSeconds > 0 {
					if t0, ok := s.firstFailAt[svc.ID]; ok {
						openBySeconds = now.Sub(t0) >= time.Duration(p.OpenSeconds)*time.Second
					}
				}
				if openByConsec || openBySeconds {
					inc := &Incident{
						ID:        s.nextIncidentID,
						ServiceID: svc.ID,
						StartedAt: now,
					}
					s.nextIncidentID++
					s.openIncident[svc.ID] = inc
					s.Incidents[svc.ID] = append(s.Incidents[svc.ID], inc)
					s.lastStatus[svc.ID] = "FAIL"

					// notify (optional): cooldown by AlertCooldownSec
					if s.canNotify(svc.ID, now) {
						s.lastAlertAt[svc.ID] = now
						// go SendTelegramNotification(fmt.Sprintf("[DOWN] %s\nURL: %s\nTime: %s", svc.Name, svc.URL, now.Format(time.RFC3339)))
					}
				}
			}

			// --- Close logic (debounced)
			if prev == "FAIL" && status.Status == "OK" {
				if s.okStreak[svc.ID] >= p.CloseConsecutiveOKs {
					if open := s.openIncident[svc.ID]; open != nil {
						open.EndedAt = &now
						open.DurationS = int(now.Sub(open.StartedAt).Seconds())
						s.openIncident[svc.ID] = nil
						s.lastStatus[svc.ID] = "OK"

						// notify (optional)
						if s.canNotify(svc.ID, now) {
							s.lastAlertAt[svc.ID] = now
							// go SendTelegramNotification(fmt.Sprintf("[UP] %s\nURL: %s\nTime: %s\nDowntime: %ds", svc.Name, svc.URL, now.Format(time.RFC3339), open.DurationS))
						}
					} else {
						// No open incident tracked, just update status
						s.lastStatus[svc.ID] = "OK"
					}
				}
			}

			s.Unlock()

		case <-stopChan:
			return
		}
	}
}

func checkService(svc *Service) StatusResult {
	// defaults if unset
	timeoutMs := svc.TimeoutMs
	if timeoutMs <= 0 {
		timeoutMs = 2500
	}
	retries := svc.Retries
	if retries < 0 {
		retries = 1
	}
	backoffMs := svc.RetryBackoffMs
	if backoffMs <= 0 {
		backoffMs = 300
	}

	totalStart := time.Now()
	status := "FAIL"
	var lastErr error
	var lastCode int

	tryCount := retries + 1 // initial try + N retries
	for i := 0; i < tryCount; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
		start := time.Now()
		req, _ := http.NewRequestWithContext(ctx, http.MethodGet, svc.URL, nil)
		resp, err := http.DefaultClient.Do(req)
		elapsed := int(time.Since(start).Milliseconds())
		cancel()

		if err == nil && resp != nil && resp.StatusCode >= 200 && resp.StatusCode < 400 {
			if resp != nil {
				resp.Body.Close()
			}
			return StatusResult{
				ID: svc.ID, Name: svc.Name, URL: svc.URL,
				Status: "OK", ResponseMs: int(time.Since(totalStart).Milliseconds()),
				CheckedAt: time.Now().UTC().Format(time.RFC3339),
			}
		}
		if resp != nil {
			lastCode = resp.StatusCode
			resp.Body.Close()
		}
		lastErr = err

		// backoff before next retry (if any)
		if i < tryCount-1 {
			time.Sleep(time.Duration(backoffMs) * time.Millisecond)
		}

		_ = elapsed // kept for future per-try metrics
	}

	// fail after all attempts
	_ = lastErr
	_ = lastCode
	return StatusResult{
		ID: svc.ID, Name: svc.Name, URL: svc.URL,
		Status: status, ResponseMs: int(time.Since(totalStart).Milliseconds()),
		CheckedAt: time.Now().UTC().Format(time.RFC3339),
	}
}

// AddService creates a service with reliability settings and starts its checker.
// Returns the assigned ID.
func (s *Store) AddService(name, url string, interval, timeoutMs, retries, backoffMs int) int {
	s.Lock()
	defer s.Unlock()
	s.ensureMaps()

	// defaults
	if interval <= 0 {
		interval = 10
	}
	if timeoutMs <= 0 {
		timeoutMs = 2500
	}
	if retries < 0 {
		retries = 1
	}
	if backoffMs <= 0 {
		backoffMs = 300
	}

	id := s.nextID
	if id <= 0 {
		id = 1
	}
	s.nextID = id + 1

	svc := &Service{
		ID: id, Name: name, URL: url,
		Interval:       time.Duration(interval) * time.Second,
		Active:         true,
		TimeoutMs:      timeoutMs,
		Retries:        retries,
		RetryBackoffMs: backoffMs,
	}

	// store and start checker
	s.services[id] = svc
	ch := make(chan struct{})
	s.stopChans[id] = ch
	// reset runtime counters
	s.failStreak[id] = 0
	s.okStreak[id] = 0
	delete(s.firstFailAt, id)

	go s.startChecker(svc, ch)
	return id
}

func (s *Store) RemoveService(id int) {
	s.Lock()
	if stopChan, ok := s.stopChans[id]; ok {
		close(stopChan) // singal checker to stop
	}
	delete(s.services, id)
	delete(s.statuses, id)
	delete(s.stopChans, id)
	s.Unlock()
}

func (s *Store) canNotify(svcID int, now time.Time) bool {
	cd := time.Duration(s.policy.AlertCooldownSec) * time.Second
	if cd <= 0 {
		return true
	}
	last, ok := s.lastAlertAt[svcID]
	if !ok {
		return true
	}
	return now.Sub(last) >= cd
}

func (s *Store) GetStatuses() []StatusResult {
	s.Lock()
	defer s.Unlock()
	results := make([]StatusResult, 0, len(s.statuses))
	for _, status := range s.statuses {
		results = append(results, status)
	}
	return results
}

func (s *Store) GetHistory(id int) ([]StatusResult, bool) {
	s.Lock()
	defer s.Unlock()
	history, ok := s.histories[id]
	return history, ok
}
