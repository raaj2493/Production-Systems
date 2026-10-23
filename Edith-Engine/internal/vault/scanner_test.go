package vault

import (
	"os"
	"path/filepath"
	"testing"
)

func TestScanner(t *testing.T) {
	tempVault := t.TempDir()

	// Create test file structure:
	// README.md
	// 00-System/Protocol.md
	// 01-Inbox/QuickNote.md
	// Nested/Deeper/DeepNote.md
	// Unicode/日本語ノート.md
	// Unicode/Café.md
	// .obsidian/config.md (should be ignored)
	// .git/HEAD.md (should be ignored)
	// node_modules/pkg/README.md (should be ignored)
	// Edith-Engine/main.go (should be ignored)
	// other.txt (non-markdown, should be ignored)

	dirs := []string{
		"00-System",
		"01-Inbox",
		"Nested/Deeper",
		"Unicode",
		".obsidian",
		".git",
		"node_modules/pkg",
		"Edith-Engine",
	}

	for _, d := range dirs {
		if err := os.MkdirAll(filepath.Join(tempVault, d), 0755); err != nil {
			t.Fatalf("failed to create dir %s: %v", d, err)
		}
	}

	files := map[string]string{
		"README.md":                  "# Main Readme",
		"00-System/Protocol.md":      "# System Protocol",
		"01-Inbox/QuickNote.md":      "# Quick Note",
		"Nested/Deeper/DeepNote.md":  "# Deep Note",
		"Unicode/日本語ノート.md":          "# Japanese Note",
		"Unicode/Café.md":            "# Cafe Note",
		".obsidian/config.md":        "# Obsidian internal",
		".git/HEAD.md":               "# Git internal",
		"node_modules/pkg/README.md": "# Dep Readme",
		"Edith-Engine/note.md":       "# Engine internal",
		"other.txt":                  "text file",
	}

	for path, content := range files {
		fullPath := filepath.Join(tempVault, path)
		if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
			t.Fatalf("failed to write %s: %v", path, err)
		}
	}

	// Create symlink tests
	// 1. Unsafe symlink pointing outside vault
	outsideDir := t.TempDir()
	outsideFile := filepath.Join(outsideDir, "secret.md")
	if err := os.WriteFile(outsideFile, []byte("# Secret Outside"), 0644); err != nil {
		t.Fatalf("failed to write outside file: %v", err)
	}
	unsafeLink := filepath.Join(tempVault, "unsafe_symlink.md")
	if err := os.Symlink(outsideFile, unsafeLink); err != nil {
		t.Logf("symlink creation skipped (platform limitation): %v", err)
	}

	scanner, err := NewScanner(tempVault)
	if err != nil {
		t.Fatalf("NewScanner error: %v", err)
	}

	notes, err := scanner.Scan()
	if err != nil {
		t.Fatalf("Scan error: %v", err)
	}

	expectedNotes := map[string]bool{
		"00-System/Protocol.md":     true,
		"01-Inbox/QuickNote.md":     true,
		"Nested/Deeper/DeepNote.md": true,
		"README.md":                 true,
		"Unicode/Café.md":           true,
		"Unicode/日本語ノート.md":         true,
	}

	if len(notes) != len(expectedNotes) {
		t.Fatalf("expected %d notes, got %d: %v", len(expectedNotes), len(notes), notes)
	}

	for _, n := range notes {
		if !expectedNotes[n] {
			t.Errorf("unexpected note discovered: %s", n)
		}
	}

	// Ensure unsafe symlink was not included
	for _, n := range notes {
		if n == "unsafe_symlink.md" {
			t.Errorf("unsafe symlink should not have been indexed")
		}
	}
}
