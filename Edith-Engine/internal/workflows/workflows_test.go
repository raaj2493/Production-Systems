package workflows_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"edith-engine/internal/config"
	"edith-engine/internal/engine"
	"edith-engine/internal/workflows"
)

func setupTestEngine(t *testing.T) (*engine.Engine, string) {
	t.Helper()
	tempDir := t.TempDir()
	vaultDir := filepath.Join(tempDir, "vault")
	if err := os.MkdirAll(vaultDir, 0755); err != nil {
		t.Fatalf("mkdir vault failed: %v", err)
	}

	dbPath := filepath.Join(tempDir, "test.db")
	cfg := &config.Config{
		VaultPath: vaultDir,
		DBPath:    dbPath,
	}

	eng, err := engine.New(cfg)
	if err != nil {
		t.Fatalf("engine.New failed: %v", err)
	}
	t.Cleanup(func() {
		eng.Close()
	})

	return eng, vaultDir
}

func writeVaultNote(t *testing.T, vaultDir, relPath, content string) {
	t.Helper()
	fullPath := filepath.Join(vaultDir, relPath)
	if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
		t.Fatalf("write file failed: %v", err)
	}
}

func TestIngestWorkflow_NewDuplicateAndSafety(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	// Seed existing note in vault to test relevant note linkage
	writeVaultNote(t, vaultDir, "Architecture.md", "# Software Architecture\nSystem design and patterns.")
	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	rawText := "# Distributed Systems Primer\nAuthor: Leslie Lamport\nCore foundations of distributed clocks and state machines."

	// 1. Initial Ingest
	rep1, err := eng.Ingest(workflows.IngestRequest{
		RawContent:       rawText,
		SourceIdentifier: "lamport-primer-v1",
		Title:            "Distributed Systems Primer",
		Author:           "Leslie Lamport",
	})
	if err != nil {
		t.Fatalf("Ingest failed: %v", err)
	}
	if rep1.Status != "new" {
		t.Fatalf("expected status 'new', got %q", rep1.Status)
	}
	if rep1.ProposalID == "" {
		t.Fatalf("expected proposal ID to be generated for new ingest")
	}
	if rep1.ContentHash == "" {
		t.Fatalf("expected content hash")
	}

	// Verify proposal exists and has pending status
	p, err := eng.Proposals().GetProposal(rep1.ProposalID)
	if err != nil || p == nil {
		t.Fatalf("GetProposal failed: %v", err)
	}
	if p.Status != "pending" {
		t.Errorf("expected proposal status pending, got %s", p.Status)
	}

	// 2. Repeated Ingest with exact same content -> Duplicate Detection
	rep2, err := eng.Ingest(workflows.IngestRequest{
		RawContent:       rawText,
		SourceIdentifier: "lamport-primer-duplicate-attempt",
	})
	if err != nil {
		t.Fatalf("Second Ingest failed: %v", err)
	}
	if rep2.Status != "duplicate" {
		t.Fatalf("expected status 'duplicate', got %q", rep2.Status)
	}
	if rep2.DuplicateOf != rep1.SourceID {
		t.Errorf("expected DuplicateOf %s, got %s", rep1.SourceID, rep2.DuplicateOf)
	}
	if rep2.ProposalID != "" {
		t.Errorf("duplicate ingest should not create a new proposal, got proposal %s", rep2.ProposalID)
	}

	// 3. Remote URL security constraint: must reject http/https
	_, err = eng.Ingest(workflows.IngestRequest{
		FilePath: "https://example.com/malicious.md",
	})
	if err == nil || !strings.Contains(err.Error(), "remote URL fetching is disabled") {
		t.Fatalf("expected remote URL rejection error, got %v", err)
	}
}

