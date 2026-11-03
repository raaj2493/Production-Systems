package proposals

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"edith-engine/internal/store"
	"edith-engine/internal/vault"
)

var (
	ErrProposalNotFound   = errors.New("proposal not found")
	ErrProposalNotPending = errors.New("proposal is not in pending status")
	ErrTargetConflict     = errors.New("target file was modified on disk since proposal was created")
	ErrRevisionNotFound   = errors.New("revision not found")
)

// Service manages safe lifecycle transitions for proposed knowledge modifications.
type Service struct {
	vaultRoot   string
	db          *store.DB
	reader      *vault.Reader
	targetLocks sync.Map
}

// NewService creates a new proposals management service.
func NewService(vaultRoot string, db *store.DB, reader *vault.Reader) *Service {
	return &Service{
		vaultRoot: filepath.Clean(vaultRoot),
		db:        db,
		reader:    reader,
	}
}

func (s *Service) getTargetLock(targetPath string) *sync.Mutex {
	actual, _ := s.targetLocks.LoadOrStore(targetPath, &sync.Mutex{})
	return actual.(*sync.Mutex)
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

// ListProposals returns proposals matching the specified filter ("pending", "approved", "rejected", "conflict", "failed", or "" for all).
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
// 2. Concurrency lock is acquired for the target note to prevent race conditions
// 3. Status is re-validated within the lock (idempotent, no double-apply)
// 4. Target file on disk has not diverged from its baseline hash (conflict recorded on divergence)
// 5. A recoverable backup snapshot is archived before writing
// 6. File write is atomic via fsync and temporary file replacement
// 7. Index is updated and operational activity logged
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

	// Acquire per-target lock to prevent concurrent approval races on the same file
	lock := s.getTargetLock(p.TargetPath)
	lock.Lock()
	defer lock.Unlock()

	// Re-verify proposal status within lock
	p, err = s.GetProposal(id)
	if err != nil {
		return err
	}
	if p.Status != "pending" {
		return fmt.Errorf("%w: current status is %s", ErrProposalNotPending, p.Status)
	}

	// Conflict Check
	var originalContent string
	var currentHash string
	existingNote, err := s.reader.ReadNote(p.TargetPath)
	if err == nil {
		originalContent = existingNote.Content
		currentHash = existingNote.Metadata.ContentHash
	} else if p.TargetHash != "NEW_FILE" {
		// Expected existing file is missing on disk -> conflict
		_ = s.db.UpdateProposalStatus(p.ID, "conflict", fmt.Sprintf("Conflict: target note %s missing on disk", p.TargetPath))
		_ = s.db.LogActivity("proposal_conflict", 0, 0, 0, 1, fmt.Sprintf("Target missing for proposal %s (%s)", p.ID, p.TargetPath))
		return fmt.Errorf("target note missing on disk: %w", err)
	}

	if p.TargetHash != "NEW_FILE" && currentHash != p.TargetHash {
		// Target file was modified on disk since proposal creation -> record conflict
		_ = s.db.UpdateProposalStatus(p.ID, "conflict", fmt.Sprintf("Conflict: expected hash %s, found %s on disk", p.TargetHash, currentHash))
		_ = s.db.LogActivity("proposal_conflict", 0, 0, 0, 1, fmt.Sprintf("Conflict on proposal %s for %s", p.ID, p.TargetPath))
		return fmt.Errorf("%w: expected hash %s, found %s on disk", ErrTargetConflict, p.TargetHash, currentHash)
	}

	// Save recoverable revision before any destructive file replacement
	rev := &store.Revision{
		ProposalID:      p.ID,
		TargetPath:      p.TargetPath,
		OriginalContent: originalContent,
		OriginalHash:    currentHash,
		AppliedAt:       time.Now().UTC(),
	}
	if err := s.db.SaveRevision(rev); err != nil {
		_ = s.db.UpdateProposalStatus(p.ID, "failed", fmt.Sprintf("Failed to archive backup revision: %v", err))
		_ = s.db.LogActivity("proposal_failed", 0, 0, 0, 1, fmt.Sprintf("Backup archive failed for proposal %s: %v", p.ID, err))
		return fmt.Errorf("failed to archive backup revision: %w", err)
	}

	// Atomic write to disk via temporary file in target directory
	targetDir := filepath.Dir(targetAbs)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		_ = s.db.UpdateProposalStatus(p.ID, "failed", fmt.Sprintf("Directory creation error: %v", err))
		return fmt.Errorf("failed to create target directory: %w", err)
	}

	tmpFile, err := os.CreateTemp(targetDir, ".edith_tmp_*")
	if err != nil {
		_ = s.db.UpdateProposalStatus(p.ID, "failed", fmt.Sprintf("Temp file error: %v", err))
		return fmt.Errorf("failed to create temporary file for atomic write: %w", err)
	}
	tmpName := tmpFile.Name()

	_, writeErr := tmpFile.WriteString(p.ProposedContent)
	syncErr := tmpFile.Sync()
	closeErr := tmpFile.Close()

	if writeErr != nil || syncErr != nil || closeErr != nil {
		_ = os.Remove(tmpName)
		_ = s.db.UpdateProposalStatus(p.ID, "failed", fmt.Sprintf("Write error: write=%v, sync=%v, close=%v", writeErr, syncErr, closeErr))
		_ = s.db.LogActivity("proposal_failed", 0, 0, 0, 1, fmt.Sprintf("Write error on proposal %s: %v", p.ID, writeErr))
		return fmt.Errorf("failed writing proposal content: write=%v, sync=%v, close=%v", writeErr, syncErr, closeErr)
	}

	// Atomic replacement via rename
	if err := os.Rename(tmpName, targetAbs); err != nil {
		_ = os.Remove(tmpName)
		_ = s.db.UpdateProposalStatus(p.ID, "failed", fmt.Sprintf("Rename error: %v", err))
		_ = s.db.LogActivity("proposal_failed", 0, 0, 0, 1, fmt.Sprintf("Rename error on proposal %s: %v", p.ID, err))
		return fmt.Errorf("failed to replace target file %s: %w", targetAbs, err)
	}

	// Re-read modified note and update index immediately
	updatedNote, err := s.reader.ReadNote(p.TargetPath)
	if err == nil {
		_ = s.db.IndexNote(updatedNote)
	}

	// Update proposal status to approved
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

