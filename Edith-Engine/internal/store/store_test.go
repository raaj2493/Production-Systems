package store

import (
	"path/filepath"
	"strings"
	"testing"
	"time"

	"edith-engine/internal/vault"
)

func setupTestDB(t *testing.T) *DB {
	db, err := Open(":memory:")
	if err != nil {
		t.Fatalf("failed to open in-memory db: %v", err)
	}
	t.Cleanup(func() {
		db.Close()
	})
	return db
}

func TestStoreNotesAndFTS(t *testing.T) {
	db := setupTestDB(t)

	note := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "00-System/Edith-Protocol.md",
			Title:       "Edith Protocol",
			ModTime:     time.Now().UTC().Truncate(time.Second),
			ContentHash: "a1b2c3d4e5f678901234567890abcdef1234567890abcdef1234567890abcdef",
			SizeBytes:   512,
		},
		Content: "# Edith Protocol\n\nEdith is my personal lifelong knowledge system. Markdown is the durable store.",
	}

	if err := db.IndexNote(note); err != nil {
		t.Fatalf("IndexNote failed: %v", err)
	}

	// 1. Get note
	fetched, err := db.GetNote(note.Metadata.RelPath)
	if err != nil {
		t.Fatalf("GetNote failed: %v", err)
	}
	if fetched == nil {
		t.Fatalf("expected note, got nil")
	}
	if fetched.Title != "Edith Protocol" {
		t.Errorf("expected title 'Edith Protocol', got %q", fetched.Title)
	}

	// 2. Search
	results, err := db.Search("lifelong knowledge", 10)
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	if results[0].RelPath != note.Metadata.RelPath {
		t.Errorf("expected relPath %s, got %s", note.Metadata.RelPath, results[0].RelPath)
	}
	if len(results[0].Snippet) == 0 {
		t.Errorf("expected non-empty snippet")
	}

	// 3. Search with malformed query (unclosed quotes, dashes, special chars)
	malformedQueries := []string{
		`"unclosed quote`,
		`local-first`,
		`NOT`,
		`:::`,
		`   `,
		`()`,
	}
	for _, q := range malformedQueries {
		res, err := db.Search(q, 10)
		if err != nil {
			t.Errorf("Search(%q) returned unexpected error: %v", q, err)
		}
		_ = res
	}

	// 4. Update note
	note.Content = "# Edith Protocol Updated\n\nUpdated information about second brain."
	note.Metadata.Title = "Edith Protocol Updated"
	if err := db.IndexNote(note); err != nil {
		t.Fatalf("IndexNote update failed: %v", err)
	}

	resUpdated, err := db.Search("brain", 10)
	if err != nil {
		t.Fatalf("Search after update failed: %v", err)
	}
	if len(resUpdated) != 1 {
		t.Fatalf("expected 1 result after update, got %d", len(resUpdated))
	}

	// 5. Delete note
	if err := db.DeleteNote(note.Metadata.RelPath); err != nil {
		t.Fatalf("DeleteNote failed: %v", err)
	}

	resDeleted, err := db.Search("brain", 10)
	if err != nil {
		t.Fatalf("Search after delete failed: %v", err)
	}
	if len(resDeleted) != 0 {
		t.Fatalf("expected 0 results after delete, got %d", len(resDeleted))
	}
}

func TestActivityAndProposals(t *testing.T) {
	db := setupTestDB(t)

	// Activity log test
	if err := db.LogActivity("index", 12, 2, 10, 0, "Incremental index run completed"); err != nil {
		t.Fatalf("LogActivity failed: %v", err)
	}

	logs, err := db.ListActivity(10)
	if err != nil {
		t.Fatalf("ListActivity failed: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("expected 1 activity log, got %d", len(logs))
	}
	if logs[0].Operation != "index" || logs[0].DiscoveredCount != 12 {
		t.Errorf("unexpected activity record: %+v", logs[0])
	}

	// Proposal test
	prop := &Proposal{
		ID:              "prop-12345",
		TargetPath:      "03-Wiki/Knowledge.md",
		TargetHash:      "hash123",
		Reason:          "Add reference link",
		SourcePaths:     []string{"02-Raw-Sources/source1.md"},
		ProposedContent: "# Knowledge\n\nNew synthesized content.",
		Status:          "pending",
		CreatedAt:       time.Now().UTC(),
	}

	if err := db.SaveProposal(prop); err != nil {
		t.Fatalf("SaveProposal failed: %v", err)
	}

	pFetched, err := db.GetProposal(prop.ID)
	if err != nil {
		t.Fatalf("GetProposal failed: %v", err)
	}
	if pFetched == nil || pFetched.TargetPath != prop.TargetPath {
		t.Fatalf("unexpected fetched proposal: %+v", pFetched)
	}

	props, err := db.ListProposals("pending")
	if err != nil {
		t.Fatalf("ListProposals failed: %v", err)
	}
	if len(props) != 1 {
		t.Fatalf("expected 1 pending proposal, got %d", len(props))
	}

	if err := db.UpdateProposalStatus(prop.ID, "approved", "Approved by user"); err != nil {
		t.Fatalf("UpdateProposalStatus failed: %v", err)
	}

	pApproved, err := db.GetProposal(prop.ID)
	if err != nil {
		t.Fatalf("GetProposal after approval failed: %v", err)
	}
	if pApproved.Status != "approved" || pApproved.ReviewNotes != "Approved by user" {
		t.Errorf("unexpected status after update: %+v", pApproved)
	}

	// Revision test
	rev := &Revision{
		ProposalID:      prop.ID,
		TargetPath:      prop.TargetPath,
		OriginalContent: "# Old Content",
		OriginalHash:    "oldhash",
		AppliedAt:       time.Now().UTC(),
	}
	if err := db.SaveRevision(rev); err != nil {
		t.Fatalf("SaveRevision failed: %v", err)
	}
}

func TestFileBackedDB(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "edith_test.db")

	db, err := Open(dbPath)
	if err != nil {
		t.Fatalf("Open file-backed DB failed: %v", err)
	}

	stats, err := db.GetStats()
	if err != nil {
		t.Fatalf("GetStats failed: %v", err)
	}
	if stats.TotalNotes != 0 {
		t.Errorf("expected 0 notes, got %d", stats.TotalNotes)
	}
	if stats.DBSizeBytes == 0 {
		t.Errorf("expected non-zero db file size")
	}

	db.Close()
}

