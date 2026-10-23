package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setupTestCLI(t *testing.T) (*bytes.Buffer, *bytes.Buffer, string, string) {
	tempDir := t.TempDir()
	vaultDir := filepath.Join(tempDir, "vault")
	if err := os.MkdirAll(vaultDir, 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}

	dbPath := filepath.Join(tempDir, "edith_cli.db")

	// Create test note
	notePath := filepath.Join(vaultDir, "README.md")
	if err := os.WriteFile(notePath, []byte("# Welcome to Edith CLI\nTesting command line interface."), 0644); err != nil {
		t.Fatalf("write note failed: %v", err)
	}

	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	return stdout, stderr, vaultDir, dbPath
}

func TestCLIHelpAndUnknown(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	code := c.Execute([]string{"help"})
	if code != 0 {
		t.Errorf("expected 0 exit code for help, got %d", code)
	}
	if !strings.Contains(stdout.String(), "Edith Engine") {
		t.Errorf("expected help text in stdout")
	}

	stdout.Reset()
	stderr.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "unknown-command"})
	if code != 1 {
		t.Errorf("expected non-zero exit code for unknown command, got %d", code)
	}
}

func TestCLIScanAndIndexAndSearch(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	// 1. Scan
	stdout.Reset()
	code := c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "scan"})
	if code != 0 {
		t.Fatalf("scan returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "Discovered 1 Markdown notes") {
		t.Errorf("expected scan output to mention 1 note, got: %s", stdout.String())
	}

	// 2. Index
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "index"})
	if code != 0 {
		t.Fatalf("index returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "Added:      +1") {
		t.Errorf("expected index output to show +1 added, got: %s", stdout.String())
	}

	// 3. Search
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "search", "command", "line"})
	if code != 0 {
		t.Fatalf("search returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "Welcome to Edith CLI") {
		t.Errorf("expected search output to match title, got: %s", stdout.String())
	}

	// 4. Read note
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "read", "README.md"})
	if code != 0 {
		t.Fatalf("read returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "Testing command line interface") {
		t.Errorf("expected read output to show note content, got: %s", stdout.String())
	}

	// 5. Read note path traversal rejected
	stdout.Reset()
	stderr.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "read", "../../etc/passwd"})
	if code == 0 {
		t.Errorf("expected non-zero exit code for path traversal")
	}

	// 6. Status
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "status"})
	if code != 0 {
		t.Fatalf("status returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "Notes Indexed:    1") {
		t.Errorf("expected status to report 1 note indexed, got: %s", stdout.String())
	}

	// 7. Lint
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "lint"})
	if code != 0 {
		t.Fatalf("lint returned %d: %s", code, stderr.String())
	}

	// 8. Reindex
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "reindex"})
	if code != 0 {
		t.Fatalf("reindex returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "Full Reindex Complete") {
		t.Errorf("expected reindex completion output, got: %s", stdout.String())
	}
}

func TestCLIProposals(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	// Create proposal
	code := c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "proposals", "create", "README.md", "Add wiki link", "# Welcome\n[[Wiki]] added."})
	if code != 0 {
		t.Fatalf("proposals create returned %d: %s", code, stderr.String())
	}

	// List proposals
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "proposals", "list"})
	if code != 0 {
		t.Fatalf("proposals list returned %d: %s", code, stderr.String())
	}
	outStr := stdout.String()
	if !strings.Contains(outStr, "README.md") || !strings.Contains(outStr, "Add wiki link") {
		t.Fatalf("unexpected proposals list: %s", outStr)
	}

	// Extract proposal ID from list
	lines := strings.Split(strings.TrimSpace(outStr), "\n")
	lastLine := lines[len(lines)-1]
	fields := strings.Fields(lastLine)
	propID := fields[0]

	// Approve proposal
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "proposals", "approve", propID, "Looks good"})
	if code != 0 {
		t.Fatalf("proposals approve returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "successfully approved") {
		t.Errorf("unexpected approval message: %s", stdout.String())
	}

	// Verify file was updated on disk
	content, _ := os.ReadFile(filepath.Join(vaultDir, "README.md"))
	if string(content) != "# Welcome\n[[Wiki]] added." {
		t.Errorf("expected updated content on disk, got: %s", string(content))
	}
}

func TestCLISearchFeatures(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	// Index initial note
	code := c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "index"})
	if code != 0 {
		t.Fatalf("index failed: %v", stderr.String())
	}

	// 1. Prefix query
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "search", "Welc*"})
	if code != 0 {
		t.Fatalf("search with prefix failed: %v", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Welcome to Edith CLI") {
		t.Errorf("expected prefix search to match title, got: %s", stdout.String())
	}

	// 2. Title-only match excerpt
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "search", "Welcome"})
	if code != 0 {
		t.Fatalf("search title-only failed: %v", stderr.String())
	}
	if !strings.Contains(stdout.String(), ">>>Welcome<<<") {
		t.Errorf("expected title snippet to highlight >>>Welcome<<<, got: %s", stdout.String())
	}

	// 3. Quoted phrase search
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "search", `"command line"`})
	if code != 0 {
		t.Fatalf("search quoted phrase failed: %v", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Found 1 matching notes") {
		t.Errorf("expected 1 match for quoted phrase, got: %s", stdout.String())
	}

	// 4. JSON search output
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "--json", "search", "interface"})
	if code != 0 {
		t.Fatalf("search JSON failed: %v", stderr.String())
	}
	if !strings.Contains(stdout.String(), `"rel_path": "README.md"`) || !strings.Contains(stdout.String(), `"rank":`) {
		t.Errorf("expected valid JSON search result, got: %s", stdout.String())
	}
}
