package service

import "time"

type Silence struct {
	ID        int       `json:"id"`
	ServiceID *int      `json:"serviceId,omitempty"` // service-targeted
	Tag       string    `json:"tag,omitempty"`       // or by tag
	Until     time.Time `json:"until"`               // when silence ends
	Reason    string    `json:"reason,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
}

func (s *Store) IsSilenced(svc *Service) bool {
	s.Lock()
	defer s.Unlock()
	now := time.Now()
	for _, sil := range s.silences {
		if now.After(sil.Until) {
			continue
		}
		if sil.ServiceID != nil && *sil.ServiceID == svc.ID {
			return true
		}
		if sil.Tag != "" {
			for _, t := range svc.Tags {
				if t == sil.Tag {
					return true
				}
			}
		}
	}
	return false
}

func (s *Store) NewSilence(sid *int, tag string, until time.Time, reason string) *Silence {
	s.Lock()
	defer s.Unlock()
	s.nextSilenceID++
	sl := &Silence{ID: s.nextSilenceID, ServiceID: sid, Tag: tag, Until: until, Reason: reason, CreatedAt: time.Now()}
	s.silences = append(s.silences, sl)
	_ = s.SaveToFile()
	return sl
}
func (s *Store) ListSilences() []*Silence {
	s.Lock()
	defer s.Unlock()
	out := make([]*Silence, len(s.silences))
	copy(out, s.silences)
	return out
}
func (s *Store) DeleteSilence(id int) bool {
	s.Lock()
	defer s.Unlock()
	for i, x := range s.silences {
		if x.ID == id {
			s.silences = append(s.silences[:i], s.silences[i+1:]...)
			_ = s.SaveToFile()
			return true
		}
	}
	return false
}
