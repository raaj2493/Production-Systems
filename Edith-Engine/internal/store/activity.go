package store

import (
	"fmt"
	"time"
)

// ActivityRecord stores an operational event in the system audit log.
type ActivityRecord struct {
	ID              int64     `json:"id"`
	Timestamp       time.Time `json:"timestamp"`
	Operation       string    `json:"operation"`
	DiscoveredCount int       `json:"discovered_count"`
	ChangedCount    int       `json:"changed_count"`
	UnchangedCount  int       `json:"unchanged_count"`
	FailedCount     int       `json:"failed_count"`
	Details         string    `json:"details"`
}

// LogActivity records an operational log entry. Full note contents are never logged.
func (db *DB) LogActivity(op string, discovered, changed, unchanged, failed int, details string) error {
	nowUnix := time.Now().UTC().Unix()
	_, err := db.conn.Exec(`
		INSERT INTO activity_log (timestamp_unix, operation, discovered_count, changed_count, unchanged_count, failed_count, details)
		VALUES (?, ?, ?, ?, ?, ?, ?);
	`, nowUnix, op, discovered, changed, unchanged, failed, details)
	if err != nil {
		return fmt.Errorf("failed to write activity log: %w", err)
	}
	return nil
}

// ListActivity retrieves recent operational log records.
func (db *DB) ListActivity(limit int) ([]ActivityRecord, error) {
	if limit <= 0 {
		limit = 20
	}

	rows, err := db.conn.Query(`
		SELECT id, timestamp_unix, operation, discovered_count, changed_count, unchanged_count, failed_count, details
		FROM activity_log
		ORDER BY id DESC
		LIMIT ?;
	`, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query activity log: %w", err)
	}
	defer rows.Close()

	var logs []ActivityRecord
	for rows.Next() {
		var a ActivityRecord
		var tsUnix int64
		if err := rows.Scan(&a.ID, &tsUnix, &a.Operation, &a.DiscoveredCount, &a.ChangedCount, &a.UnchangedCount, &a.FailedCount, &a.Details); err != nil {
			return nil, fmt.Errorf("error scanning activity record: %w", err)
		}
		a.Timestamp = time.Unix(tsUnix, 0).UTC()
		logs = append(logs, a)
	}

	return logs, rows.Err()
}
