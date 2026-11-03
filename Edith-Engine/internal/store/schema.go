package store

import (
	"database/sql"
	"fmt"
	"time"
)

type migration struct {
	version int
	name    string
	queries []string
}

var migrations = []migration{
	{
		version: 1,
		name:    "initial_schema",
		queries: []string{
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
		},
	},
	{
		version: 2,
		name:    "knowledge_graph_links",
		queries: []string{
			`CREATE TABLE IF NOT EXISTS note_links (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				source_path TEXT NOT NULL,
				target_path TEXT NOT NULL,
				raw_target TEXT NOT NULL,
				display_text TEXT NOT NULL,
				heading_anchor TEXT NOT NULL,
				is_wikilink INTEGER NOT NULL,
				line_number INTEGER NOT NULL
			);`,
			`CREATE INDEX IF NOT EXISTS idx_links_source ON note_links(source_path);`,
			`CREATE INDEX IF NOT EXISTS idx_links_target ON note_links(target_path);`,
			`CREATE INDEX IF NOT EXISTS idx_revisions_target ON proposal_revisions(target_path, applied_at_unix DESC);`,
		},
	},
	{
		version: 3,
		name:    "ingested_sources",
		queries: []string{
			`CREATE TABLE IF NOT EXISTS sources (
				id TEXT PRIMARY KEY,
				source_identifier TEXT NOT NULL,
				content_hash TEXT NOT NULL,
				title TEXT NOT NULL,
				author TEXT NOT NULL,
				url TEXT NOT NULL,
				raw_content TEXT NOT NULL,
				ingested_at_unix INTEGER NOT NULL
			);`,
			`CREATE INDEX IF NOT EXISTS idx_sources_hash ON sources(content_hash);`,
			`CREATE INDEX IF NOT EXISTS idx_sources_identifier ON sources(source_identifier);`,
		},
	},
	{
		version: 4,
		name:    "chat_conversations",
		queries: []string{
			`CREATE TABLE IF NOT EXISTS chat_conversations (
				id TEXT PRIMARY KEY,
				title TEXT NOT NULL,
				created_at_unix INTEGER NOT NULL,
				updated_at_unix INTEGER NOT NULL
			);`,
			`CREATE INDEX IF NOT EXISTS idx_chat_conversations_updated ON chat_conversations(updated_at_unix DESC);`,
			`CREATE TABLE IF NOT EXISTS chat_messages (
				id TEXT PRIMARY KEY,
				conversation_id TEXT NOT NULL,
				role TEXT NOT NULL,
				content TEXT NOT NULL,
				citations_json TEXT NOT NULL DEFAULT '[]',
				created_at_unix INTEGER NOT NULL,
				FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE
			);`,
			`CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation ON chat_messages(conversation_id, created_at_unix ASC);`,
		},
	},
}

func (db *DB) migrateSchema() error {
	// Create migration tracking table if not present
	_, err := db.conn.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		version INTEGER PRIMARY KEY,
		name TEXT NOT NULL,
		applied_at_unix INTEGER NOT NULL
	);`)
	if err != nil {
		return fmt.Errorf("failed to initialize schema_migrations table: %w", err)
	}

	for _, m := range migrations {
		var exists int
		err := db.conn.QueryRow(`SELECT 1 FROM schema_migrations WHERE version = ?;`, m.version).Scan(&exists)
		if err != nil && err != sql.ErrNoRows {
			return fmt.Errorf("failed checking migration status for version %d: %w", m.version, err)
		}
		if exists == 1 {
			continue // already applied
		}

		tx, err := db.conn.Begin()
		if err != nil {
			return fmt.Errorf("failed beginning transaction for migration %d (%s): %w", m.version, m.name, err)
		}

		for _, query := range m.queries {
			if _, err := tx.Exec(query); err != nil {
				tx.Rollback()
				return fmt.Errorf("error running migration %d query (%s): %w", m.version, query, err)
			}
		}

		nowUnix := time.Now().UTC().Unix()
		if _, err := tx.Exec(`INSERT INTO schema_migrations (version, name, applied_at_unix) VALUES (?, ?, ?);`,
			m.version, m.name, nowUnix); err != nil {
			tx.Rollback()
			return fmt.Errorf("failed recording migration %d: %w", m.version, err)
		}

		if err := tx.Commit(); err != nil {
			return fmt.Errorf("failed committing migration %d (%s): %w", m.version, m.name, err)
		}
	}

	return nil
}