func TestSearchBM25TitleRanking(t *testing.T) {
	db := setupTestDB(t)

	// Note A matches "benchmark" in Title only.
	noteA := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "01-TitleMatch.md",
			Title:       "Benchmark Analysis Guide",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashA",
			SizeBytes:   256,
		},
		Content: "# Notes on System Performance\n\nDiscussion about evaluation and testing procedures.",
	}

	// Note B matches "benchmark" in Content only.
	noteB := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "02-BodyMatch.md",
			Title:       "Performance Overview Guide",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashB",
			SizeBytes:   256,
		},
		Content: "# Notes on System Performance\n\nDiscussion about benchmark and testing procedures.",
	}

	if err := db.IndexNote(noteA); err != nil {
		t.Fatalf("IndexNote noteA failed: %v", err)
	}
	if err := db.IndexNote(noteB); err != nil {
		t.Fatalf("IndexNote noteB failed: %v", err)
	}

	results, err := db.Search("benchmark", 10)
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}

	// Note A (title match) must rank higher (first in ORDER BY score ASC) than Note B (body match).
	// With SQLite BM25, higher relevance yields a lower (more negative) score.
	if results[0].RelPath != noteA.Metadata.RelPath {
		t.Errorf("expected title match %s to rank first, got %s", noteA.Metadata.RelPath, results[0].RelPath)
	}
	if results[1].RelPath != noteB.Metadata.RelPath {
		t.Errorf("expected body match %s to rank second, got %s", noteB.Metadata.RelPath, results[1].RelPath)
	}
	if results[0].Rank >= results[1].Rank {
		t.Errorf("expected title match score (%f) to be lower than body match score (%f)", results[0].Rank, results[1].Rank)
	}
}

func TestSearchSnippetTitleOnly(t *testing.T) {
	db := setupTestDB(t)

	note := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "03-GraphTheory.md",
			Title:       "Graph Theory and Network Topology",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashGraph",
			SizeBytes:   256,
		},
		Content: "# Overview\n\nDetailed study of tree traversal and connectivity algorithms.",
	}

	if err := db.IndexNote(note); err != nil {
		t.Fatalf("IndexNote failed: %v", err)
	}

	// Search for "Topology" which appears strictly in the title
	results, err := db.Search("Topology", 10)
	if err != nil {
		t.Fatalf("Search failed: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}

	// The snippet must highlight the matched term in the title
	if !strings.Contains(results[0].Snippet, ">>>Topology<<<") {
		t.Errorf("expected snippet to highlight >>>Topology<<<, got: %q", results[0].Snippet)
	}
}

func TestSearchPrefixWildcard(t *testing.T) {
	db := setupTestDB(t)

	noteOpt := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "04-Optimize.md",
			Title:       "Performance Optimization",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashOpt",
			SizeBytes:   256,
		},
		Content: "Strategies to optimize runtime execution.",
	}
	noteOptimal := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "05-Optimal.md",
			Title:       "Routing Solutions",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashOptimal",
			SizeBytes:   256,
		},
		Content: "Selecting the optimal network path.",
	}
	noteUnrelated := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "06-Unrelated.md",
			Title:       "Database Indexing",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashUnrelated",
			SizeBytes:   256,
		},
		Content: "B-Tree structures and storage design.",
	}

	for _, n := range []*vault.Note{noteOpt, noteOptimal, noteUnrelated} {
		if err := db.IndexNote(n); err != nil {
			t.Fatalf("IndexNote failed: %v", err)
		}
	}

	// 1. Explicit prefix wildcard matches both optimize and optimal
	resPrefix, err := db.Search("optim*", 10)
	if err != nil {
		t.Fatalf("Search optim* failed: %v", err)
	}
	if len(resPrefix) != 2 {
		t.Fatalf("expected 2 results for optim*, got %d", len(resPrefix))
	}

	// 2. Exact token without wildcard does NOT match optimize or optimal
	resExact, err := db.Search("optim", 10)
	if err != nil {
		t.Fatalf("Search optim failed: %v", err)
	}
	if len(resExact) != 0 {
		t.Fatalf("expected 0 results for exact optim without wildcard, got %d", len(resExact))
	}

	// 3. Quoted prefix wildcard "optim"* matches both
	resQuotedPrefix, err := db.Search(`"optim"*`, 10)
	if err != nil {
		t.Fatalf("Search quoted prefix failed: %v", err)
	}
	if len(resQuotedPrefix) != 2 {
		t.Fatalf("expected 2 results for quoted prefix, got %d", len(resQuotedPrefix))
	}

	// 4. Prefix query combined with another term requires both
	resPrefixAnd, err := db.Search("optim* network", 10)
	if err != nil {
		t.Fatalf("Search prefix and failed: %v", err)
	}
	if len(resPrefixAnd) != 1 || resPrefixAnd[0].RelPath != noteOptimal.Metadata.RelPath {
		t.Fatalf("expected 1 result (noteOptimal) for 'optim* network', got %d", len(resPrefixAnd))
	}
}

