package store

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"time"

	"edith-engine/internal/vault"
)

// IndexedNote represents a note's metadata persisted in the SQLite store.
type IndexedNote struct {
	ID          int64     `json:"id"`
	RelPath     string    `json:"rel_path"`
	Title       string    `json:"title"`
	ModTime     time.Time `json:"mod_time"`
	ContentHash string    `json:"content_hash"`
	SizeBytes   int64     `json:"size_bytes"`
	IndexedAt   time.Time `json:"indexed_at"`
	Status      string    `json:"status"`
}

// StoreStats holds summary statistics about the indexed database.
type StoreStats struct {
	TotalNotes    int       `json:"total_notes"`
	LastIndexedAt time.Time `json:"last_indexed_at"`
	DBSizeBytes   int64     `json:"db_size_bytes"`
	DBPath        string    `json:"db_path"`
}

// GetNote retrieves metadata for a single note by its vault-relative path.
func (db *DB) GetNote(relPath string) (*IndexedNote, error) {
	row := db.conn.QueryRow(`
		SELECT id, rel_path, title, mod_time_unix, content_hash, size_bytes, indexed_at_unix, status
		FROM notes
		WHERE rel_path = ?;
	`, relPath)

	var n IndexedNote
	var modUnix, idxUnix int64
	err := row.Scan(&n.ID, &n.RelPath, &n.Title, &modUnix, &n.ContentHash, &n.SizeBytes, &idxUnix, &n.Status)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get note %s: %w", relPath, err)
	}

	n.ModTime = time.Unix(modUnix, 0).UTC()
	n.IndexedAt = time.Unix(idxUnix, 0).UTC()
	return &n, nil
}

// ListAllNotes returns all notes currently registered in the database.
func (db *DB) ListAllNotes() ([]*IndexedNote, error) {
	rows, err := db.conn.Query(`
		SELECT id, rel_path, title, mod_time_unix, content_hash, size_bytes, indexed_at_unix, status
		FROM notes
		ORDER BY rel_path ASC;
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query all notes: %w", err)
	}
	defer rows.Close()

	var notes []*IndexedNote
	for rows.Next() {
		var n IndexedNote
		var modUnix, idxUnix int64
		if err := rows.Scan(&n.ID, &n.RelPath, &n.Title, &modUnix, &n.ContentHash, &n.SizeBytes, &idxUnix, &n.Status); err != nil {
			return nil, fmt.Errorf("error scanning note row: %w", err)
		}
		n.ModTime = time.Unix(modUnix, 0).UTC()
		n.IndexedAt = time.Unix(idxUnix, 0).UTC()
		notes = append(notes, &n)
	}

	return notes, rows.Err()
}

// IndexNote writes or updates both the metadata record in `notes`
// and the full-text search content in `notes_fts` atomically.
func (db *DB) IndexNote(note *vault.Note) error {
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	nowUnix := time.Now().UTC().Unix()
	modUnix := note.Metadata.ModTime.UTC().Unix()

	// Upsert note metadata
	_, err = tx.Exec(`
		INSERT INTO notes (rel_path, title, mod_time_unix, content_hash, size_bytes, indexed_at_unix, status)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(rel_path) DO UPDATE SET
			title = excluded.title,
			mod_time_unix = excluded.mod_time_unix,
			content_hash = excluded.content_hash,
			size_bytes = excluded.size_bytes,
			indexed_at_unix = excluded.indexed_at_unix,
			status = excluded.status;
	`, note.Metadata.RelPath, note.Metadata.Title, modUnix, note.Metadata.ContentHash, note.Metadata.SizeBytes, nowUnix, "indexed")
	if err != nil {
		return fmt.Errorf("failed to upsert note metadata: %w", err)
	}

	// Update FTS index
	_, err = tx.Exec(`DELETE FROM notes_fts WHERE rel_path = ?;`, note.Metadata.RelPath)
	if err != nil {
		return fmt.Errorf("failed to clear existing FTS entry: %w", err)
	}

	_, err = tx.Exec(`
		INSERT INTO notes_fts (rel_path, title, content)
		VALUES (?, ?, ?);
	`, note.Metadata.RelPath, note.Metadata.Title, note.Content)
	if err != nil {
		return fmt.Errorf("failed to insert FTS entry: %w", err)
	}

	return tx.Commit()
}

// DeleteNote removes a note from both the metadata table and FTS index.
// Note: This modifies the SQLite index only; it never touches any file on disk.
func (db *DB) DeleteNote(relPath string) error {
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DELETE FROM notes WHERE rel_path = ?;`, relPath); err != nil {
		return fmt.Errorf("failed to delete from notes: %w", err)
	}

	if _, err := tx.Exec(`DELETE FROM notes_fts WHERE rel_path = ?;`, relPath); err != nil {
		return fmt.Errorf("failed to delete from notes_fts: %w", err)
	}

	return tx.Commit()
}

// ClearAllNotes clears all note records and full-text search entries.
func (db *DB) ClearAllNotes() error {
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DELETE FROM notes;`); err != nil {
		return fmt.Errorf("failed to clear notes: %w", err)
	}

	if _, err := tx.Exec(`DELETE FROM notes_fts;`); err != nil {
		return fmt.Errorf("failed to clear notes_fts: %w", err)
	}

	return tx.Commit()
}

// GetStats returns summary information about the current index state.
func (db *DB) GetStats() (*StoreStats, error) {
	row := db.conn.QueryRow(`
		SELECT COUNT(*), COALESCE(MAX(indexed_at_unix), 0)
		FROM notes;
	`)

	var totalNotes int
	var maxIndexedUnix int64
	if err := row.Scan(&totalNotes, &maxIndexedUnix); err != nil {
		return nil, fmt.Errorf("failed to read stats: %w", err)
	}

	var sizeBytes int64
	if db.dbPath != ":memory:" {
		info, err := os.Stat(db.dbPath)
		if err == nil {
			sizeBytes = info.Size()
		}
	}

	var lastIndexed time.Time
	if maxIndexedUnix > 0 {
		lastIndexed = time.Unix(maxIndexedUnix, 0).UTC()
	}

	return &StoreStats{
		TotalNotes:    totalNotes,
		LastIndexedAt: lastIndexed,
		DBSizeBytes:   sizeBytes,
		DBPath:        db.dbPath,
	}, nil
}
