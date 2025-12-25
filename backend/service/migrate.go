package service

func (s *SQLStore) Migrate() error {
	_, err := s.DB.Exec(`
CREATE TABLE IF NOT EXISTS services(
 id INTEGER PRIMARY KEY,
 name TEXT, url TEXT, interval_s INTEGER, active INTEGER,
 timeout_ms INTEGER, retries INTEGER, backoff_ms INTEGER,
 expected_status INTEGER, contains TEXT,
 slo_target REAL, public INTEGER, tags TEXT
);
CREATE TABLE IF NOT EXISTS checks(
 service_id INTEGER, ts TEXT, status TEXT, latency_ms INTEGER,
 PRIMARY KEY(service_id, ts)
);
CREATE TABLE IF NOT EXISTS incidents(
 id INTEGER PRIMARY KEY,
 service_id INTEGER, started_at TEXT, ended_at TEXT, duration_s INTEGER, reason TEXT
);
CREATE TABLE IF NOT EXISTS silences(
 id INTEGER PRIMARY KEY, service_id INTEGER, tag TEXT, until TEXT, reason TEXT, created_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_checks_service_ts ON checks(service_id, ts);
CREATE INDEX IF NOT EXISTS idx_incidents_service_start ON incidents(service_id, started_at);
`)
	return err
}