func TestSearchMixedPhrasesAndAND(t *testing.T) {
	db := setupTestDB(t)

	noteContiguous := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "07-Contiguous.md",
			Title:       "Algorithm Strategy",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashContig",
			SizeBytes:   256,
		},
		Content: "Always start with a brute force approach, then optimize later.",
	}
	noteSeparated := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "08-Separated.md",
			Title:       "Physics Calculation",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashSep",
			SizeBytes:   256,
		},
		Content: "He used brute computational strength and force of will to optimize the engine.",
	}
	noteNoOptimize := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "09-NoOptimize.md",
			Title:       "Pure Brute Force",
			ModTime:     time.Now().UTC(),
			ContentHash: "hashNoOpt",
			SizeBytes:   256,
		},
		Content: "A pure brute force search without any extra steps.",
	}

	for _, n := range []*vault.Note{noteContiguous, noteSeparated, noteNoOptimize} {
		if err := db.IndexNote(n); err != nil {
			t.Fatalf("IndexNote failed: %v", err)
		}
	}

	// 1. Mixed query with quoted phrase: "brute force" optimize
	// Requires the contiguous phrase "brute force" AND the word "optimize"
	resMixed, err := db.Search(`"brute force" optimize`, 10)
	if err != nil {
		t.Fatalf("Search mixed phrase failed: %v", err)
	}
	if len(resMixed) != 1 {
		t.Fatalf("expected 1 result for '\"brute force\" optimize', got %d", len(resMixed))
	}
	if resMixed[0].RelPath != noteContiguous.Metadata.RelPath {
		t.Errorf("expected %s, got %s", noteContiguous.Metadata.RelPath, resMixed[0].RelPath)
	}

	// 2. Unquoted multiword query: brute force optimize
	// Matches both notes because contiguous sequence is not required when unquoted
	resMultiword, err := db.Search("brute force optimize", 10)
	if err != nil {
		t.Fatalf("Search multiword failed: %v", err)
	}
	if len(resMultiword) != 2 {
		t.Fatalf("expected 2 results for unquoted multiword, got %d", len(resMultiword))
	}

	// 3. Multiword query with explicit AND word: "brute force" AND optimize
	resExplicitAND, err := db.Search(`"brute force" AND optimize`, 10)
	if err != nil {
		t.Fatalf("Search explicit AND failed: %v", err)
	}
	if len(resExplicitAND) != 1 || resExplicitAND[0].RelPath != noteContiguous.Metadata.RelPath {
		t.Fatalf("expected 1 result for '\"brute force\" AND optimize', got %d", len(resExplicitAND))
	}
}

func TestBuildFTSQueryUnit(t *testing.T) {
	cases := []struct {
		input    string
		expected string
	}{
		{"optimize", `"optimize"`},
		{"lifelong knowledge", `"lifelong" "knowledge"`},
		{`"brute force" optimize`, `"brute force" "optimize"`},
		{"optim*", `"optim"*`},
		{`"optim"*`, `"optim"*`},
		{`"optim*"`, `"optim"*`},
		{"local-first", `"local-first"`},
		{"-local-first-", `"local-first"`},
		{"NOT", `"NOT"`},
		{`"NOT"`, `"NOT"`},
		{"apple AND banana", `"apple" "banana"`},
		{"apple OR banana", `"apple" "banana"`},
		{`"unclosed quote`, `"unclosed quote"`},
		{":::", ""},
		{"()", ""},
		{"   ", ""},
		{"*", ""},
		{"***", ""},
		{"*optim", `"optim"`},
		{"optim**", `"optim"*`},
	}

	for _, tc := range cases {
		actual := buildFTSQuery(tc.input)
		if actual != tc.expected {
			t.Errorf("buildFTSQuery(%q) = %q, expected %q", tc.input, actual, tc.expected)
		}
	}
}
