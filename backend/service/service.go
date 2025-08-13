package service

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"
)

const persistenceFile = "serverwatcher_data.json"

// / --- MODELS --- /
// Service represents a monitored target.
type Service struct {
	ID       int           `json:"id"`
	Name     string        `json:"name"`
	URL      string        `json:"url"`
	Interval time.Duration `json:"interval"` // check interval in seconds
	Active   bool          `json:"active"`
}

// StatusResult represents the latest status of a monitored service
type StatusResult struct {
	ID         int    `json:"id"`
	Name       string `json:"name"`
	URL        string `json:"url"`
	Status     string `json:"status"` // "OK" or "FAIL"
	ResponseMs int    `json:"responseMs"`
	CheckedAt  string `json:"checkedAt"` // RFC3339
}

type Incident struct {
	ID        int        `json:"id"`
	ServiceID int        `json:"serviceId"`
	StartedAt time.Time  `json:"startedAt"`
	EndedAt   *time.Time `json:"endedAt,omitempty"`
	DurationS int        `json:"durationS"` // filled when closed
}

type Analytics struct {
	ServiceID     int     `json:"serviceId"`
	WindowStart   string  `json:"windowStart"`
	WindowEnd     string  `json:"windowEnd"`
	Checks        int     `json:"checks"`
	UptimePercent float64 `json:"uptimePercent"`
	AvgResponseMs int     `json:"avgResponseMs"`
	FailCount     int     `json:"failCount"`
	IncidentCount int     `json:"incidentCount"`
	MTTRSeconds   int     `json:"mttrSeconds"`
}

// / / --- STORE --- /
type Store struct {
	sync.Mutex
	services  map[int]*Service
	statuses  map[int]StatusResult
	histories map[int][]StatusResult

	Incidents    map[int][]*Incident // serviceID -> incidents
	lastStatus   map[int]string      // latest status snapshot
	openIncident map[int]*Incident   // currently open incident (if any)

	nextID         int
	nextIncidentID int
	stopChans      map[int]chan struct{}

	lastNotifiedStatus map[int]string

	failStreak  map[int]int
	okStreak    map[int]int
	firstFailAt map[int]time.Time
	lastAlertAt map[int]time.Time

	policy IncidentPolicy
}

type storeData struct {
	Services           map[int]*Service       `json:"services"`
	Histories          map[int][]StatusResult `json:"histories"`
	Statuses           map[int]StatusResult   `json:"statuses"`
	Incidents          map[int][]*Incident    `json:"incidents"`
	LastStatus         map[int]string         `json:"lastStatus"`
	LastNotifiedStatus map[int]string         `json:"lastNotifiedStatus"`
	NextID             int                    `json:"nextId"`
	NextIncidentID     int                    `json:"nextIncidentId"`

	// (We intentionally DO NOT persist streaks/cooldowns; they’re runtime-only)
	Policy IncidentPolicy `json:"policy"`
}

func NewStore() *Store {
	s := &Store{
		nextID: 1, nextIncidentID: 1,
	}
	s.ensureMaps()
	return s
}

func (s *Store) SetPolicy(p IncidentPolicy) {
	s.Lock()
	defer s.Unlock()
	s.policy = p
}

func (s *Store) ensureMaps() {
	if s.services == nil {
		s.services = make(map[int]*Service)
	}
	if s.statuses == nil {
		s.statuses = make(map[int]StatusResult)
	}
	if s.histories == nil {
		s.histories = make(map[int][]StatusResult)
	}
	if s.Incidents == nil {
		s.Incidents = make(map[int][]*Incident)
	}
	if s.lastStatus == nil {
		s.lastStatus = make(map[int]string)
	}
	if s.openIncident == nil {
		s.openIncident = make(map[int]*Incident)
	}
	if s.stopChans == nil {
		s.stopChans = make(map[int]chan struct{})
	}
	if s.lastNotifiedStatus == nil {
		s.lastNotifiedStatus = make(map[int]string)
	}

	if s.failStreak == nil {
		s.failStreak = make(map[int]int)
	}
	if s.okStreak == nil {
		s.okStreak = make(map[int]int)
	}
	if s.firstFailAt == nil {
		s.firstFailAt = make(map[int]time.Time)
	}
	if s.lastAlertAt == nil {
		s.lastAlertAt = make(map[int]time.Time)
	}
}

// / --- PERSISTENCE --- /
func (s *Store) SaveToFile() error {
	s.Lock()
	defer s.Unlock()
	data := storeData{
		Services:       s.services,
		Histories:      s.histories,
		Statuses:       s.statuses,
		Incidents:      s.Incidents,
		LastStatus:     s.lastStatus,
		NextID:         s.nextID,
		NextIncidentID: s.nextIncidentID,
		Policy:         s.policy,
	}
	f, err := os.Create(persistenceFile)
	if err != nil {
		return err
	}
	defer f.Close()
	return json.NewEncoder(f).Encode(&data)
}

