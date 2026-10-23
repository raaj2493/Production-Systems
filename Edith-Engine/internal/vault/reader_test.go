package vault

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestReader(t *testing.T) {
	tempVault := t.TempDir()

	contentNote1 := `# Architecture of Edith

This connects to [[00-System/Edith-Protocol|Protocol]] and [[Inbox#Today]].
External link to [Karpathy Gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
Image: ![Diagram](assets/arch.png) should not be treated as a markdown note link.
Local relative link: [Inbox Notes](01-Inbox/README.md).
`
	p1 := filepath.Join(tempVault, "Architecture.md")
	if err := os.WriteFile(p1, []byte(contentNote1), 0644); err != nil {
		t.Fatalf("failed to write test note: %v", err)
	}

	reader, err := NewReader(tempVault)
	if err != nil {
		t.Fatalf("NewReader failed: %v", err)
	}

	note, err := reader.ReadNote("Architecture.md")
	if err != nil {
		t.Fatalf("ReadNote failed: %v", err)
	}

	if note.Metadata.Title != "Architecture of Edith" {
		t.Errorf("expected title 'Architecture of Edith', got %q", note.Metadata.Title)
	}

	if len(note.Metadata.ContentHash) != 64 {
		t.Errorf("expected 64-char sha256 hash, got %q", note.Metadata.ContentHash)
	}

	if note.Metadata.SizeBytes != int64(len(contentNote1)) {
		t.Errorf("expected size %d, got %d", len(contentNote1), note.Metadata.SizeBytes)
	}

	// Verify link extraction
	// [[00-System/Edith-Protocol|Protocol]]
	// [[Inbox#Today]]
	// [Karpathy Gist](https://gist...)
	// [Inbox Notes](01-Inbox/README.md)
	// (not image)
	if len(note.Links) != 4 {
		t.Fatalf("expected 4 links extracted, got %d: %+v", len(note.Links), note.Links)
	}

	wikilink1 := note.Links[0]
	if !wikilink1.IsWikiLink || wikilink1.CleanTarget != "00-System/Edith-Protocol" || wikilink1.DisplayText != "Protocol" {
		t.Errorf("unexpected wikilink 1: %+v", wikilink1)
	}

	wikilink2 := note.Links[1]
	if !wikilink2.IsWikiLink || wikilink2.CleanTarget != "Inbox" || wikilink2.HeadingAnchor != "Today" {
		t.Errorf("unexpected wikilink 2: %+v", wikilink2)
	}

	extLink := note.Links[2]
	if wikilink1.IsExternal || !extLink.IsExternal || extLink.DisplayText != "Karpathy Gist" {
		t.Errorf("unexpected external link: %+v", extLink)
	}

	localMdLink := note.Links[3]
	if localMdLink.IsExternal || localMdLink.CleanTarget != "01-Inbox/README.md" {
		t.Errorf("unexpected local markdown link: %+v", localMdLink)
	}

	// Test Path Traversal rejection
	_, err = reader.ReadNote("../../etc/passwd")
	if err == nil {
		t.Errorf("expected path traversal error, got nil")
	}

	_, err = reader.ReadNote("../outside.md")
	if err == nil {
		t.Errorf("expected path traversal error, got nil")
	}

	// Test Non-existent file
	_, err = reader.ReadNote("nonexistent.md")
	if err == nil {
		t.Errorf("expected error for non-existent note, got nil")
	}
}

func TestExtractTitle(t *testing.T) {
	tests := []struct {
		name     string
		content  string
		relPath  string
		expected string
	}{
		{
			name:     "Markdown H1",
			content:  "# My First Note\nContent here",
			relPath:  "note.md",
			expected: "My First Note",
		},
		{
			name:     "Markdown H2 when no H1",
			content:  "Some text\n\n## Sub Heading\nMore text",
			relPath:  "note.md",
			expected: "Sub Heading",
		},
		{
			name:     "YAML Frontmatter title",
			content:  "---\ntitle: \"Custom Frontmatter Title\"\nauthor: me\n---\n# Ignored Heading\nBody",
			relPath:  "custom.md",
			expected: "Custom Frontmatter Title",
		},
		{
			name:     "Heading with wikilink",
			content:  "# [[Real-Target|Formatted Heading]]\nBody",
			relPath:  "linked.md",
			expected: "Formatted Heading",
		},
		{
			name:     "Filename fallback",
			content:  "No headings anywhere in this file",
			relPath:  "Notes/Daily-Log.md",
			expected: "Daily-Log",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := ExtractTitle(tc.content, tc.relPath)
			if got != tc.expected {
				t.Errorf("ExtractTitle() = %q, want %q", got, tc.expected)
			}
		})
	}
}

func TestExtractLinksCodeBlocksAndInline(t *testing.T) {
	template := `# Code and Inline Test

Here is active prose with a [[real_link]].
Here is an inline code snippet with @[[ignored_inline]]@ and @[ignored_md](target.md)@.
And another active link: [Active MD Link](doc.md).

@@@markdown
This is inside a fenced code block:
[[code_block_wikilink]]
[code_block_md](some/path.md)
@@@

~~~go
// Inside tilde fenced code block:
[[tilde_wikilink]]
~~~

Back in regular prose with [[another_real_link]].
`
	realContent := strings.ReplaceAll(template, "@", "`")

	links := ExtractLinks(realContent, "test.md")

	if len(links) != 3 {
		t.Fatalf("expected 3 links extracted, got %d: %+v", len(links), links)
	}

	expectedTargets := []string{"real_link", "doc.md", "another_real_link"}
	for i, exp := range expectedTargets {
		if links[i].CleanTarget != exp {
			t.Errorf("link[%d]: expected target %q, got %q", i, exp, links[i].CleanTarget)
		}
	}
}
