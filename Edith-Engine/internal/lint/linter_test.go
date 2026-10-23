package lint

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"edith-engine/internal/store"
	"edith-engine/internal/vault"
)

func TestLinter(t *testing.T) {
	tempVault := t.TempDir()

	// Setup notes:
	// 1. README.md -> links to NoteA.md and NonExistent.md
	// 2. NoteA.md -> links to NoteB.md
	// 3. NoteB.md -> no links
	// 4. Orphan.md -> no inbound links
	// 5. Dupe1.md and Dupe2.md -> identical content

	files := map[string]string{
		"README.md":       "# Readme\nLinks: [[NoteA]], [[NonExistent]], and [Note B](NoteB.md)",
		"NoteA.md":        "# Note A\nLinks: [[NoteB]]",
		"NoteB.md":        "# Note B\nTerminal note",
		"Orphan.md":       "# Orphan Note\nNo one links to me",
		"Dupe1.md":        "# Dupe\nIdentical content here",
		"Dupe2.md":        "# Dupe\nIdentical content here",
		"NoHeading.md":    "Just body text without any markdown heading",
		"03-Wiki/Synt.md": "# Synthesis\nSynthesized knowledge without sources",
	}

	for p, content := range files {
		fullPath := filepath.Join(tempVault, p)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("mkdir failed: %v", err)
		}
		if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
			t.Fatalf("write file %s failed: %v", p, err)
		}
	}

	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("store.Open failed: %v", err)
	}
	defer db.Close()

	// Index NoteA and a deleted note to test stale index detection
	reader, _ := vault.NewReader(tempVault)
	noteA, _ := reader.ReadNote("NoteA.md")
	_ = db.IndexNote(noteA)

	// Simulate deleted note in DB
	fakeDeletedNote := &vault.Note{
		Metadata: vault.NoteMetadata{
			RelPath:     "DeletedNote.md",
			Title:       "Deleted Note",
			ContentHash: "fakehash",
			SizeBytes:   100,
		},
		Content: "Deleted content",
	}
	_ = db.IndexNote(fakeDeletedNote)

	linter, err := NewLinter(tempVault, db)
	if err != nil {
		t.Fatalf("NewLinter failed: %v", err)
	}

	report, err := linter.Run()
	if err != nil {
		t.Fatalf("linter.Run failed: %v", err)
	}

	// Verify findings
	var foundBrokenLink, foundOrphan, foundDupe, foundStale, foundNoHeading, foundMissingSource bool
	for _, f := range report.Findings {
		switch f.Category {
		case CategoryBrokenLink:
			if f.Path == "README.md" {
				foundBrokenLink = true
			}
		case CategoryOrphanNote:
			if f.Path == "Orphan.md" {
				foundOrphan = true
			}
		case CategoryDuplicate:
			foundDupe = true
		case CategoryStaleIndex:
			if f.Path == "DeletedNote.md" {
				foundStale = true
			}
		case CategorySuspiciousTitle:
			if f.Path == "NoHeading.md" {
				foundNoHeading = true
			}
		case CategoryMissingSource:
			if f.Path == "03-Wiki/Synt.md" {
				foundMissingSource = true
			}
		}
	}

	if !foundBrokenLink {
		t.Errorf("expected broken link finding for NonExistent in README.md")
	}
	if !foundOrphan {
		t.Errorf("expected orphan finding for Orphan.md")
	}
	if !foundDupe {
		t.Errorf("expected duplicate finding for Dupe1/Dupe2")
	}
	if !foundStale {
		t.Errorf("expected stale index finding for DeletedNote.md")
	}
	if !foundNoHeading {
		t.Errorf("expected suspicious title finding for NoHeading.md")
	}
	if !foundMissingSource {
		t.Errorf("expected missing source finding for 03-Wiki/Synt.md")
	}
}

func TestLinterFalsePositivesAndGenuineBrokenLinks(t *testing.T) {
	tempVault := t.TempDir()

	files := map[string]string{
		"00-System/Edith-Protocol.md": "# Edith Protocol\n- Connect related concepts using Obsidian [[wikilinks]].",
		"Edith/Welcome.md":            "This is your new *vault*.\nMake a note of something, [[create a link]], or try [the Importer](obsidian://show-plugin?id=obsidian-importer)!\nWhen you are ready, delete this note and make the vault your own.",
		"Notes/RealNote.md":           "# Real Note\nThis note exists and links to [[00-System/Edith-Protocol]].",
		"Notes/BrokenNote.md":         "# Broken Note\nThis note links to a [[TrulyBrokenLink]] that does not exist.",
		"Notes/CodeNote.md":           "# Code Note\n`[[ignored_in_inline_code]]` should be ignored.\n\n```markdown\n[[ignored_in_code_block]]\n```\nNormal text.",
	}

	for p, content := range files {
		fullPath := filepath.Join(tempVault, p)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("mkdir failed: %v", err)
		}
		if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
			t.Fatalf("write file %s failed: %v", p, err)
		}
	}

	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("store.Open failed: %v", err)
	}
	defer db.Close()

	linter, err := NewLinter(tempVault, db)
	if err != nil {
		t.Fatalf("NewLinter failed: %v", err)
	}

	report, err := linter.Run()
	if err != nil {
		t.Fatalf("linter.Run failed: %v", err)
	}

	// 1. Verify that TrulyBrokenLink is reported as an ERROR
	var foundGenuineError bool
	for _, f := range report.Findings {
		if f.Category == CategoryBrokenLink && f.Severity == SeverityError && f.Path == "Notes/BrokenNote.md" {
			foundGenuineError = true
		}
	}
	if !foundGenuineError {
		t.Errorf("expected genuine broken link error in Notes/BrokenNote.md")
	}

	// 2. Verify that [[wikilinks]] in 00-System/Edith-Protocol.md is NOT an error
	for _, f := range report.Findings {
		if f.Path == "00-System/Edith-Protocol.md" && f.Severity == SeverityError {
			t.Errorf("unexpected error finding for 00-System/Edith-Protocol.md: %+v", f)
		}
	}

	// 3. Verify that [[create a link]] in Edith/Welcome.md is NOT an error
	for _, f := range report.Findings {
		if f.Path == "Edith/Welcome.md" && f.Severity == SeverityError {
			t.Errorf("unexpected error finding for Edith/Welcome.md: %+v", f)
		}
	}

	// 4. Verify that code block and inline code links are NOT in findings at all
	for _, f := range report.Findings {
		if strings.Contains(f.Message, "ignored_in_inline_code") || strings.Contains(f.Message, "ignored_in_code_block") {
			t.Errorf("link inside code block or inline code should not be reported: %+v", f)
		}
	}

	// 5. Verify TotalErrors is exactly 1 (only the truly broken link)
	if report.TotalErrors != 1 {
		t.Errorf("expected TotalErrors == 1, got %d", report.TotalErrors)
	}
}
