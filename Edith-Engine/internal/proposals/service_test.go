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