func TestQueryWorkflow_EvidenceAndNoEvidence(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	writeVaultNote(t, vaultDir, "Alpha.md", "# Alpha Architecture\nEvent driven stream processing architecture.")
	writeVaultNote(t, vaultDir, "Beta.md", "# Beta Systems\nConnected to [[Alpha]] for data replication.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	// 1. Query with evidence
	qRes, err := eng.Query(workflows.QueryRequest{
		Query:    "stream processing",
		UseGraph: true,
		Limit:    5,
	})
	if err != nil {
		t.Fatalf("Query failed: %v", err)
	}
	if !qRes.EvidenceFound {
		t.Fatalf("expected evidence to be found")
	}
	if len(qRes.Items) < 1 {
		t.Fatalf("expected at least 1 evidence item, got %d", len(qRes.Items))
	}
	if qRes.Items[0].RelPath != "Alpha.md" {
		t.Errorf("expected top evidence to be Alpha.md, got %s", qRes.Items[0].RelPath)
	}
	if qRes.Items[0].ContentHash == "" {
		t.Errorf("expected content hash to be populated")
	}
	if qRes.Items[0].InclusionReason == "" {
		t.Errorf("expected inclusion reason to be populated")
	}

	// 2. Query with no evidence
	emptyRes, err := eng.Query(workflows.QueryRequest{
		Query:    "nonexistentxyz12345",
		UseGraph: false,
	})
	if err != nil {
		t.Fatalf("Query failed: %v", err)
	}
	if emptyRes.EvidenceFound {
		t.Fatalf("expected EvidenceFound=false for nonexistent term")
	}
	if !strings.Contains(emptyRes.Message, "No evidence found") {
		t.Errorf("expected no evidence message, got: %s", emptyRes.Message)
	}
}

func TestSynthesizeWorkflow_ProvenanceAndContradictions(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	// Note 1: Active architecture
	writeVaultNote(t, vaultDir, "Consensus-Raft.md", "# Consensus Protocol\nStatus: Active\nLeader election and log replication via Raft.")
	// Note 2: Deprecated architecture with same normalized topic
	writeVaultNote(t, vaultDir, "Consensus-Paxos.md", "# Consensus Protocol\nStatus: Deprecated\nMulti-paxos implementation replaced by Raft.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	res, err := eng.Synthesize(workflows.SynthesizeRequest{
		Topic:          "Consensus",
		SubmitProposal: true,
	})
	if err != nil {
		t.Fatalf("Synthesize failed: %v", err)
	}

	if res.TotalSources < 2 {
		t.Fatalf("expected at least 2 sources, got %d", res.TotalSources)
	}

	// Verify evidence groups preserve provenance
	if len(res.EvidenceGroups) < 2 {
		t.Fatalf("expected at least 2 evidence groups, got %d", len(res.EvidenceGroups))
	}
	for _, grp := range res.EvidenceGroups {
		for _, item := range grp.Items {
			if item.SourcePath == "" || item.ContentHash == "" {
				t.Errorf("evidence item missing provenance path or hash: %+v", item)
			}
		}
	}

	// Verify contradiction group detected
	if len(res.Contradictions) == 0 {
		t.Errorf("expected contradiction group for duplicate topic with opposing active/deprecated statuses")
	}

	// Verify proposal was staged
	if res.ProposalID == "" {
		t.Errorf("expected proposal ID to be returned when SubmitProposal is true")
	}
	p, err := eng.Proposals().GetProposal(res.ProposalID)
	if err != nil || p == nil {
		t.Fatalf("staged synthesis proposal not found: %v", err)
	}
	if p.Status != "pending" {
		t.Errorf("expected proposal status pending, got %s", p.Status)
	}
	if !strings.Contains(p.ProposedContent, "## Evidence Groups & Citations") {
		t.Errorf("expected proposed outline to contain evidence citations")
	}
}

