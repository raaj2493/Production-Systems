package contextpkg_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"edith-engine/internal/config"
	"edith-engine/internal/contextpkg"
	"edith-engine/internal/engine"
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

func TestContextDeterminismAndProvenance(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	writeVaultNote(t, vaultDir, "03-Wiki/Distributed-Consensus.md", "# Distributed Consensus\nStudy of Paxos, Raft, and Byzantine Fault Tolerance consensus algorithms.")
	writeVaultNote(t, vaultDir, "00-Sources/Lamport1998.md", "# The Part-Time Parliament\nType: source\nOriginal paper introducing Paxos by Leslie Lamport.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	req := contextpkg.ContextRequest{
		Query:       "consensus",
		EnableGraph: true,
		GraphDepth:  1,
		MaxResults:  10,
	}

	pkg1, err := eng.Context(req)
	if err != nil {
		t.Fatalf("Context run 1 failed: %v", err)
	}
	pkg2, err := eng.Context(req)
	if err != nil {
		t.Fatalf("Context run 2 failed: %v", err)
	}

	if pkg1.TotalEvidenceCount != pkg2.TotalEvidenceCount {
		t.Fatalf("determinism failure: count mismatch (%d vs %d)", pkg1.TotalEvidenceCount, pkg2.TotalEvidenceCount)
	}
	for i := range pkg1.Evidence {
		if pkg1.Evidence[i].RelPath != pkg2.Evidence[i].RelPath {
			t.Errorf("ordering mismatch at %d: %s vs %s", i, pkg1.Evidence[i].RelPath, pkg2.Evidence[i].RelPath)
		}
		if pkg1.Evidence[i].ContentHash != pkg2.Evidence[i].ContentHash {
			t.Errorf("hash mismatch at %d: %s vs %s", i, pkg1.Evidence[i].ContentHash, pkg2.Evidence[i].ContentHash)
		}
	}

	// Verify provenance and classification
	for _, ev := range pkg1.Evidence {
		if ev.ContentHash == "" {
			t.Errorf("expected content hash for %s", ev.RelPath)
		}
		if ev.RelPath == "00-Sources/Lamport1998.md" && ev.Classification != contextpkg.ClassOriginalSource {
			t.Errorf("expected original_source classification for source note, got %s", ev.Classification)
		}
		if ev.RelPath == "03-Wiki/Distributed-Consensus.md" && ev.Classification != contextpkg.ClassWikiNote {
			t.Errorf("expected wiki_note classification, got %s", ev.Classification)
		}
	}
}

func TestContextBudgetEnforcementAndTruncation(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	// Create notes with substantial text
	longText1 := "# Note One\n" + strings.Repeat("Long text paragraph detailing engineering principles. ", 15)
	longText2 := "# Note Two\n" + strings.Repeat("Another detailed paragraph explaining distributed architecture. ", 15)
	longText3 := "# Note Three\n" + strings.Repeat("Third note discussing database transactions and write ahead logs. ", 15)

	writeVaultNote(t, vaultDir, "Note1.md", longText1)
	writeVaultNote(t, vaultDir, "Note2.md", longText2)
	writeVaultNote(t, vaultDir, "Note3.md", longText3)

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	// Restrict budget strictly to 350 bytes
	maxBudget := 350
	pkg, err := eng.Context(contextpkg.ContextRequest{
		Query:           "paragraph",
		MaxContextBytes: maxBudget,
		MaxResults:      10,
	})
	if err != nil {
		t.Fatalf("Context failed: %v", err)
	}

	if pkg.TotalContextBytes > maxBudget {
		t.Fatalf("context budget violated! Total bytes %d > max %d", pkg.TotalContextBytes, maxBudget)
	}
	if !pkg.IsTruncated {
		t.Errorf("expected IsTruncated=true when budget is reached")
	}
	if pkg.TruncationReason == "" {
		t.Errorf("expected truncation reason to be documented")
	}
	if len(pkg.ExcludedCandidates) == 0 {
		t.Errorf("expected excluded candidates to be recorded due to budget exhaustion")
	}
}

