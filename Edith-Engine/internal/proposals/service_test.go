package proposals

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"edith-engine/internal/store"
	"edith-engine/internal/vault"
)

func setupTestService(t *testing.T) (*Service, string, *store.DB) {
	tempVault := t.TempDir()
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("failed to open test db: %v", err)
	}
	t.Cleanup(func() {
		db.Close()
	})

	reader, err := vault.NewReader(tempVault)
	if err != nil {
		t.Fatalf("failed to create reader: %v", err)
	}

	service := NewService(tempVault, db, reader)
	return service, tempVault, db
}

func TestProposalApprovalFlow(t *testing.T) {
	service, tempVault, db := setupTestService(t)

	notePath := "03-Wiki/Knowledge.md"
	initialContent := "# Initial Knowledge\nOriginal facts here."
	fullTarget := filepath.Join(tempVault, notePath)
	if err := os.MkdirAll(filepath.Dir(fullTarget), 0755); err != nil {
		t.Fatalf("failed to create dir: %v", err)
	}
	if err := os.WriteFile(fullTarget, []byte(initialContent), 0644); err != nil {
		t.Fatalf("failed to write initial note: %v", err)
	}

	// 1. Create proposal
	proposedContent := "# Initial Knowledge\nOriginal facts here.\n\nAdded insight from source."
	prop, err := service.CreateProposal(notePath, "Synthesize new insight", []string{"02-Raw-Sources/ref.md"}, proposedContent)
	if err != nil {
		t.Fatalf("CreateProposal failed: %v", err)
	}
	if prop.Status != "pending" {
		t.Errorf("expected pending status, got %s", prop.Status)
	}

	// 2. Approve proposal
	if err := service.Approve(prop.ID, "Looks good to merge"); err != nil {
		t.Fatalf("Approve failed: %v", err)
	}

	// Check file on disk
	onDisk, err := os.ReadFile(fullTarget)
	if err != nil {
		t.Fatalf("failed to read file after approve: %v", err)
	}
	if string(onDisk) != proposedContent {
		t.Errorf("expected file content to be updated on disk, got %q", string(onDisk))
	}

	// Check revision saved in DB
	row := db.Conn().QueryRow(`SELECT original_content FROM proposal_revisions WHERE proposal_id = ?;`, prop.ID)
	var archivedContent string
	if err := row.Scan(&archivedContent); err != nil {
		t.Fatalf("failed to read archived revision: %v", err)
	}
	if archivedContent != initialContent {
		t.Errorf("expected archived content to equal initial content, got %q", archivedContent)
	}

	// Check proposal status
	updatedProp, err := service.GetProposal(prop.ID)
	if err != nil {
		t.Fatalf("GetProposal failed: %v", err)
	}
	if updatedProp.Status != "approved" {
		t.Errorf("expected status approved, got %s", updatedProp.Status)
	}
}

func TestProposalConflictDetection(t *testing.T) {
	service, tempVault, _ := setupTestService(t)

	notePath := "03-Wiki/ConflictTest.md"
	initialContent := "# Conflict Test\nVersion 1"
	fullTarget := filepath.Join(tempVault, notePath)
	if err := os.MkdirAll(filepath.Dir(fullTarget), 0755); err != nil {
		t.Fatalf("failed to create dir: %v", err)
	}
	if err := os.WriteFile(fullTarget, []byte(initialContent), 0644); err != nil {
		t.Fatalf("failed to write initial note: %v", err)
	}

	// Create proposal
	prop, err := service.CreateProposal(notePath, "Proposed change", nil, "# Conflict Test\nVersion Proposal")
	if err != nil {
		t.Fatalf("CreateProposal failed: %v", err)
	}

	// Simulate concurrent modification on disk
	modifiedContent := "# Conflict Test\nVersion Modified by Human"
	if err := os.WriteFile(fullTarget, []byte(modifiedContent), 0644); err != nil {
		t.Fatalf("failed to overwrite note: %v", err)
	}

	// Try to approve: should fail with ErrTargetConflict
	err = service.Approve(prop.ID, "Approve after conflict")
	if !errors.Is(err, ErrTargetConflict) {
		t.Fatalf("expected ErrTargetConflict, got %v", err)
	}

	// Ensure file was NOT overwritten with proposal content
	currentOnDisk, _ := os.ReadFile(fullTarget)
	if string(currentOnDisk) != modifiedContent {
		t.Errorf("file was altered despite conflict rejection: %q", string(currentOnDisk))
	}
}

