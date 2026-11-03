package store

import (
	"database/sql"
	"fmt"
)

// NoteLink represents a directed relationship between notes.
type NoteLink struct {
	ID            int64  `json:"id"`
	SourcePath    string `json:"source_path"`
	TargetPath    string `json:"target_path"` // empty string if unresolved/broken
	RawTarget     string `json:"raw_target"`
	DisplayText   string `json:"display_text"`
	HeadingAnchor string `json:"heading_anchor"`
	IsWikiLink    bool   `json:"is_wikilink"`
	LineNumber    int    `json:"line_number"`
}

// SaveNoteLinks persists all links originating from a source note.
// It atomically replaces any prior links for this source_path.
func (db *DB) SaveNoteLinks(sourcePath string, links []NoteLink) error {
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed starting transaction: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DELETE FROM note_links WHERE source_path = ?;`, sourcePath); err != nil {
		return fmt.Errorf("failed clearing prior links for %s: %w", sourcePath, err)
	}

	stmt, err := tx.Prepare(`
		INSERT INTO note_links (source_path, target_path, raw_target, display_text, heading_anchor, is_wikilink, line_number)
		VALUES (?, ?, ?, ?, ?, ?, ?);
	`)
	if err != nil {
		return fmt.Errorf("failed preparing link statement: %w", err)
	}
	defer stmt.Close()

	for _, l := range links {
		isWiki := 0
		if l.IsWikiLink {
			isWiki = 1
		}
		if _, err := stmt.Exec(sourcePath, l.TargetPath, l.RawTarget, l.DisplayText, l.HeadingAnchor, isWiki, l.LineNumber); err != nil {
			return fmt.Errorf("failed inserting link from %s to %s: %w", sourcePath, l.RawTarget, err)
		}
	}

	return tx.Commit()
}

// DeleteNoteLinks removes all links originating from sourcePath.
func (db *DB) DeleteNoteLinks(sourcePath string) error {
	_, err := db.conn.Exec(`DELETE FROM note_links WHERE source_path = ?;`, sourcePath)
	return err
}

// ClearAllNoteLinks truncates the note_links table.
func (db *DB) ClearAllNoteLinks() error {
	_, err := db.conn.Exec(`DELETE FROM note_links;`)
	return err
}

// InvalidateTargetLinks sets target_path = ” for any links pointing to a deleted note.
func (db *DB) InvalidateTargetLinks(deletedPath string) error {
	_, err := db.conn.Exec(`UPDATE note_links SET target_path = '' WHERE target_path = ?;`, deletedPath)
	return err
}

// ResolveTargetLinks updates target_path for links matching rawTarget or cleanTarget.
func (db *DB) ResolveTargetLinks(rawTarget, targetPath string) error {
	_, err := db.conn.Exec(`UPDATE note_links SET target_path = ? WHERE target_path = '' AND raw_target = ?;`, targetPath, rawTarget)
	return err
}

// GetOutgoingLinks returns all outgoing links from a source note.
func (db *DB) GetOutgoingLinks(sourcePath string) ([]NoteLink, error) {
	rows, err := db.conn.Query(`
		SELECT id, source_path, target_path, raw_target, display_text, heading_anchor, is_wikilink, line_number
		FROM note_links
		WHERE source_path = ?
		ORDER BY line_number ASC;
	`, sourcePath)
	if err != nil {
		return nil, fmt.Errorf("failed querying outgoing links for %s: %w", sourcePath, err)
	}
	defer rows.Close()

	return scanLinks(rows)
}

// GetBacklinks returns all incoming links pointing to targetPath.
func (db *DB) GetBacklinks(targetPath string) ([]NoteLink, error) {
	rows, err := db.conn.Query(`
		SELECT id, source_path, target_path, raw_target, display_text, heading_anchor, is_wikilink, line_number
		FROM note_links
		WHERE target_path = ?
		ORDER BY source_path ASC, line_number ASC;
	`, targetPath)
	if err != nil {
		return nil, fmt.Errorf("failed querying backlinks for %s: %w", targetPath, err)
	}
	defer rows.Close()

	return scanLinks(rows)
}

// GetAllNoteLinks returns all links currently recorded in the database.
func (db *DB) GetAllNoteLinks() ([]NoteLink, error) {
	rows, err := db.conn.Query(`
		SELECT id, source_path, target_path, raw_target, display_text, heading_anchor, is_wikilink, line_number
		FROM note_links
		ORDER BY source_path ASC, line_number ASC;
	`)
	if err != nil {
		return nil, fmt.Errorf("failed querying all links: %w", err)
	}
	defer rows.Close()

	return scanLinks(rows)
}

// GetBrokenLinks returns links whose target could not be resolved to an existing note.
func (db *DB) GetBrokenLinks() ([]NoteLink, error) {
	rows, err := db.conn.Query(`
		SELECT id, source_path, target_path, raw_target, display_text, heading_anchor, is_wikilink, line_number
		FROM note_links
		WHERE target_path = ''
		ORDER BY source_path ASC, line_number ASC;
	`)
	if err != nil {
		return nil, fmt.Errorf("failed querying broken links: %w", err)
	}
	defer rows.Close()

	return scanLinks(rows)
}

// GetOrphanNotes returns notes that have 0 incoming backlinks.
func (db *DB) GetOrphanNotes() ([]string, error) {
	rows, err := db.conn.Query(`
		SELECT n.rel_path
		FROM notes n
		WHERE n.rel_path NOT IN (
			SELECT DISTINCT target_path FROM note_links WHERE target_path != ''
		)
		ORDER BY n.rel_path ASC;
	`)
	if err != nil {
		return nil, fmt.Errorf("failed querying orphan notes: %w", err)
	}
	defer rows.Close()

	var orphans []string
	for rows.Next() {
		var p string
		if err := rows.Scan(&p); err != nil {
			return nil, err
		}
		orphans = append(orphans, p)
	}
	return orphans, rows.Err()
}

func scanLinks(rows *sql.Rows) ([]NoteLink, error) {
	var links []NoteLink
	for rows.Next() {
		var l NoteLink
		var isWiki int
		if err := rows.Scan(&l.ID, &l.SourcePath, &l.TargetPath, &l.RawTarget, &l.DisplayText, &l.HeadingAnchor, &isWiki, &l.LineNumber); err != nil {
			return nil, fmt.Errorf("error scanning link: %w", err)
		}
		l.IsWikiLink = (isWiki == 1)
		links = append(links, l)
	}
	return links, rows.Err()
}
