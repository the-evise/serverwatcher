package service

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"time"
)

// startChecker runs periodic checks for a single service.
func (s *Store) startChecker(svc *Service, stopChan chan struct{}) {
	// Safety: ensure maps exist before entering loop
	s.Lock()
	s.ensureMaps()
	s.Unlock()

	ticker := time.NewTicker(svc.Interval)
	defer ticker.Stop()

	// Optional: run immediately instead of waiting for first tick
	runCheck := func() {
		status := checkService(svc)
		now := time.Now().UTC()

		s.Lock()
		defer s.Unlock()
		s.ensureMaps()

		// Update latest + history (bounded)
		s.statuses[svc.ID] = status
		const maxHistory = 1000
		h := s.histories[svc.ID]
		h = append(h, status)
		if len(h) > maxHistory {
			h = h[len(h)-maxHistory:]
		}
		s.histories[svc.ID] = h

		// Streak accounting for incident debounce
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

		// ---- OPEN logic (OK->FAIL, debounced)
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

				// Notify (respect cooldown + silences)
				if s.canNotify(svc.ID, now) && !s.IsSilenced(svc) {
					s.lastAlertAt[svc.ID] = now
					title := fmt.Sprintf("[DOWN] %s", svc.Name)
					text := fmt.Sprintf("URL: %s\nTime: %s", svc.URL, now.Format(time.RFC3339))
					go s.broadcast(title, text)
				}
			}
		}

		// ---- CLOSE logic (FAIL->OK, debounced)
		if prev == "FAIL" && status.Status == "OK" {
			if s.okStreak[svc.ID] >= p.CloseConsecutiveOKs {
				if open := s.openIncident[svc.ID]; open != nil {
					open.EndedAt = &now
					open.DurationS = int(now.Sub(open.StartedAt).Seconds())
					s.openIncident[svc.ID] = nil
					s.lastStatus[svc.ID] = "OK"

					// Notify (respect cooldown + silences)
					if s.canNotify(svc.ID, now) && !s.IsSilenced(svc) {
						s.lastAlertAt[svc.ID] = now
						title := fmt.Sprintf("[UP] %s", svc.Name)
						text := fmt.Sprintf("URL: %s\nTime: %s\nDowntime: %ds",
							svc.URL, now.Format(time.RFC3339), open.DurationS)
						go s.broadcast(title, text)
					}
				} else {
					// No open incident tracked; just set status
					s.lastStatus[svc.ID] = "OK"
				}
			}
		}

		// NOTE: SQLite write removed. We'll add it back once SqlStore is integrated.
	}

	// run once immediately
	runCheck()

	for {
		select {
		case <-ticker.C:
			runCheck()
		case <-stopChan:
			return
		}
	}
}

// checkService performs one logical check with retries/backoff and assertions.
func checkService(svc *Service) StatusResult {
	// Defaults
	timeoutMs := svc.TimeoutMs
	if timeoutMs <= 0 {
		timeoutMs = 2500
	}
	retries := svc.Retries
	if retries < 0 {
		retries = 0 // 0 extra retries means single attempt
	}
	backoffMs := svc.RetryBackoffMs
	if backoffMs <= 0 {
		backoffMs = 300
	}
	expected := svc.ExpectedStatus
	if expected == 0 {
		expected = 200
	}
	needle := svc.Contains

	totalStart := time.Now()
	statusStr := "FAIL"

	tryCount := retries + 1
	for i := 0; i < tryCount; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
		start := time.Now()
		req, _ := http.NewRequestWithContext(ctx, http.MethodGet, svc.URL, nil)
		resp, err := http.DefaultClient.Do(req)
		_ = int(time.Since(start).Milliseconds()) // per-try latency placeholder
		cancel()

		ok := false
		if err == nil && resp != nil {
			// body assertion only if needed; limit to 256KiB
			bodyOK := true
			if needle != "" {
				const maxRead = 256 * 1024
				b, _ := io.ReadAll(io.LimitReader(resp.Body, maxRead))
				bodyOK = bytes.Contains(b, []byte(needle))
			}
			if resp.Body != nil {
				resp.Body.Close()
			}
			ok = (resp.StatusCode == expected) && bodyOK
		} else {
			if resp != nil && resp.Body != nil {
				resp.Body.Close()
			}
		}

		if ok {
			statusStr = "OK"
			break
		}
		// backoff if more attempts remain
		if i < tryCount-1 {
			time.Sleep(time.Duration(backoffMs) * time.Millisecond)
		}
	}

	return StatusResult{
		ID:         svc.ID,
		Name:       svc.Name,
		URL:        svc.URL,
		Status:     statusStr,                                  // "OK"/"FAIL"
		ResponseMs: int(time.Since(totalStart).Milliseconds()), // total wall time incl. retries
		CheckedAt:  time.Now().UTC().Format(time.RFC3339),
	}
}

// AddService creates a service with reliability settings and starts its checker.
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
		retries = 0
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
		ID:             id,
		Name:           name,
		URL:            url,
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
		close(stopChan) // signal checker to stop
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
