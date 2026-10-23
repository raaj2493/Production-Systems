package store

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

// DB wraps the SQLite connection and provides repository methods.
type DB struct {
	conn   *sql.DB
	dbPath string
}

// Open initializes or connects to the SQLite database, applies pragmas,
// and ensures all required tables exist.
func Open(dbPath string) (*DB, error) {
	if dbPath == "" {
		return nil, fmt.Errorf("database path cannot be empty")
	}

	// In-memory support for testing
	if dbPath != ":memory:" {
		dir := filepath.Dir(dbPath)
		if err := os.MkdirAll(dir, 0755); err != nil {
			return nil, fmt.Errorf("failed to create database directory %s: %w", dir, err)
		}
	}

	// Open connection with sqlite driver
	conn, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open sqlite database at %s: %w", dbPath, err)
	}

	// Set connection pool settings suitable for SQLite
	conn.SetMaxOpenConns(1)
	conn.SetMaxIdleConns(1)
	conn.SetConnMaxLifetime(time.Hour)

	db := &DB{
		conn:   conn,
		dbPath: dbPath,
	}

	if err := db.applyPragmas(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to apply pragmas: %w", err)
	}

	if err := db.migrateSchema(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to migrate schema: %w", err)
	}

	return db, nil
}

// Close closes the underlying database connection.
func (db *DB) Close() error {
	if db.conn != nil {
		return db.conn.Close()
	}
	return nil
}

// Conn returns the raw sql.DB connection.
func (db *DB) Conn() *sql.DB {
	return db.conn
}

// DBPath returns the configured path to the database.
func (db *DB) DBPath() string {
	return db.dbPath
}

func (db *DB) applyPragmas() error {
	// Foreign keys, busy timeout, and WAL journal mode
	pragmas := []string{
		"PRAGMA foreign_keys = ON;",
		"PRAGMA busy_timeout = 5000;",
	}

	if db.dbPath != ":memory:" {
		pragmas = append(pragmas,
			"PRAGMA journal_mode = WAL;",
			"PRAGMA synchronous = NORMAL;",
		)
	}

	for _, p := range pragmas {
		if _, err := db.conn.Exec(p); err != nil {
			return fmt.Errorf("executing %q: %w", p, err)
		}
	}
	return nil
}
