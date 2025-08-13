package service

import (
	"encoding/json"
	"os"
)

type IncidentPolicy struct {
	OpenConsecutiveFails int `json:"openConsecutiveFails"`
	OpenSeconds          int `json:"openSeconds"`
	CloseConsecutiveOKs  int `json:"closeConsecutiveOKs"`
	AlertCooldownSec     int `json:"alertCooldownSec"`
}

func defaultPolicy() IncidentPolicy {
	return IncidentPolicy{
		OpenConsecutiveFails: 2,
		OpenSeconds:          5,
		CloseConsecutiveOKs:  1,
		AlertCooldownSec:     60,
	}
}

func (s *Store) GetPolicy() IncidentPolicy {
	s.Lock()
	defer s.Unlock()
	return s.policy
}

func (s *Store) UpdatePolicy(newP IncidentPolicy) {
	s.Lock()
	defer s.Unlock()
	s.policy = newP
}

// For persistence in storeData
func (s *Store) SavePolicyToFile(file string) error {
	s.Lock()
	defer s.Unlock()
	f, err := os.Create(file)
	if err != nil {
		return err
	}
	defer f.Close()
	return json.NewEncoder(f).Encode(s.policy)
}

func (s *Store) LoadPolicyFromFile(file string) error {
	s.Lock()
	defer s.Unlock()
	f, err := os.Open(file)
	if err != nil {
		if os.IsNotExist(err) {
			s.policy = defaultPolicy()
			return nil
		}
		return err
	}
	defer f.Close()
	return json.NewDecoder(f).Decode(&s.policy)
}
