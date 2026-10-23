package proposals

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"edith-engine/internal/store"
	"edith-engine/internal/vault"
)

var (
	ErrProposalNotFound   = errors.New("proposal not found")
	ErrProposalNotPending = errors.New("proposal is not in pending status")
	ErrTargetConflict     = errors.New("target file was modified on disk since proposal was created")
)

// Service manages safe lifecycle transitions for proposed knowledge modifications.
type Service struct {
	vaultRoot string
	db        *store.DB
	reader    *vault.Reader
}

// NewService creates a new proposals management service.
func NewService(vaultRoot string, db *store.DB, reader *vault.Reader) *Service {
	return &Service{
		vaultRoot: filepath.Clean(vaultRoot),
		db:        db,
		reader:    reader,
	}
}

// CreateProposal constructs and persists a new change proposal against a target note.
func (s *Service) CreateProposal(targetPath, reason string, sourcePaths []string, proposedContent string) (*store.Proposal, error) {
	cleanRel := filepath.Clean(filepath.ToSlash(targetPath))
	if strings.HasPrefix(cleanRel, "..") || filepath.IsAbs(cleanRel) {
		return nil, fmt.Errorf("invalid target path: %s", targetPath)
	}

	// Verify target note on disk to obtain baseline hash
	var currentHash string
	existingNote, err := s.reader.ReadNote(cleanRel)
	if err == nil {
		currentHash = existingNote.Metadata.ContentHash
	} else if os.IsNotExist(err) || strings.Contains(err.Error(), "does not exist") {
		// New note proposal
		currentHash = "NEW_FILE"
	} else {
		return nil, fmt.Errorf("cannot verify target note %s: %w", cleanRel, err)
	}

	id := generateProposalID()
	proposal := &store.Proposal{
		ID:              id,
		TargetPath:      cleanRel,
		TargetHash:      currentHash,
		Reason:          reason,
		SourcePaths:     sourcePaths,
		ProposedContent: proposedContent,
		Status:          "pending",
		CreatedAt:       time.Now().UTC(),
	}

	if err := s.db.SaveProposal(proposal); err != nil {
		return nil, fmt.Errorf("failed to save proposal: %w", err)
	}

	_ = s.db.LogActivity("proposal_create", 0, 0, 0, 0, fmt.Sprintf("Created proposal %s for %s", id, cleanRel))
	return proposal, nil
}

// ListProposals returns proposals matching the specified filter ("pending", "approved", "rejected", or "" for all).
func (s *Service) ListProposals(filter string) ([]*store.Proposal, error) {
	return s.db.ListProposals(filter)
}

// GetProposal retrieves a proposal by ID.
func (s *Service) GetProposal(id string) (*store.Proposal, error) {
	p, err := s.db.GetProposal(id)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, ErrProposalNotFound
	}
	return p, nil
}

// Approve reviews and safely applies a proposed modification to disk.
// It verifies that:
// 1. Target path remains strictly inside the vault
// 2. Target file on disk has not diverged from its baseline hash
// 3. A recoverable backup snapshot is archived before writing
// 4. File write is atomic
// 5. Index is updated and operational activity logged
func (s *Service) Approve(id, reviewNotes string) error {
	p, err := s.GetProposal(id)
	if err != nil {
		return err
	}
	if p.Status != "pending" {
		return fmt.Errorf("%w: current status is %s", ErrProposalNotPending, p.Status)
	}

	targetAbs, err := vault.EnsureSafePath(s.vaultRoot, p.TargetPath)
	if err != nil {
		return fmt.Errorf("safety check failed for target: %w", err)
	}

	// Conflict Check
	var originalContent string
	var currentHash string
	existingNote, err := s.reader.ReadNote(p.TargetPath)
	if err == nil {
		originalContent = existingNote.Content
		currentHash = existingNote.Metadata.ContentHash
	} else if p.TargetHash != "NEW_FILE" {
		return fmt.Errorf("target note missing on disk: %w", err)
	}

	if p.TargetHash != "NEW_FILE" && currentHash != p.TargetHash {
		return fmt.Errorf("%w: expected hash %s, found %s on disk", ErrTargetConflict, p.TargetHash, currentHash)
	}

	// Save recoverable revision
	rev := &store.Revision{
		ProposalID:      p.ID,
		TargetPath:      p.TargetPath,
		OriginalContent: originalContent,
		OriginalHash:    currentHash,
		AppliedAt:       time.Now().UTC(),
	}
	if err := s.db.SaveRevision(rev); err != nil {
		return fmt.Errorf("failed to archive backup revision: %w", err)
	}

	// Atomic write to disk
	targetDir := filepath.Dir(targetAbs)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("failed to create target directory: %w", err)
	}

	tmpFile, err := os.CreateTemp(targetDir, ".edith_tmp_*")
	if err != nil {
		return fmt.Errorf("failed to create temporary file for atomic write: %w", err)
	}
	tmpName := tmpFile.Name()

	_, writeErr := tmpFile.WriteString(p.ProposedContent)
	syncErr := tmpFile.Sync()
	closeErr := tmpFile.Close()

	if writeErr != nil || syncErr != nil || closeErr != nil {
		_ = os.Remove(tmpName)
		return fmt.Errorf("failed writing proposal content: write=%v, sync=%v, close=%v", writeErr, syncErr, closeErr)
	}

	// Atomic replacement
	if err := os.Rename(tmpName, targetAbs); err != nil {
		_ = os.Remove(tmpName)
		return fmt.Errorf("failed to replace target file %s: %w", targetAbs, err)
	}

	// Re-read modified note and update index
	updatedNote, err := s.reader.ReadNote(p.TargetPath)
	if err == nil {
		_ = s.db.IndexNote(updatedNote)
	}

	// Update proposal status
	if err := s.db.UpdateProposalStatus(p.ID, "approved", reviewNotes); err != nil {
		return fmt.Errorf("failed updating proposal status: %w", err)
	}

	_ = s.db.LogActivity("proposal_approve", 0, 1, 0, 0, fmt.Sprintf("Approved and applied proposal %s for %s", p.ID, p.TargetPath))
	return nil
}

// Reject marks a proposal as rejected and logs the action.
// The target note on disk is never touched.
func (s *Service) Reject(id, reviewNotes string) error {
	p, err := s.GetProposal(id)
	if err != nil {
		return err
	}
	if p.Status != "pending" {
		return fmt.Errorf("%w: current status is %s", ErrProposalNotPending, p.Status)
	}

	if err := s.db.UpdateProposalStatus(p.ID, "rejected", reviewNotes); err != nil {
		return fmt.Errorf("failed updating proposal status: %w", err)
	}

	_ = s.db.LogActivity("proposal_reject", 0, 0, 0, 0, fmt.Sprintf("Rejected proposal %s for %s", p.ID, p.TargetPath))
	return nil
}

func generateProposalID() string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	return fmt.Sprintf("prop-%s-%s", time.Now().Format("20060102150405"), hex.EncodeToString(b))
}