func TestReviewWorkflow_ApproveRejectConflictAndRestore(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)
	rw := eng.Review()

	targetPath := "Notes/Architecture.md"
	initialContent := "# System Architecture\nBaseline microservices design."
	writeVaultNote(t, vaultDir, targetPath, initialContent)

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	// 1. Stage proposal
	p1, err := eng.Proposals().CreateProposal(targetPath, "Update architecture to event-driven", nil, "# System Architecture\nEvent-driven microservices design.")
	if err != nil {
		t.Fatalf("CreateProposal failed: %v", err)
	}

	// 2. Inspect proposal
	insp, err := rw.Inspect(p1.ID)
	if err != nil {
		t.Fatalf("Inspect failed: %v", err)
	}
	if !insp.TargetExists {
		t.Errorf("expected TargetExists=true")
	}
	if insp.IsStaleConflict {
		t.Errorf("expected IsStaleConflict=false initially")
	}

	// 3. Reject proposal -> target remains unchanged
	if err := rw.Reject(p1.ID, "Rejected by architect"); err != nil {
		t.Fatalf("Reject failed: %v", err)
	}
	p1After, _ := eng.Proposals().GetProposal(p1.ID)
	if p1After.Status != "rejected" {
		t.Errorf("expected status rejected, got %s", p1After.Status)
	}
	// Verify file on disk is untouched
	readData, _ := os.ReadFile(filepath.Join(vaultDir, targetPath))
	if string(readData) != initialContent {
		t.Errorf("file was modified after rejection! Expected %q, got %q", initialContent, string(readData))
	}

	// 4. Stale Target Conflict Detection:
	// Stage proposal 2
	p2, err := eng.Proposals().CreateProposal(targetPath, "Add caching tier", nil, "# System Architecture\nWith Redis cache.")
	if err != nil {
		t.Fatalf("CreateProposal p2 failed: %v", err)
	}

	// Directly modify file on disk before approval (simulating external user edit in Obsidian)
	modifiedContent := "# System Architecture\nDirectly modified in Obsidian."
	writeVaultNote(t, vaultDir, targetPath, modifiedContent)

	// Approve should detect stale hash and REFUSE to overwrite newer edits
	err = rw.Approve(p2.ID, "Attempt approval on modified target")
	if err == nil || !strings.Contains(err.Error(), "modified on disk") {
		t.Fatalf("expected stale target conflict error, got %v", err)
	}
	p2After, _ := eng.Proposals().GetProposal(p2.ID)
	if p2After.Status != "conflict" {
		t.Errorf("expected proposal status conflict, got %s", p2After.Status)
	}
	// Target note must NOT be overwritten by the stale proposal
	readDataAfterConflict, _ := os.ReadFile(filepath.Join(vaultDir, targetPath))
	if string(readDataAfterConflict) != modifiedContent {
		t.Errorf("stale proposal overwrote disk! Expected %q, got %q", modifiedContent, string(readDataAfterConflict))
	}

	// 5. Successful Approval and Safe Revision Restore:
	// Stage proposal 3 matching the current disk hash
	p3, err := eng.Proposals().CreateProposal(targetPath, "Legitimate update", nil, "# System Architecture\nApproved modern design.")
	if err != nil {
		t.Fatalf("CreateProposal p3 failed: %v", err)
	}
	if err := rw.Approve(p3.ID, "Approved modern design"); err != nil {
		t.Fatalf("Approve p3 failed: %v", err)
	}

	// Check revision history
	history, err := rw.History(targetPath)
	if err != nil {
		t.Fatalf("History failed: %v", err)
	}
	if len(history) < 1 {
		t.Fatalf("expected at least 1 revision snapshot, got %d", len(history))
	}
	rev := history[0]

	// Restore prior revision
	if err := rw.Restore(rev.ID, "Rolling back to previous version"); err != nil {
		t.Fatalf("Restore failed: %v", err)
	}

	// Verify file content on disk is restored
	restoredData, _ := os.ReadFile(filepath.Join(vaultDir, targetPath))
	if string(restoredData) != rev.OriginalContent {
		t.Errorf("restore did not restore original content. Expected %q, got %q", rev.OriginalContent, string(restoredData))
	}
}
