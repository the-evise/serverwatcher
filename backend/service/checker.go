package service

import (
	"fmt"
	"net/http"
	"time"
)

func (s *Store) AddService(name, url string, intervalSec int) int {
	s.Lock()
	id := s.nextID
	svc := &Service{
		ID:       id,
		Name:     name,
		URL:      url,
		Interval: time.Duration(intervalSec) * time.Second,
		Active:   true,
	}
	s.services[id] = svc
	s.nextID++
	stopChan := make(chan struct{})
	s.stopChans[id] = stopChan
	s.Unlock()

	go s.startChecker(svc, stopChan)
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

func (s *Store) startChecker(svc *Service, stopChan chan struct{}) {
	ticker := time.NewTicker(svc.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			status := checkService(svc)
			s.Lock()
			s.statuses[svc.ID] = status

			// append to history
			var maxHistory int8 = 100
			h := s.histories[svc.ID]
			h = append(h, status)
			if len(h) > int(maxHistory) {
				h = h[len(h)-int(maxHistory):]
			}
			s.histories[svc.ID] = h

			prevStatus := s.lastNotifiedStatus[svc.ID]
			if status.Status != prevStatus {
				// Only notify on change (OK->FAIL or FAIL->OK)
				go SendTelegramNotification(fmt.Sprintf(
					"[Serverwatcher]\nService: %s\nURL: %s\nStatus: %s\nResponse: %d ms\nTime: %s",
					svc.Name, svc.URL, status.Status, status.ResponseMs, status.CheckedAt,
				))
				s.lastNotifiedStatus[svc.ID] = status.Status
			}

			s.Unlock()
		case <-stopChan:
			return
		}
	}
}

func checkService(svc *Service) StatusResult {
	start := time.Now()
	resp, err := http.Get(svc.URL)
	ms := int(time.Since(start).Milliseconds())

	status := "OK"
	if err != nil || resp.StatusCode < 200 || resp.StatusCode >= 400 {
		status = "FAIL"
	}
	if resp != nil {
		resp.Body.Close()
	}

	return StatusResult{
		ID:         svc.ID,
		Name:       svc.Name,
		URL:        svc.URL,
		Status:     status,
		ResponseMs: ms,
		CheckedAt:  time.Now().UTC().Format(time.RFC3339),
	}
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
