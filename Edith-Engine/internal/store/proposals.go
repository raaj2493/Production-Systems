package store

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// Proposal represents a proposed change to a target note awaiting review.
type Proposal struct {
	ID              string    `json:"id"`
	TargetPath      string    `json:"target_path"`
	TargetHash      string    `json:"target_hash"`
	Reason          string    `json:"reason"`
	SourcePaths     []string  `json:"source_paths"`
	ProposedContent string    `json:"proposed_content"`
	Status          string    `json:"status"` // "pending", "approved", "rejected"
	CreatedAt       time.Time `json:"created_at"`
	ReviewedAt      time.Time `json:"reviewed_at"`
	ReviewNotes     string    `json:"review_notes"`
}

// Revision represents a historical backup snapshot of a note prior to an approved proposal.
type Revision struct {
	ID              int64     `json:"id"`
	ProposalID      string    `json:"proposal_id"`
	TargetPath      string    `json:"target_path"`
	OriginalContent string    `json:"original_content"`
	OriginalHash    string    `json:"original_hash"`
	AppliedAt       time.Time `json:"applied_at"`
}

// SaveProposal writes a new change proposal into the store.
func (db *DB) SaveProposal(p *Proposal) error {
	sourcesJSON, err := json.Marshal(p.SourcePaths)
	if err != nil {
		sourcesJSON = []byte("[]")
	}

	createdUnix := p.CreatedAt.UTC().Unix()
	var reviewedUnix int64
	if !p.ReviewedAt.IsZero() {
		reviewedUnix = p.ReviewedAt.UTC().Unix()
	}

	_, err = db.conn.Exec(`
		INSERT INTO proposals (id, target_path, target_hash, reason, source_paths, proposed_content, status, created_at_unix, reviewed_at_unix, review_notes)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			target_path = excluded.target_path,
			target_hash = excluded.target_hash,
			reason = excluded.reason,
			source_paths = excluded.source_paths,
			proposed_content = excluded.proposed_content,
			status = excluded.status,
			reviewed_at_unix = excluded.reviewed_at_unix,
			review_notes = excluded.review_notes;
	`, p.ID, p.TargetPath, p.TargetHash, p.Reason, string(sourcesJSON), p.ProposedContent, p.Status, createdUnix, reviewedUnix, p.ReviewNotes)
	if err != nil {
		return fmt.Errorf("failed to save proposal %s: %w", p.ID, err)
	}
	return nil
}

// GetProposal retrieves a proposal by its ID.
func (db *DB) GetProposal(id string) (*Proposal, error) {
	row := db.conn.QueryRow(`
		SELECT id, target_path, target_hash, reason, source_paths, proposed_content, status, created_at_unix, reviewed_at_unix, review_notes
		FROM proposals
		WHERE id = ?;
	`, id)

	var p Proposal
	var sourcesJSON string
	var createdUnix, reviewedUnix int64

	err := row.Scan(&p.ID, &p.TargetPath, &p.TargetHash, &p.Reason, &sourcesJSON, &p.ProposedContent, &p.Status, &createdUnix, &reviewedUnix, &p.ReviewNotes)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get proposal %s: %w", id, err)
	}

	_ = json.Unmarshal([]byte(sourcesJSON), &p.SourcePaths)
	p.CreatedAt = time.Unix(createdUnix, 0).UTC()
	if reviewedUnix > 0 {
		p.ReviewedAt = time.Unix(reviewedUnix, 0).UTC()
	}

	return &p, nil
}

// ListProposals lists proposals optionally filtered by status ("pending", "approved", "rejected", or "" for all).
func (db *DB) ListProposals(statusFilter string) ([]*Proposal, error) {
	var rows *sql.Rows
	var err error

	if statusFilter != "" {
		rows, err = db.conn.Query(`
			SELECT id, target_path, target_hash, reason, source_paths, proposed_content, status, created_at_unix, reviewed_at_unix, review_notes
			FROM proposals
			WHERE status = ?
			ORDER BY created_at_unix DESC;
		`, statusFilter)
	} else {
		rows, err = db.conn.Query(`
			SELECT id, target_path, target_hash, reason, source_paths, proposed_content, status, created_at_unix, reviewed_at_unix, review_notes
			FROM proposals
			ORDER BY created_at_unix DESC;
		`)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to list proposals: %w", err)
	}
	defer rows.Close()

	var proposals []*Proposal
	for rows.Next() {
		var p Proposal
		var sourcesJSON string
		var createdUnix, reviewedUnix int64

		if err := rows.Scan(&p.ID, &p.TargetPath, &p.TargetHash, &p.Reason, &sourcesJSON, &p.ProposedContent, &p.Status, &createdUnix, &reviewedUnix, &p.ReviewNotes); err != nil {
			return nil, fmt.Errorf("error scanning proposal: %w", err)
		}

		_ = json.Unmarshal([]byte(sourcesJSON), &p.SourcePaths)
		p.CreatedAt = time.Unix(createdUnix, 0).UTC()
		if reviewedUnix > 0 {
			p.ReviewedAt = time.Unix(reviewedUnix, 0).UTC()
		}

		proposals = append(proposals, &p)
	}

	return proposals, rows.Err()
}

// UpdateProposalStatus updates the status and review notes of a proposal.
func (db *DB) UpdateProposalStatus(id, status, reviewNotes string) error {
	nowUnix := time.Now().UTC().Unix()
	res, err := db.conn.Exec(`
		UPDATE proposals
		SET status = ?, reviewed_at_unix = ?, review_notes = ?
		WHERE id = ?;
	`, status, nowUnix, reviewNotes, id)
	if err != nil {
		return fmt.Errorf("failed to update proposal status: %w", err)
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("proposal not found: %s", id)
	}
	return nil
}

// SaveRevision preserves the previous content of a note before applying a change proposal.
func (db *DB) SaveRevision(r *Revision) error {
	appliedUnix := r.AppliedAt.UTC().Unix()
	_, err := db.conn.Exec(`
		INSERT INTO proposal_revisions (proposal_id, target_path, original_content, original_hash, applied_at_unix)
		VALUES (?, ?, ?, ?, ?);
	`, r.ProposalID, r.TargetPath, r.OriginalContent, r.OriginalHash, appliedUnix)
	if err != nil {
		return fmt.Errorf("failed to save revision record: %w", err)
	}
	return nil
}