// ListRevisions returns historical backup snapshots of notes, optionally filtered by targetPath.
func (s *Service) ListRevisions(targetPath string) ([]*store.Revision, error) {
	return s.db.ListRevisions(targetPath)
}

// GetRevision returns a specific historical backup snapshot by ID.
func (s *Service) GetRevision(id int64) (*store.Revision, error) {
	rev, err := s.db.GetRevision(id)
	if err != nil {
		return nil, err
	}
	if rev == nil {
		return nil, ErrRevisionNotFound
	}
	return rev, nil
}

// RestoreRevision safely restores a note to a prior revision snapshot.
// It verifies safety, archives the current state as a new revision before restoration,
// writes atomically via fsync/rename, updates the index, and logs the activity.
func (s *Service) RestoreRevision(revisionID int64, reviewNotes string) error {
	rev, err := s.GetRevision(revisionID)
	if err != nil {
		return err
	}

	targetAbs, err := vault.EnsureSafePath(s.vaultRoot, rev.TargetPath)
	if err != nil {
		return fmt.Errorf("safety check failed for target: %w", err)
	}

	// Acquire lock for target
	lock := s.getTargetLock(rev.TargetPath)
	lock.Lock()
	defer lock.Unlock()

	// Capture current disk content to create a recoverable backup before restoring older version
	var currentContent string
	var currentHash string
	existingNote, err := s.reader.ReadNote(rev.TargetPath)
	if err == nil {
		currentContent = existingNote.Content
		currentHash = existingNote.Metadata.ContentHash
	}

	// Create an audit proposal record for the restore operation
	restorePropID := generateProposalID()
	restoreProp := &store.Proposal{
		ID:              restorePropID,
		TargetPath:      rev.TargetPath,
		TargetHash:      currentHash,
		Reason:          fmt.Sprintf("Restore to revision %d", revisionID),
		ProposedContent: rev.OriginalContent,
		Status:          "approved",
		CreatedAt:       time.Now().UTC(),
		ReviewedAt:      time.Now().UTC(),
		ReviewNotes:     reviewNotes,
	}
	if err := s.db.SaveProposal(restoreProp); err != nil {
		return fmt.Errorf("failed creating proposal record for restore: %w", err)
	}

	// Save pre-restoration snapshot so the restore operation is itself 100% reversible
	restoreRev := &store.Revision{
		ProposalID:      restorePropID,
		TargetPath:      rev.TargetPath,
		OriginalContent: currentContent,
		OriginalHash:    currentHash,
		AppliedAt:       time.Now().UTC(),
	}
	if err := s.db.SaveRevision(restoreRev); err != nil {
		return fmt.Errorf("failed to archive pre-restoration snapshot: %w", err)
	}

	// Atomic write restored content to disk
	targetDir := filepath.Dir(targetAbs)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("failed to create target directory: %w", err)
	}

	tmpFile, err := os.CreateTemp(targetDir, ".edith_restore_tmp_*")
	if err != nil {
		return fmt.Errorf("failed creating temporary file for restore: %w", err)
	}
	tmpName := tmpFile.Name()

	_, writeErr := tmpFile.WriteString(rev.OriginalContent)
	syncErr := tmpFile.Sync()
	closeErr := tmpFile.Close()

	if writeErr != nil || syncErr != nil || closeErr != nil {
		_ = os.Remove(tmpName)
		return fmt.Errorf("failed writing restored content: write=%v, sync=%v, close=%v", writeErr, syncErr, closeErr)
	}

	if err := os.Rename(tmpName, targetAbs); err != nil {
		_ = os.Remove(tmpName)
		return fmt.Errorf("failed replacing target file during restore: %w", err)
	}

	// Update index immediately
	updatedNote, err := s.reader.ReadNote(rev.TargetPath)
	if err == nil {
		_ = s.db.IndexNote(updatedNote)
	}

	_ = s.db.LogActivity("proposal_restore", 0, 1, 0, 0,
		fmt.Sprintf("Restored %s from revision %d (%s)", rev.TargetPath, revisionID, reviewNotes))

	return nil
}

func generateProposalID() string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	return fmt.Sprintf("prop-%s-%s", time.Now().Format("20060102150405"), hex.EncodeToString(b))
}
