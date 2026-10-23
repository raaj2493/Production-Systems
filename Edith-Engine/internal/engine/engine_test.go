package engine

import (
	"os"
	"path/filepath"
	"testing"

	"edith-engine/internal/config"
)

func setupTestEngine(t *testing.T) (*Engine, string) {
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

	eng, err := New(cfg)
	if err != nil {
		t.Fatalf("engine.New failed: %v", err)
	}
	t.Cleanup(func() {
		eng.Close()
	})

	return eng, vaultDir
}

func TestEngineLifecycle(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	// 1. Create initial notes
	note1 := filepath.Join(vaultDir, "README.md")
	note2 := filepath.Join(vaultDir, "00-System", "Protocol.md")
	if err := os.MkdirAll(filepath.Dir(note2), 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}

	if err := os.WriteFile(note1, []byte("# Welcome to Edith\nA personal second brain."), 0644); err != nil {
		t.Fatalf("write failed: %v", err)
	}
	if err := os.WriteFile(note2, []byte("# System Protocol\nRules of engagement and [[README]]."), 0644); err != nil {
		t.Fatalf("write failed: %v", err)
	}

	// 2. Scan before indexing
	scanRes, err := eng.Scan()
	if err != nil {
		t.Fatalf("Scan failed: %v", err)
	}
	if scanRes.TotalDiscovered != 2 {
		t.Fatalf("expected 2 discovered notes, got %d", scanRes.TotalDiscovered)
	}
	if scanRes.UnindexedCount != 2 {
		t.Fatalf("expected 2 unindexed notes, got %d", scanRes.UnindexedCount)
	}

	// 3. Initial Index
	idxRes, err := eng.Index()
	if err != nil {
		t.Fatalf("Index failed: %v", err)
	}
	if idxRes.AddedCount != 2 || idxRes.FailedCount != 0 {
		t.Fatalf("expected 2 added notes, got %d (failed: %d)", idxRes.AddedCount, idxRes.FailedCount)
	}

	// 4. Second index immediately: should be unchanged
	idxRes2, err := eng.Index()
	if err != nil {
		t.Fatalf("Second Index failed: %v", err)
	}
	if idxRes2.UnchangedCount != 2 || idxRes2.AddedCount != 0 || idxRes2.UpdatedCount != 0 {
		t.Fatalf("expected 2 unchanged notes, got %+v", idxRes2)
	}

	// 5. Search
	searchRes, err := eng.Search("second brain", 10)
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	if len(searchRes) != 1 {
		t.Fatalf("expected 1 search result, got %d", len(searchRes))
	}
	if searchRes[0].RelPath != "README.md" {
		t.Errorf("expected README.md match, got %s", searchRes[0].RelPath)
	}

	// 6. Modify note and index incrementally
	if err := os.WriteFile(note1, []byte("# Welcome to Edith\nUpdated content with artificial intelligence references."), 0644); err != nil {
		t.Fatalf("modify note failed: %v", err)
	}
	idxRes3, err := eng.Index()
	if err != nil {
		t.Fatalf("Incremental Index failed: %v", err)
	}
	if idxRes3.UpdatedCount != 1 || idxRes3.UnchangedCount != 1 {
		t.Fatalf("expected 1 updated and 1 unchanged, got %+v", idxRes3)
	}

	// 7. Verify search finds updated content
	searchRes2, err := eng.Search("artificial intelligence", 10)
	if err != nil {
		t.Fatalf("Search after update failed: %v", err)
	}
	if len(searchRes2) != 1 {
		t.Fatalf("expected 1 search result for updated content, got %d", len(searchRes2))
	}

	// 8. Delete note from disk and verify cleanup on index
	if err := os.Remove(note2); err != nil {
		t.Fatalf("remove note failed: %v", err)
	}
	idxRes4, err := eng.Index()
	if err != nil {
		t.Fatalf("Index after delete failed: %v", err)
	}
	if idxRes4.RemovedCount != 1 {
		t.Fatalf("expected 1 removed note, got %d", idxRes4.RemovedCount)
	}

	// 9. Reindex
	reindexRes, err := eng.Reindex()
	if err != nil {
		t.Fatalf("Reindex failed: %v", err)
	}
	if reindexRes.AddedCount != 1 {
		t.Fatalf("expected 1 note added in reindex, got %d", reindexRes.AddedCount)
	}

	// 10. Status
	status, err := eng.Status()
	if err != nil {
		t.Fatalf("Status failed: %v", err)
	}
	if status.DiskNoteCount != 1 || status.DBNoteCount != 1 {
		t.Errorf("unexpected status counts: disk=%d, db=%d", status.DiskNoteCount, status.DBNoteCount)
	}

	// 11. ReadNote
	note, err := eng.ReadNote("README.md")
	if err != nil {
		t.Fatalf("ReadNote failed: %v", err)
	}
	if note.Metadata.Title != "Welcome to Edith" {
		t.Errorf("expected title 'Welcome to Edith', got %q", note.Metadata.Title)
	}

	// 12. Lint
	report, err := eng.Lint()
	if err != nil {
		t.Fatalf("Lint failed: %v", err)
	}
	if report == nil {
		t.Fatalf("expected non-nil lint report")
	}
}