func TestContextPathScopingAndSecurity(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	writeVaultNote(t, vaultDir, "00-System/Secret.md", "# Secret System Note\nInternal administrative rules.")
	writeVaultNote(t, vaultDir, "03-Wiki/PublicGuide.md", "# Public Guide\nPublic engineering documentation.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	// 1. Exclude 00-System/
	pkg, err := eng.Context(contextpkg.ContextRequest{
		Query:         "System",
		ExcludedPaths: []string{"00-System/"},
	})
	if err != nil {
		t.Fatalf("Context failed: %v", err)
	}
	for _, ev := range pkg.Evidence {
		if strings.HasPrefix(ev.RelPath, "00-System/") {
			t.Fatalf("excluded path %s appeared in evidence!", ev.RelPath)
		}
	}

	// 2. AllowedPaths filter
	pkgAllowed, err := eng.Context(contextpkg.ContextRequest{
		Query:        "guide",
		AllowedPaths: []string{"03-Wiki/"},
	})
	if err != nil {
		t.Fatalf("Context with allowed paths failed: %v", err)
	}
	for _, ev := range pkgAllowed.Evidence {
		if !strings.HasPrefix(ev.RelPath, "03-Wiki/") {
			t.Fatalf("evidence note %s is outside allowed paths!", ev.RelPath)
		}
	}

	// 3. Path traversal attack must be rejected
	_, err = eng.Context(contextpkg.ContextRequest{
		SelectedNotes: []string{"../../etc/passwd"},
	})
	if err == nil || !strings.Contains(err.Error(), "escapes vault root") {
		t.Fatalf("expected vault escape security rejection, got: %v", err)
	}
}

func TestContextGraphDepthLimits(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	// Chain: N0 -> N1 -> N2 -> N3
	writeVaultNote(t, vaultDir, "N0.md", "# N0\nKeyword search hit target with [[N1]].")
	writeVaultNote(t, vaultDir, "N1.md", "# N1\nLink to [[N2]].")
	writeVaultNote(t, vaultDir, "N2.md", "# N2\nLink to [[N3]].")
	writeVaultNote(t, vaultDir, "N3.md", "# N3\nEnd of long chain.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	// Depth 1: N0 (hit), N1 (1-hop)
	pkgDepth1, err := eng.Context(contextpkg.ContextRequest{
		Query:       "target",
		EnableGraph: true,
		GraphDepth:  1,
	})
	if err != nil {
		t.Fatalf("Depth 1 failed: %v", err)
	}
	for _, ev := range pkgDepth1.Evidence {
		if ev.RelationshipHops > 1 {
			t.Errorf("evidence item %s exceeded depth 1 (hops: %d)", ev.RelPath, ev.RelationshipHops)
		}
		if ev.RelPath == "N2.md" || ev.RelPath == "N3.md" {
			t.Errorf("note beyond depth 1 included: %s", ev.RelPath)
		}
	}
}

func TestContextConflictPreservation(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	writeVaultNote(t, vaultDir, "Database-Active.md", "# Database Standard\nStatus: Active\nPostgreSQL is our primary relational datastore.")
	writeVaultNote(t, vaultDir, "Database-Deprecated.md", "# Database Standard\nStatus: Deprecated\nMySQL was historically used.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	pkg, err := eng.Context(contextpkg.ContextRequest{
		Query: "Database",
	})
	if err != nil {
		t.Fatalf("Context failed: %v", err)
	}

	if len(pkg.ConflictGroups) == 0 {
		t.Fatalf("expected conflict group to be detected and preserved")
	}
	cg := pkg.ConflictGroups[0]
	if len(cg.ContradictingNotes) < 2 {
		t.Errorf("expected both contradictory notes in conflict group, got %v", cg.ContradictingNotes)
	}
}

func TestContextEmptyRetrieval(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	writeVaultNote(t, vaultDir, "README.md", "# Welcome\nEdith knowledge base.")
	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	pkg, err := eng.Context(contextpkg.ContextRequest{
		Query: "completelyunrelatedqueryxyz987",
	})
	if err != nil {
		t.Fatalf("Context failed: %v", err)
	}

	if len(pkg.Evidence) != 0 {
		t.Errorf("expected 0 evidence items for nonexistent query, got %d", len(pkg.Evidence))
	}
	if len(pkg.Warnings) == 0 {
		t.Errorf("expected warning for empty retrieval")
	}
}

func TestContextJSONSchemaRoundTrip(t *testing.T) {
	eng, vaultDir := setupTestEngine(t)

	writeVaultNote(t, vaultDir, "Note.md", "# Sample Note\nContent for schema test.")
	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	pkg, err := eng.Context(contextpkg.ContextRequest{
		Query: "Sample",
	})
	if err != nil {
		t.Fatalf("Context failed: %v", err)
	}

	data, err := json.Marshal(pkg)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var decoded contextpkg.ContextPackage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	if decoded.SchemaVersion != contextpkg.SchemaVersion {
		t.Errorf("expected schema version %s, got %s", contextpkg.SchemaVersion, decoded.SchemaVersion)
	}
	if decoded.Query != pkg.Query {
		t.Errorf("expected query %q, got %q", pkg.Query, decoded.Query)
	}
	if len(decoded.Evidence) != len(pkg.Evidence) {
		t.Errorf("expected %d evidence items, got %d", len(pkg.Evidence), len(decoded.Evidence))
	}
}
