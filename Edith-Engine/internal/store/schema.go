package store

import (
	"fmt"
)

func (db *DB) migrateSchema() error {
	schemaQueries := []string{
		`CREATE TABLE IF NOT EXISTS notes (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			rel_path TEXT UNIQUE NOT NULL,
			title TEXT NOT NULL,
			mod_time_unix INTEGER NOT NULL,
			content_hash TEXT NOT NULL,
			size_bytes INTEGER NOT NULL,
			indexed_at_unix INTEGER NOT NULL,
			status TEXT NOT NULL
		);`,

		`CREATE INDEX IF NOT EXISTS idx_notes_rel_path ON notes(rel_path);`,
		`CREATE INDEX IF NOT EXISTS idx_notes_content_hash ON notes(content_hash);`,

		`CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
			rel_path UNINDEXED,
			title,
			content,
			tokenize = 'unicode61 remove_diacritics 1'
		);`,

		`CREATE TABLE IF NOT EXISTS activity_log (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			timestamp_unix INTEGER NOT NULL,
			operation TEXT NOT NULL,
			discovered_count INTEGER DEFAULT 0,
			changed_count INTEGER DEFAULT 0,
			unchanged_count INTEGER DEFAULT 0,
			failed_count INTEGER DEFAULT 0,
			details TEXT NOT NULL
		);`,

		`CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log(timestamp_unix DESC);`,

		`CREATE TABLE IF NOT EXISTS proposals (
			id TEXT PRIMARY KEY,
			target_path TEXT NOT NULL,
			target_hash TEXT NOT NULL,
			reason TEXT NOT NULL,
			source_paths TEXT NOT NULL,
			proposed_content TEXT NOT NULL,
			status TEXT NOT NULL,
			created_at_unix INTEGER NOT NULL,
			reviewed_at_unix INTEGER DEFAULT 0,
			review_notes TEXT DEFAULT ''
		);`,

		`CREATE INDEX IF NOT EXISTS idx_proposals_status ON proposals(status);`,

		`CREATE TABLE IF NOT EXISTS proposal_revisions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			proposal_id TEXT NOT NULL,
			target_path TEXT NOT NULL,
			original_content TEXT NOT NULL,
			original_hash TEXT NOT NULL,
			applied_at_unix INTEGER NOT NULL,
			FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE
		);`,
	}

	for _, query := range schemaQueries {
		if _, err := db.conn.Exec(query); err != nil {
			return fmt.Errorf("error running migration query (%s): %w", query, err)
		}
	}

	return nil
}
