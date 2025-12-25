package service

import "time"

func (s *SQLStore) StartRetention(days int) {
	go func() {
		t := time.NewTicker(24 * time.Hour)
		defer t.Stop()
		for range t.C {
			cut := time.Now().Add(-time.Duration(days) * 24 * time.Hour).Format(time.RFC3339)
			_, _ = s.DB.Exec(`DELETE FROM checks WHERE ts < ?`, cut)
			// optionally compress incidents older than N months into rollups
		}
	}()
}
