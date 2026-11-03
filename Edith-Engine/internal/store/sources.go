package store

import (
	"database/sql"
	"fmt"
	"time"
)

// SourceRecord represents an immutable preserved external source artifact.
type SourceRecord struct {
	ID               string    `json:"id"`
	SourceIdentifier string    `json:"source_identifier"`
	ContentHash      string    `json:"content_hash"`
	Title            string    `json:"title"`
	Author           string    `json:"author"`
	URL              string    `json:"url"`
	RawContent       string    `json:"raw_content"`
	IngestedAt       time.Time `json:"ingested_at"`
}

// SaveSource stores a newly ingested source into the database.
func (db *DB) SaveSource(s *SourceRecord) error {
	query := `INSERT INTO sources (id, source_identifier, content_hash, title, author, url, raw_content, ingested_at_unix)
	          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
	_, err := db.conn.Exec(query, s.ID, s.SourceIdentifier, s.ContentHash, s.Title, s.Author, s.URL, s.RawContent, s.IngestedAt.Unix())
	if err != nil {
		return fmt.Errorf("failed to save source record: %w", err)
	}
	return nil
}

// GetSourceByHash retrieves an ingested source matching the given SHA-256 content hash.
func (db *DB) GetSourceByHash(hash string) (*SourceRecord, error) {
	query := `SELECT id, source_identifier, content_hash, title, author, url, raw_content, ingested_at_unix
	          FROM sources WHERE content_hash = ? LIMIT 1`
	row := db.conn.QueryRow(query, hash)

	var s SourceRecord
	var ingestedUnix int64
	err := row.Scan(&s.ID, &s.SourceIdentifier, &s.ContentHash, &s.Title, &s.Author, &s.URL, &s.RawContent, &ingestedUnix)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get source by hash: %w", err)
	}
	s.IngestedAt = time.Unix(ingestedUnix, 0).UTC()
	return &s, nil
}

// GetSourceByID retrieves an ingested source matching the given unique identifier.
func (db *DB) GetSourceByID(id string) (*SourceRecord, error) {
	query := `SELECT id, source_identifier, content_hash, title, author, url, raw_content, ingested_at_unix
	          FROM sources WHERE id = ? LIMIT 1`
	row := db.conn.QueryRow(query, id)

	var s SourceRecord
	var ingestedUnix int64
	err := row.Scan(&s.ID, &s.SourceIdentifier, &s.ContentHash, &s.Title, &s.Author, &s.URL, &s.RawContent, &ingestedUnix)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get source by id: %w", err)
	}
	s.IngestedAt = time.Unix(ingestedUnix, 0).UTC()
	return &s, nil
}

// ListSources returns all stored source records ordered by ingestion time descending.
func (db *DB) ListSources() ([]SourceRecord, error) {
	query := `SELECT id, source_identifier, content_hash, title, author, url, raw_content, ingested_at_unix
	          FROM sources ORDER BY ingested_at_unix DESC`
	rows, err := db.conn.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed listing sources: %w", err)
	}
	defer rows.Close()

	var records []SourceRecord
	for rows.Next() {
		var s SourceRecord
		var ingestedUnix int64
		if err := rows.Scan(&s.ID, &s.SourceIdentifier, &s.ContentHash, &s.Title, &s.Author, &s.URL, &s.RawContent, &ingestedUnix); err != nil {
			return nil, fmt.Errorf("failed scanning source row: %w", err)
		}
		s.IngestedAt = time.Unix(ingestedUnix, 0).UTC()
		records = append(records, s)
	}
	return records, rows.Err()
}