func TestProposalRejectionFlow(t *testing.T) {
	service, tempVault, _ := setupTestService(t)

	notePath := "03-Wiki/RejectTest.md"
	initialContent := "# Rejection Test\nMust remain unchanged."
	fullTarget := filepath.Join(tempVault, notePath)
	if err := os.MkdirAll(filepath.Dir(fullTarget), 0755); err != nil {
		t.Fatalf("failed to create dir: %v", err)
	}
	if err := os.WriteFile(fullTarget, []byte(initialContent), 0644); err != nil {
		t.Fatalf("failed to write initial note: %v", err)
	}

	prop, err := service.CreateProposal(notePath, "Will be rejected", nil, "# Rejection Test\nBad content")
	if err != nil {
		t.Fatalf("CreateProposal failed: %v", err)
	}

	if err := service.Reject(prop.ID, "Not relevant to wiki"); err != nil {
		t.Fatalf("Reject failed: %v", err)
	}

	// Check file on disk is unchanged
	onDisk, _ := os.ReadFile(fullTarget)
	if string(onDisk) != initialContent {
		t.Errorf("file on disk was modified on rejection: %q", string(onDisk))
	}

	updatedProp, err := service.GetProposal(prop.ID)
	if err != nil {
		t.Fatalf("GetProposal failed: %v", err)
	}
	if updatedProp.Status != "rejected" {
		t.Errorf("expected status rejected, got %s", updatedProp.Status)
	}
}

func TestProposalConcurrentApprovalSafety(t *testing.T) {
	service, tempVault, _ := setupTestService(t)

	notePath := "ConcurrentNote.md"
	initialContent := "# Concurrent Test\nOriginal"
	fullTarget := filepath.Join(tempVault, notePath)
	if err := os.WriteFile(fullTarget, []byte(initialContent), 0644); err != nil {
		t.Fatalf("write failed: %v", err)
	}

	prop, err := service.CreateProposal(notePath, "Concurrent update", nil, "# Concurrent Test\nApproved New Content")
	if err != nil {
		t.Fatalf("create proposal failed: %v", err)
	}

	// Launch two concurrent approvals
	errs := make(chan error, 2)
	for i := 0; i < 2; i++ {
		go func(workerID int) {
			errs <- service.Approve(prop.ID, "Review from worker")
		}(i)
	}

	err1 := <-errs
	err2 := <-errs

	// Exactly one approval should succeed; the other should fail because status is no longer pending
	successCount := 0
	conflictOrNotPendingCount := 0
	for _, e := range []error{err1, err2} {
		if e == nil {
			successCount++
		} else if errors.Is(e, ErrProposalNotPending) {
			conflictOrNotPendingCount++
		}
	}

	if successCount != 1 || conflictOrNotPendingCount != 1 {
		t.Fatalf("expected 1 success and 1 not-pending failure, got err1=%v, err2=%v", err1, err2)
	}

	// Verify file is correctly written
	onDisk, _ := os.ReadFile(fullTarget)
	if string(onDisk) != "# Concurrent Test\nApproved New Content" {
		t.Errorf("unexpected file content: %s", string(onDisk))
	}
}

func TestProposalConflictRecording(t *testing.T) {
	service, tempVault, _ := setupTestService(t)

	notePath := "ConflictRecord.md"
	initialContent := "# Pre-conflict\nOriginal"
	fullTarget := filepath.Join(tempVault, notePath)
	_ = os.WriteFile(fullTarget, []byte(initialContent), 0644)

	prop, err := service.CreateProposal(notePath, "Will conflict", nil, "# New Content")
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	// Alter file on disk
	_ = os.WriteFile(fullTarget, []byte("# Altered on disk\nBy human"), 0644)

	// Approve should fail with conflict
	err = service.Approve(prop.ID, "Try approve")
	if !errors.Is(err, ErrTargetConflict) {
		t.Fatalf("expected ErrTargetConflict, got %v", err)
	}

	// Proposal in DB must be recorded as 'conflict'
	p, err := service.GetProposal(prop.ID)
	if err != nil {
		t.Fatalf("GetProposal failed: %v", err)
	}
	if p.Status != "conflict" {
		t.Errorf("expected proposal status 'conflict', got %q", p.Status)
	}
}

