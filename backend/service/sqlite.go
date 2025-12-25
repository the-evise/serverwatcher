package service

import (
	"database/sql"

	_ "github.com/mattn/go-sqlite3"
)

type SQLStore struct {
	DB *sql.DB
}

func OpenSQLite(path string) (*SQLStore, error) {
	db, err := sql.Open("sqlite3", path+"?_busy_timeout=5000&_journal_mode=WAL")
	if err != nil {
		return nil, err
	}
	return &SQLStore{DB: db}, nil
}
