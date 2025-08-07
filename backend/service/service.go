package service

import (
	"sync"
	"time"
)

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
	CheckedAt  string `json:"checkedAt"`
}

type Store struct {
	sync.Mutex
	services  map[int]*Service
	statuses  map[int]StatusResult
	histories map[int][]StatusResult
	nextID    int
	stopChans map[int]chan struct{}
}

func NeweStore() *Store {
	return &Store{
		services:  make(map[int]*Service),
		statuses:  make(map[int]StatusResult),
		histories: make(map[int][]StatusResult),
		nextID:    1,
		stopChans: make(map[int]chan struct{}),
	}
}