func TestProposalRepeatedRejection(t *testing.T) {
	service, tempVault, _ := setupTestService(t)

	notePath := "RepeatReject.md"
	_ = os.WriteFile(filepath.Join(tempVault, notePath), []byte("# Text"), 0644)

	prop, _ := service.CreateProposal(notePath, "Reject me", nil, "# Proposed")
	if err := service.Reject(prop.ID, "First reject"); err != nil {
		t.Fatalf("first reject failed: %v", err)
	}

	// Second reject must fail predictably with ErrProposalNotPending
	err := service.Reject(prop.ID, "Second reject")
	if !errors.Is(err, ErrProposalNotPending) {
		t.Fatalf("expected ErrProposalNotPending on repeated rejection, got %v", err)
	}
}

func TestProposalRevisionRestore(t *testing.T) {
	service, tempVault, db := setupTestService(t)

	notePath := "RestoreNote.md"
	v1Content := "# Version 1\nHistorical original content."
	fullTarget := filepath.Join(tempVault, notePath)
	_ = os.WriteFile(fullTarget, []byte(v1Content), 0644)

	// Step 1: Create and approve proposal (replaces v1 with v2)
	v2Content := "# Version 2\nUpdated content from proposal."
	prop, err := service.CreateProposal(notePath, "Upgrade to v2", nil, v2Content)
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}
	if err := service.Approve(prop.ID, "Merged v2"); err != nil {
		t.Fatalf("approve failed: %v", err)
	}

	// Verify note is v2
	content, _ := os.ReadFile(fullTarget)
	if string(content) != v2Content {
		t.Fatalf("expected note to be v2")
	}

	// Step 2: List revisions
	revs, err := service.ListRevisions(notePath)
	if err != nil || len(revs) != 1 {
		t.Fatalf("expected 1 revision, got %d (err: %v)", len(revs), err)
	}
	v1RevID := revs[0].ID
	if revs[0].OriginalContent != v1Content {
		t.Errorf("expected revision content to match v1, got %q", revs[0].OriginalContent)
	}

	// Step 3: Restore v1 from revision
	if err := service.RestoreRevision(v1RevID, "Rollback to v1"); err != nil {
		t.Fatalf("RestoreRevision failed: %v", err)
	}

	// Step 4: Verify note on disk is now restored to v1
	restoredContent, _ := os.ReadFile(fullTarget)
	if string(restoredContent) != v1Content {
		t.Errorf("expected restored content to be v1, got %q", string(restoredContent))
	}

	// Step 5: Verify pre-restoration snapshot (v2) was preserved!
	revsAfter, err := service.ListRevisions(notePath)
	if err != nil || len(revsAfter) != 2 {
		t.Fatalf("expected 2 revisions after rollback, got %d", len(revsAfter))
	}
	// The newest revision should contain v2Content
	if revsAfter[0].OriginalContent != v2Content {
		t.Errorf("expected newest revision to hold v2 pre-restore content, got %q", revsAfter[0].OriginalContent)
	}

	// Step 6: Verify indexed note in DB reflects restored v1
	indexed, err := db.GetNote(notePath)
	if err != nil || indexed == nil {
		t.Fatalf("GetNote failed: %v", err)
	}
	if indexed.Title != "Version 1" {
		t.Errorf("expected indexed title 'Version 1', got %q", indexed.Title)
	}

	// Step 7: Attempting to restore non-existent revision returns error
	err = service.RestoreRevision(999999, "Invalid")
	if !errors.Is(err, ErrRevisionNotFound) {
		t.Fatalf("expected ErrRevisionNotFound, got %v", err)
	}
}