func (s *Store) LoadFromFile() error {
	f, err := os.Open(persistenceFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	defer f.Close()
	var data storeData
	if err := json.NewDecoder(f).Decode(&data); err != nil {
		return err
	}

	s.services = data.Services
	s.histories = data.Histories
	s.statuses = data.Statuses
	s.Incidents = data.Incidents
	s.lastStatus = data.LastStatus
	s.nextID = data.NextID
	s.nextIncidentID = data.NextIncidentID
	s.policy = data.Policy
	s.policy = data.Policy
	if s.policy == (IncidentPolicy{}) {
		s.policy = defaultPolicy()
	}
	s.ensureMaps()

	// rebuild openIncident: last incident with nil EndedAt
	s.openIncident = make(map[int]*Incident)
	for sid, incs := range s.Incidents {
		if len(incs) == 0 {
			continue
		}
		last := incs[len(incs)-1]
		if last.EndedAt == nil {
			s.openIncident[sid] = last
		}
	}
	return nil
}

// / --- PUBLIC HELPERS --- /
func (s *Store) GetAllServices() []*Service {
	s.Lock()
	defer s.Unlock()
	out := make([]*Service, 0, len(s.services))
	for _, v := range s.services {
		out = append(out, v)
	}
	return out
}

func (s *Store) RestartChecker(svc *Service) {
	s.Lock()
	s.ensureMaps()
	// Stop existing checker for this service, if present
	if stopChan, ok := s.stopChans[svc.ID]; ok {
		close(stopChan)
	}
	// Start a new checker goroutine
	stopChan := make(chan struct{})
	s.stopChans[svc.ID] = stopChan

	// reset streaks for fresh config
	s.failStreak[svc.ID] = 0
	s.okStreak[svc.ID] = 0
	delete(s.firstFailAt, svc.ID)
	s.Unlock()
	go s.startChecker(svc, stopChan)
}

func (s *Store) UpdateService(id int, name, url string, interval int) error {
	s.Lock()
	defer s.Unlock()
	svc, ok := s.services[id]
	if !ok {
		return fmt.Errorf("service not found")
	}
	svc.Name = name
	svc.URL = url
	svc.Interval = time.Duration(interval) * time.Second

	// restart checker with new config
	if stopChan, ok := s.stopChans[id]; ok {
		close(stopChan)
	}
	stopChan := make(chan struct{})
	s.stopChans[id] = stopChan

	// reset streaks on update
	s.failStreak[id] = 0
	s.okStreak[id] = 0
	delete(s.firstFailAt, id)

	go s.startChecker(svc, stopChan)
	return nil
}

func (s *Store) GetIncidents(id int) ([]*Incident, bool) {
	s.Lock()
	defer s.Unlock()
	incs, ok := s.Incidents[id]
	return incs, ok
}

// time-weighted analytics
func (s *Store) ComputeAnalytics(id int, hours int) Analytics {
	s.Lock()
	hist := s.histories[id]
	incs := s.Incidents[id]
	s.Unlock()

	windowEnd := time.Now().UTC()
	windowStart := windowEnd.Add(-time.Duration(hours) * time.Hour)
	windowDur := windowEnd.Sub(windowStart).Seconds()
	if windowDur <= 0 {
		windowDur = 1
	}

	downSeconds := 0.0
	for _, inc := range incs {
		incStart := inc.StartedAt
		incEnd := windowEnd
		if inc.EndedAt != nil {
			incEnd = *inc.EndedAt
		}
		start := maxTime(incStart, windowStart)
		end := minTime(incEnd, windowEnd)
		if end.After(start) {
			downSeconds += end.Sub(start).Seconds()
		}
	}
	uptimePercent := 100.0 * (1.0 - (downSeconds / windowDur))
	if uptimePercent < 0 {
		uptimePercent = 0
	}
	if uptimePercent > 100 {
		uptimePercent = 100
	}

	// sample-based avg/failed count
	filtered := make([]StatusResult, 0, len(hist))
	for _, v := range hist {
		t, _ := time.Parse(time.RFC3339, v.CheckedAt)
		if t.After(windowStart) {
			filtered = append(filtered, v)
		}
	}
	checks := len(filtered)
	avgMs := 0
	failCount := 0
	if checks > 0 {
		sumMs, okCnt := 0, 0
		for _, v := range filtered {
			if v.Status == "OK" {
				okCnt++
				sumMs += v.ResponseMs
			} else {
				failCount++
			}
		}
		if okCnt > 0 {
			avgMs = sumMs / okCnt
		}
	}

	// MTTR & count
	mttrs, mttrCount := 0, 0
	for _, inc := range incs {
		if inc.EndedAt != nil && inc.EndedAt.After(windowStart) {
			mttrs += inc.DurationS
			mttrCount++
		}
	}
	mttr := 0
	if mttrCount > 0 {
		mttr = mttrs / mttrCount
	}

	return Analytics{
		ServiceID:     id,
		WindowStart:   windowStart.Format(time.RFC3339),
		WindowEnd:     windowEnd.Format(time.RFC3339),
		Checks:        checks,
		UptimePercent: uptimePercent,
		AvgResponseMs: avgMs,
		FailCount:     failCount,
		IncidentCount: mttrCount,
		MTTRSeconds:   mttr,
	}
}

func maxTime(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}
func minTime(a, b time.Time) time.Time {
	if a.Before(b) {
		return a
	}
	return b
}
