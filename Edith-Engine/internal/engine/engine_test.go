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

func TestIndexingIdempotencyAndRebuildEquivalence(t *testing.T) {
	tempDir := t.TempDir()
	vaultDir := filepath.Join(tempDir, "vault")
	if err := os.MkdirAll(vaultDir, 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}

	// Create a representative vault of notes
	notes := map[string]string{
		"Alpha.md":           "# Alpha Note\nFirst knowledge entry on systems architecture.",
		"Beta.md":            "# Beta Note\nSecond knowledge entry on distributed databases.",
		"00-System/Gamma.md": "# Gamma Protocol\nSystem specifications and standards.",
	}
	for rel, content := range notes {
		full := filepath.Join(vaultDir, rel)
		_ = os.MkdirAll(filepath.Dir(full), 0755)
		if err := os.WriteFile(full, []byte(content), 0644); err != nil {
			t.Fatalf("write failed: %v", err)
		}
	}

	// Engine 1: Incremental indexing
	dbPath1 := filepath.Join(tempDir, "db1.db")
	cfg1 := &config.Config{VaultPath: vaultDir, DBPath: dbPath1}
	eng1, err := New(cfg1)
	if err != nil {
		t.Fatalf("New eng1 failed: %v", err)
	}
	defer eng1.Close()

	idx1, err := eng1.Index()
	if err != nil || idx1.AddedCount != 3 {
		t.Fatalf("initial index failed: %v, added: %d", err, idx1.AddedCount)
	}

	// Idempotency: Second index run should be completely unchanged
	idx2, err := eng1.Index()
	if err != nil {
		t.Fatalf("second index failed: %v", err)
	}
	if idx2.UnchangedCount != 3 || idx2.AddedCount != 0 || idx2.UpdatedCount != 0 || idx2.RemovedCount != 0 {
		t.Fatalf("idempotency violated: expected 3 unchanged, got %+v", idx2)
	}

	// Engine 2: Clean Rebuild
	dbPath2 := filepath.Join(tempDir, "db2.db")
	cfg2 := &config.Config{VaultPath: vaultDir, DBPath: dbPath2}
	eng2, err := New(cfg2)
	if err != nil {
		t.Fatalf("New eng2 failed: %v", err)
	}
	defer eng2.Close()

	// Initial index on DB2, then full reindex
	if _, err := eng2.Index(); err != nil {
		t.Fatalf("eng2 index failed: %v", err)
	}
	reindexRes, err := eng2.Reindex()
	if err != nil || reindexRes.AddedCount != 3 {
		t.Fatalf("reindex failed: %v, added: %d", err, reindexRes.AddedCount)
	}

	// Compare logical state between eng1 (incremental) and eng2 (reindexed)
	notes1, err := eng1.db.ListAllNotes()
	if err != nil {
		t.Fatalf("list notes 1 failed: %v", err)
	}
	notes2, err := eng2.db.ListAllNotes()
	if err != nil {
		t.Fatalf("list notes 2 failed: %v", err)
	}

	if len(notes1) != len(notes2) {
		t.Fatalf("rebuild equivalence failed: db1 has %d notes, db2 has %d notes", len(notes1), len(notes2))
	}

	for i := range notes1 {
		if notes1[i].RelPath != notes2[i].RelPath ||
			notes1[i].Title != notes2[i].Title ||
			notes1[i].ContentHash != notes2[i].ContentHash {
			t.Errorf("mismatch at index %d: db1=%+v, db2=%+v", i, notes1[i], notes2[i])
		}
	}

	// Verify identical search outcomes
	res1, _ := eng1.Search("databases", 10)
	res2, _ := eng2.Search("databases", 10)
	if len(res1) != 1 || len(res2) != 1 || res1[0].RelPath != res2[0].RelPath {
		t.Errorf("search results differ between incremental and rebuild: res1=%+v, res2=%+v", res1, res2)
	}
}

func TestNoteRenameAndMove(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	oldPath := filepath.Join(vaultDir, "OldName.md")
	if err := os.WriteFile(oldPath, []byte("# Dynamic Note\nUniqueTokenXYZ in content."), 0644); err != nil {
		t.Fatalf("write failed: %v", err)
	}

	if _, err := eng.Index(); err != nil {
		t.Fatalf("index failed: %v", err)
	}

	// Search finds old note
	resOld, err := eng.Search("UniqueTokenXYZ", 10)
	if err != nil || len(resOld) != 1 || resOld[0].RelPath != "OldName.md" {
		t.Fatalf("expected OldName.md match: %v, res: %+v", err, resOld)
	}

	// Rename note on disk
	newDir := filepath.Join(vaultDir, "SubDir")
	_ = os.MkdirAll(newDir, 0755)
	newPath := filepath.Join(newDir, "NewName.md")
	if err := os.Rename(oldPath, newPath); err != nil {
		t.Fatalf("rename failed: %v", err)
	}

	// Run incremental index
	idxRes, err := eng.Index()
	if err != nil {
		t.Fatalf("index after rename failed: %v", err)
	}
	if idxRes.AddedCount != 1 || idxRes.RemovedCount != 1 {
		t.Fatalf("expected 1 added and 1 removed after rename, got %+v", idxRes)
	}

	// Search now finds new note path and old note path is gone
	resNew, err := eng.Search("UniqueTokenXYZ", 10)
	if err != nil || len(resNew) != 1 || resNew[0].RelPath != "SubDir/NewName.md" {
		t.Fatalf("expected SubDir/NewName.md match, got %+v", resNew)
	}
}

func TestRecoveryFromInterruptedIndexing(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	// Create 3 notes on disk
	for _, name := range []string{"Note1.md", "Note2.md", "Note3.md"} {
		path := filepath.Join(vaultDir, name)
		if err := os.WriteFile(path, []byte("# "+name+"\nContent for "+name), 0644); err != nil {
			t.Fatalf("write failed: %v", err)
		}
	}

	// Simulate interrupted run by pre-indexing only Note1 into SQLite
	note1, err := eng.reader.ReadNote("Note1.md")
	if err != nil {
		t.Fatalf("read failed: %v", err)
	}
	if err := eng.db.IndexNote(note1); err != nil {
		t.Fatalf("pre-index note1 failed: %v", err)
	}

	// Resume indexing via standard Index()
	idxRes, err := eng.Index()
	if err != nil {
		t.Fatalf("resume index failed: %v", err)
	}

	// Should discover 3, add the 2 missing notes, and skip Note1 as unchanged
	if idxRes.DiscoveredCount != 3 || idxRes.AddedCount != 2 || idxRes.UnchangedCount != 1 {
		t.Fatalf("expected 2 added, 1 unchanged on resume, got %+v", idxRes)
	}

	// Database should have exactly 3 notes
	allNotes, err := eng.db.ListAllNotes()
	if err != nil || len(allNotes) != 3 {
		t.Fatalf("expected 3 total indexed notes, got %d", len(allNotes))
	}
}
