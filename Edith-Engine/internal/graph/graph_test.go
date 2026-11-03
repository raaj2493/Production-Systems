package graph_test

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"edith-engine/internal/config"
	"edith-engine/internal/engine"
)

func setupTestEngineWithVault(t *testing.T) (*engine.Engine, string) {
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

func writeNote(t *testing.T, vaultDir, relPath, content string) {
	t.Helper()
	fullPath := filepath.Join(vaultDir, relPath)
	if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
		t.Fatalf("write file %s failed: %v", relPath, err)
	}
}

func TestGraphBasicChainAndBacklinks(t *testing.T) {
	eng, vaultDir := setupTestEngineWithVault(t)

	// Chain: A -> B -> C
	writeNote(t, vaultDir, "NoteA.md", "# Note A\nLinks to [[NoteB]].")
	writeNote(t, vaultDir, "NoteB.md", "# Note B\nLinks to [[NoteC]].")
	writeNote(t, vaultDir, "NoteC.md", "# Note C\nEnd of chain.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	g := eng.Graph()

	// Outgoing from A
	outA, err := g.Outgoing("NoteA.md")
	if err != nil {
		t.Fatalf("Outgoing(NoteA) failed: %v", err)
	}
	if len(outA) != 1 || outA[0].TargetPath != "NoteB.md" {
		t.Fatalf("expected 1 outgoing link to NoteB.md, got %+v", outA)
	}

	// Backlinks to B
	inB, err := g.Backlinks("NoteB.md")
	if err != nil {
		t.Fatalf("Backlinks(NoteB) failed: %v", err)
	}
	if len(inB) != 1 || inB[0].SourcePath != "NoteA.md" {
		t.Fatalf("expected 1 backlink from NoteA.md, got %+v", inB)
	}

	// Backlinks to C
	inC, err := g.Backlinks("NoteC.md")
	if err != nil {
		t.Fatalf("Backlinks(NoteC) failed: %v", err)
	}
	if len(inC) != 1 || inC[0].SourcePath != "NoteB.md" {
		t.Fatalf("expected 1 backlink from NoteB.md, got %+v", inC)
	}

	// Shortest path A -> C
	path, err := g.ShortestPath("NoteA.md", "NoteC.md")
	if err != nil {
		t.Fatalf("ShortestPath failed: %v", err)
	}
	if len(path) != 3 || path[0] != "NoteA.md" || path[1] != "NoteB.md" || path[2] != "NoteC.md" {
		t.Fatalf("expected [NoteA.md NoteB.md NoteC.md], got %v", path)
	}
}

func TestGraphCycleSafety(t *testing.T) {
	eng, vaultDir := setupTestEngineWithVault(t)

	// Cycle: A -> B -> C -> A
	writeNote(t, vaultDir, "NoteA.md", "# Note A\nCycle to [[NoteB]].")
	writeNote(t, vaultDir, "NoteB.md", "# Note B\nCycle to [[NoteC]].")
	writeNote(t, vaultDir, "NoteC.md", "# Note C\nCycle back to [[NoteA]].")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	g := eng.Graph()

	// Traversal should terminate without looping infinitely
	results, err := g.Traverse("NoteA.md", 5, 50)
	if err != nil {
		t.Fatalf("Traverse failed: %v", err)
	}

	// Should visit NoteB and NoteC (start note NoteA is depth 0 and excluded from results)
	seen := make(map[string]bool)
	for _, r := range results {
		if seen[r.Path] {
			t.Fatalf("duplicate node in traversal results: %s", r.Path)
		}
		seen[r.Path] = true
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 unique traversed nodes in cycle, got %d: %+v", len(results), results)
	}
	if !seen["NoteB.md"] || !seen["NoteC.md"] {
		t.Fatalf("expected NoteB.md and NoteC.md in results, got %v", seen)
	}
}

func TestGraphOrphanAndBrokenLinks(t *testing.T) {
	eng, vaultDir := setupTestEngineWithVault(t)

	// NoteA links to missing note
	writeNote(t, vaultDir, "NoteA.md", "# Note A\nRefers to [[MissingTarget]].")
	// NoteB is an orphan with no incoming backlinks
	writeNote(t, vaultDir, "OrphanNote.md", "# Orphan\nNobody links to me.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	g := eng.Graph()

	// Broken links
	broken, err := g.BrokenLinks()
	if err != nil {
		t.Fatalf("BrokenLinks failed: %v", err)
	}
	if len(broken) != 1 || broken[0].RawTarget != "MissingTarget" {
		t.Fatalf("expected 1 broken link to MissingTarget, got %+v", broken)
	}

	// Orphan notes: NoteA has 0 incoming links, OrphanNote has 0 incoming links
	orphans, err := g.Orphans()
	if err != nil {
		t.Fatalf("Orphans failed: %v", err)
	}
	orphanMap := make(map[string]bool)
	for _, o := range orphans {
		orphanMap[o] = true
	}
	if !orphanMap["OrphanNote.md"] || !orphanMap["NoteA.md"] {
		t.Fatalf("expected OrphanNote.md and NoteA.md in orphans, got %v", orphans)
	}
}

func TestGraphAliasesAndAnchors(t *testing.T) {
	eng, vaultDir := setupTestEngineWithVault(t)

	writeNote(t, vaultDir, "Guide.md", "# Guide\n## Introduction\nContent here.")
	writeNote(t, vaultDir, "Index.md", "# Index\nSee [[Guide#Introduction|Getting Started]] for details.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	g := eng.Graph()
	links, err := g.Outgoing("Index.md")
	if err != nil {
		t.Fatalf("Outgoing failed: %v", err)
	}
	if len(links) != 1 {
		t.Fatalf("expected 1 link, got %d", len(links))
	}

	link := links[0]
	if link.TargetPath != "Guide.md" {
		t.Errorf("expected target Guide.md, got %s", link.TargetPath)
	}
	if link.HeadingAnchor != "Introduction" {
		t.Errorf("expected heading anchor 'Introduction', got %q", link.HeadingAnchor)
	}
	if link.DisplayText != "Getting Started" {
		t.Errorf("expected display text 'Getting Started', got %q", link.DisplayText)
	}
}

func TestGraphRenamedAndDeletedNote(t *testing.T) {
	eng, vaultDir := setupTestEngineWithVault(t)

	writeNote(t, vaultDir, "Source.md", "# Source\nPoints to [[Target]].")
	writeNote(t, vaultDir, "Target.md", "# Target\nOriginal target note.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Initial Index failed: %v", err)
	}

	g := eng.Graph()
	links, err := g.Outgoing("Source.md")
	if err != nil || len(links) != 1 || links[0].TargetPath != "Target.md" {
		t.Fatalf("initial link expected Target.md, got %+v", links)
	}

	// Delete Target.md from vault
	if err := os.Remove(filepath.Join(vaultDir, "Target.md")); err != nil {
		t.Fatalf("remove failed: %v", err)
	}

	// Reindex
	summary, err := eng.Index()
	if err != nil {
		t.Fatalf("Index after remove failed: %v", err)
	}
	if summary.RemovedCount != 1 {
		t.Fatalf("expected 1 note removed, got %d", summary.RemovedCount)
	}

	// Broken link should now detect Target
	broken, err := g.BrokenLinks()
	if err != nil {
		t.Fatalf("BrokenLinks failed: %v", err)
	}
	if len(broken) != 1 || broken[0].RawTarget != "Target" {
		t.Fatalf("expected 1 broken link to Target, got %+v", broken)
	}
}

func TestGraphTraversalLimits(t *testing.T) {
	eng, vaultDir := setupTestEngineWithVault(t)

	// Chain: N0 -> N1 -> N2 -> N3 -> N4
	for i := 0; i < 5; i++ {
		content := fmt.Sprintf("# Note %d\nEnd.", i)
		if i < 4 {
			content = fmt.Sprintf("# Note %d\nLink to [[Note%d]].", i, i+1)
		}
		writeNote(t, vaultDir, fmt.Sprintf("Note%d.md", i), content)
	}

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	g := eng.Graph()

	// Depth limit 2 from Note0.md should only return Note1.md and Note2.md
	res, err := g.Traverse("Note0.md", 2, 50)
	if err != nil {
		t.Fatalf("Traverse failed: %v", err)
	}
	if len(res) != 2 {
		t.Fatalf("expected 2 notes at depth <= 2, got %d: %+v", len(res), res)
	}
	for _, r := range res {
		if r.Depth > 2 {
			t.Fatalf("node depth %d exceeded max depth 2: %s", r.Depth, r.Path)
		}
	}

	// Node limit 1
	res1, err := g.Traverse("Note0.md", 4, 1)
	if err != nil {
		t.Fatalf("Traverse failed: %v", err)
	}
	if len(res1) != 1 {
		t.Fatalf("expected exactly 1 note when maxNodes=1, got %d", len(res1))
	}
}

func TestSearchWithRelationships(t *testing.T) {
	eng, vaultDir := setupTestEngineWithVault(t)

	// NoteA: lexical hit on "quantum physics"
	writeNote(t, vaultDir, "Quantum.md", "# Quantum Physics\nExploration of quantum mechanical principles and superposition.")
	// NoteB: links to Quantum.md, but doesn't mention "quantum"
	writeNote(t, vaultDir, "Computing.md", "# Modern Computing\nStudy of hardware architecture and [[Quantum]] principles.")
	// NoteC: completely unrelated
	writeNote(t, vaultDir, "Gardening.md", "# Urban Gardening\nGrowing heirloom tomatoes in small spaces.")

	if _, err := eng.Index(); err != nil {
		t.Fatalf("Index failed: %v", err)
	}

	g := eng.Graph()

	// Lexical search for "superposition" which only appears in Quantum.md
	matches, err := g.SearchWithRelationships("superposition", 10, 1)
	if err != nil {
		t.Fatalf("SearchWithRelationships failed: %v", err)
	}

	if len(matches) < 2 {
		t.Fatalf("expected at least 2 matches (1 lexical + 1 graph connected), got %d: %+v", len(matches), matches)
	}

	// Top match should be direct lexical hit
	if matches[0].RelPath != "Quantum.md" {
		t.Errorf("expected top match to be Quantum.md, got %s", matches[0].RelPath)
	}
	if matches[0].RelationshipHops != 0 {
		t.Errorf("expected 0 hops for direct lexical match, got %d", matches[0].RelationshipHops)
	}

	// Second match should be Computing.md (connected via backlink to search hit)
	if matches[1].RelPath != "Computing.md" {
		t.Errorf("expected second match to be Computing.md, got %s", matches[1].RelPath)
	}
	if matches[1].RelationshipHops != 1 {
		t.Errorf("expected 1 hop for connected note, got %d", matches[1].RelationshipHops)
	}
	if matches[1].InclusionReason == "" {
		t.Errorf("expected inclusion reason to be populated, got empty string")
	}

	// Gardening.md should NOT be present
	for _, m := range matches {
		if m.RelPath == "Gardening.md" {
			t.Errorf("unrelated Gardening.md should not be included in results")
		}
	}
}
