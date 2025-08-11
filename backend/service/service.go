package service

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"
)

const persistenceFile = "serverwatcher_data.json"

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

type Store struct {
	sync.Mutex
	services           map[int]*Service
	statuses           map[int]StatusResult
	histories          map[int][]StatusResult
	nextID             int
	stopChans          map[int]chan struct{}
	lastNotifiedStatus map[int]string
}

type storeData struct {
	Services  map[int]*Service       `json:"services"`
	Histories map[int][]StatusResult `json:"histories"`
	NextID    int                    `json:"nextId"`
}

func NewStore() *Store {
	return &Store{
		services:           make(map[int]*Service),
		statuses:           make(map[int]StatusResult),
		histories:          make(map[int][]StatusResult),
		nextID:             1,
		stopChans:          make(map[int]chan struct{}),
		lastNotifiedStatus: make(map[int]string),
	}
}

func (s *Store) SaveToFile() error {
	s.Lock()
	defer s.Unlock()
	data := storeData{
		Services:  s.services,
		Histories: s.histories,
		NextID:    s.nextID,
	}
	file, err := os.Create(persistenceFile)
	if err != nil {
		return err
	}
	defer file.Close()
	return json.NewEncoder(file).Encode(&data)
}

func (s *Store) LoadFromFile() error {
	file, err := os.Open(persistenceFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil // Not an error on first launch
		}
		return err
	}
	defer file.Close()
	var data storeData
	if err := json.NewDecoder(file).Decode(&data); err != nil {
		return err
	}
	s.services = data.Services
	s.histories = data.Histories
	s.nextID = data.NextID
	return nil
}

func (s *Store) GetAllServices() []*Service {
	s.Lock()
	defer s.Unlock()
	services := make([]*Service, 0, len(s.services))
	for _, svc := range s.services {
		services = append(services, svc)
	}
	return services
}

func (s *Store) RestartChecker(svc *Service) {
	s.Lock()
	defer s.Unlock()
	// Stop existing checker for this service, if present
	if stopChan, ok := s.stopChans[svc.ID]; ok {
		close(stopChan)
	}
	// Start a new checker goroutine
	stopChan := make(chan struct{})
	s.stopChans[svc.ID] = stopChan
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
	go s.startChecker(svc, stopChan)
	return nil
}
