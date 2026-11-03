package workflows

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"

	"edith-engine/internal/proposals"
	"edith-engine/internal/store"
)

// ProposalInspection provides a full audit inspection of a proposal prior to approval.
type ProposalInspection struct {
	Proposal           store.Proposal `json:"proposal"`
	TargetExists       bool           `json:"target_exists"`
	ExpectedTargetHash string         `json:"expected_target_hash"`
	CurrentTargetHash  string         `json:"current_target_hash"`
	IsStaleConflict    bool           `json:"is_stale_conflict"`
	CurrentContent     string         `json:"current_content"`
	ProposedContent    string         `json:"proposed_content"`
}

// ReviewWorkflow orchestrates the safe human-approval lifecycle for change proposals and revisions.
type ReviewWorkflow struct {
	vaultRoot string
	db        *store.DB
	proposals *proposals.Service
}

// NewReviewWorkflow constructs a ReviewWorkflow.
func NewReviewWorkflow(vaultRoot string, db *store.DB, ps *proposals.Service) *ReviewWorkflow {
	return &ReviewWorkflow{
		vaultRoot: vaultRoot,
		db:        db,
		proposals: ps,
	}
}

// ListPending returns all pending proposals awaiting human review.
func (w *ReviewWorkflow) ListPending() ([]*store.Proposal, error) {
	return w.proposals.ListProposals("pending")
}

// Inspect prepares a detailed comparison and safety check for a proposal.
func (w *ReviewWorkflow) Inspect(id string) (*ProposalInspection, error) {
	p, err := w.proposals.GetProposal(id)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, fmt.Errorf("proposal %q not found", id)
	}

	fullPath := filepath.Join(w.vaultRoot, p.TargetPath)
	insp := &ProposalInspection{
		Proposal:           *p,
		ExpectedTargetHash: p.TargetHash,
		ProposedContent:    p.ProposedContent,
	}

	data, err := os.ReadFile(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			insp.TargetExists = false
			if p.TargetHash != "" {
				insp.IsStaleConflict = true // Target existed at proposal creation, now missing!
			}
		} else {
			return nil, fmt.Errorf("failed reading target file %s: %w", p.TargetPath, err)
		}
	} else {
		insp.TargetExists = true
		insp.CurrentContent = string(data)
		h := sha256.Sum256(data)
		insp.CurrentTargetHash = hex.EncodeToString(h[:])
		if p.TargetHash != "" && p.TargetHash != insp.CurrentTargetHash {
			insp.IsStaleConflict = true
		}
	}

	return insp, nil
}

// Approve applies the approved proposal to disk using Phase 2 transactional & rollback guarantees.
func (w *ReviewWorkflow) Approve(id string, reviewNotes string) error {
	return w.proposals.Approve(id, reviewNotes)
}

// Reject rejects the proposal without touching target files on disk.
func (w *ReviewWorkflow) Reject(id string, reviewNotes string) error {
	return w.proposals.Reject(id, reviewNotes)
}

// History retrieves the revision snapshot history for all notes or a specific target.
func (w *ReviewWorkflow) History(targetPath string) ([]*store.Revision, error) {
	return w.proposals.ListRevisions(targetPath)
}

// Restore rolls back a note to a prior revision snapshot safely and auditably.
func (w *ReviewWorkflow) Restore(revisionID int64, notes string) error {
	return w.proposals.RestoreRevision(revisionID, notes)
}
