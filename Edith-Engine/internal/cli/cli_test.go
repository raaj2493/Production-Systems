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

	// Show proposal
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "proposals", "show", propID})
	if code != 0 {
		t.Fatalf("proposals show returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "APPROVED") || !strings.Contains(stdout.String(), "Add wiki link") {
		t.Errorf("unexpected proposals show output: %s", stdout.String())
	}

	// List revisions
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "proposals", "revisions", "README.md"})
	if code != 0 {
		t.Fatalf("proposals revisions returned %d: %s", code, stderr.String())
	}
	revsOut := stdout.String()
	if !strings.Contains(revsOut, "README.md") {
		t.Fatalf("expected revisions table to contain README.md: %s", revsOut)
	}

	// Extract revision ID
	revLines := strings.Split(strings.TrimSpace(revsOut), "\n")
	lastRevLine := revLines[len(revLines)-1]
	revFields := strings.Fields(lastRevLine)
	revID := revFields[0]

	// Restore revision
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "proposals", "restore", revID, "Testing rollback"})
	if code != 0 {
		t.Fatalf("proposals restore returned %d: %s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "Successfully restored") {
		t.Errorf("unexpected restore output: %s", stdout.String())
	}

	// Verify file on disk is restored to original content
	restoredContent, _ := os.ReadFile(filepath.Join(vaultDir, "README.md"))
	if !strings.Contains(string(restoredContent), "Testing command line interface") {
		t.Errorf("expected original content to be restored, got: %s", string(restoredContent))
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

func TestCLIGraphFeatures(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	// Create interconnected notes
	note1 := filepath.Join(vaultDir, "Alpha.md")
	note2 := filepath.Join(vaultDir, "Beta.md")
	note3 := filepath.Join(vaultDir, "Gamma.md")

	_ = os.WriteFile(note1, []byte("# Alpha Note\nPoints to [[Beta]] and [[BrokenTarget]]."), 0644)
	_ = os.WriteFile(note2, []byte("# Beta Note\nPoints to [[Gamma]]."), 0644)
	_ = os.WriteFile(note3, []byte("# Gamma Note\nLeaf note."), 0644)

	// Index notes and graph
	code := c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "index"})
	if code != 0 {
		t.Fatalf("index failed: %s", stderr.String())
	}

	// 1. graph links
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "graph", "links", "Alpha.md"})
	if code != 0 {
		t.Fatalf("graph links failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Beta.md") || !strings.Contains(stdout.String(), "[UNRESOLVED]") {
		t.Errorf("expected outgoing links to include Beta.md and UNRESOLVED, got: %s", stdout.String())
	}

	// 2. graph backlinks
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "graph", "backlinks", "Beta.md"})
	if code != 0 {
		t.Fatalf("graph backlinks failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Alpha.md") {
		t.Errorf("expected backlink from Alpha.md, got: %s", stdout.String())
	}

	// 3. graph broken
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "graph", "broken"})
	if code != 0 {
		t.Fatalf("graph broken failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "BrokenTarget") {
		t.Errorf("expected broken link to BrokenTarget, got: %s", stdout.String())
	}

	// 4. graph path
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "graph", "path", "Alpha.md", "Gamma.md"})
	if code != 0 {
		t.Fatalf("graph path failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Shortest path (2 hops, 3 notes)") {
		t.Errorf("expected shortest path 2 hops, got: %s", stdout.String())
	}

	// 5. graph traverse
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "graph", "traverse", "Alpha.md", "--depth", "2"})
	if code != 0 {
		t.Fatalf("graph traverse failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Beta Note") || !strings.Contains(stdout.String(), "Gamma Note") {
		t.Errorf("expected traversal to discover Beta and Gamma notes, got: %s", stdout.String())
	}

	// 6. search --graph
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "search", "--graph", "Leaf"})
	if code != 0 {
		t.Fatalf("search --graph failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Gamma Note") || !strings.Contains(stdout.String(), "graph-aware") {
		t.Errorf("expected graph search output, got: %s", stdout.String())
	}
}

func TestCLIWorkflows(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	// Index initial note
	code := c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "index"})
	if code != 0 {
		t.Fatalf("index failed: %s", stderr.String())
	}

	// 1. Ingest text
	stdout.Reset()
	code = c.Execute([]string{
		"--vault", vaultDir, "--db", dbPath,
		"ingest", "# Ingested Note Title\nAuthor: Ada Lovelace\nEarly computing algorithms.",
		"--title", "Ingested Note Title",
	})
	if code != 0 {
		t.Fatalf("ingest failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Source Ingested Successfully") {
		t.Errorf("expected success ingest output, got: %s", stdout.String())
	}

	// 2. Query
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "query", "interface"})
	if code != 0 {
		t.Fatalf("query failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Grounded Evidence") {
		t.Errorf("expected query output, got: %s", stdout.String())
	}

	// 3. Synthesize
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "synthesize", "interface", "--propose"})
	if code != 0 {
		t.Fatalf("synthesize failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Synthesis: interface") || !strings.Contains(stdout.String(), "Proposal staged:") {
		t.Errorf("expected synthesize output with staged proposal, got: %s", stdout.String())
	}

	// 4. Review list
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "review", "list"})
	if code != 0 {
		t.Fatalf("review list failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Pending Proposals") {
		t.Errorf("expected review list output, got: %s", stdout.String())
	}

	// 5. Context Packager (Text & JSON)
	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "context", "interface", "--bytes", "8192"})
	if code != 0 {
		t.Fatalf("context text failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "Context Package [Schema 1.0.0") || !strings.Contains(stdout.String(), "Selected Evidence Items") {
		t.Errorf("expected context packager output, got: %s", stdout.String())
	}

	stdout.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "--json", "context", "interface"})
	if code != 0 {
		t.Fatalf("context json failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), `"schema_version": "1.0.0"`) || !strings.Contains(stdout.String(), `"evidence":`) {
		t.Errorf("expected valid JSON context package, got: %s", stdout.String())
	}
}

func TestCLIChatHelpAndCommand(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	// 1. Verify edith help contains chat command
	code := c.Execute([]string{"help"})
	if code != 0 {
		t.Fatalf("help failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "chat") || !strings.Contains(stdout.String(), "Conversational AI") {
		t.Errorf("expected chat in help text, got:\n%s", stdout.String())
	}

	// 2. Verify edith chat --help shows flags
	stdout.Reset()
	stderr.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "chat", "--help"})
	// flag.ContinueOnError with --help returns 0 or prints to stderr
	helpOut := stdout.String() + stderr.String()
	if !strings.Contains(helpOut, "-addr") || !strings.Contains(helpOut, "-model") || !strings.Contains(helpOut, "-env") {
		t.Errorf("expected chat flags in output, got: %s", helpOut)
	}
}

func TestCLIEnvFlagLoading(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	tempDir := t.TempDir()
	customEnvPath := filepath.Join(tempDir, "custom.env")
	envContent := `GROQ_API_KEY=gsk_custom_env_key_xyz
GROQ_MODEL=llama-3.1-8b-instant
`
	if err := os.WriteFile(customEnvPath, []byte(envContent), 0644); err != nil {
		t.Fatalf("write custom env failed: %v", err)
	}

	defer func() {
		_ = os.Unsetenv("GROQ_API_KEY")
		_ = os.Unsetenv("GROQ_MODEL")
	}()

	// Execute with --env
	code := c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "--env", customEnvPath, "scan"})
	if code != 0 {
		t.Fatalf("scan with --env failed: %s", stderr.String())
	}

	if val := os.Getenv("GROQ_API_KEY"); val != "gsk_custom_env_key_xyz" {
		t.Errorf("expected GROQ_API_KEY to be loaded from custom.env, got %q", val)
	}
	if val := os.Getenv("GROQ_MODEL"); val != "llama-3.1-8b-instant" {
		t.Errorf("expected GROQ_MODEL to be loaded from custom.env, got %q", val)
	}
}

func TestCLICaptureCommand(t *testing.T) {
	stdout, stderr, vaultDir, dbPath := setupTestCLI(t)
	c := New(stdout, stderr)

	// 1. Text capture
	stdout.Reset()
	stderr.Reset()
	rawText := "# LSM Tree Storage\nLSM trees optimize write throughput by using append-only immutable memtables and SSTables."
	code := c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "capture", rawText})
	if code != 0 {
		t.Fatalf("capture failed: %s", stderr.String())
	}
	out := stdout.String()
	if !strings.Contains(out, "Universal Capture") || !strings.Contains(out, "knowledge") {
		t.Errorf("expected capture report in output: %s", out)
	}

	// 2. JSON capture
	stdout.Reset()
	stderr.Reset()
	journalText := "# Journal Entry 2026-10-23\nCompleted daily goals and system tests."
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "--json", "capture", journalText})
	if code != 0 {
		t.Fatalf("json capture failed: %s", stderr.String())
	}
	jsonOut := stdout.String()
	if !strings.Contains(jsonOut, `"category": "journal"`) && !strings.Contains(jsonOut, `"category":"journal"`) {
		t.Errorf("expected json output with journal category: %s", jsonOut)
	}
	if !strings.Contains(jsonOut, `"capture_id"`) {
		t.Errorf("expected capture_id in json output: %s", jsonOut)
	}

	// 3. File capture
	tempFile := filepath.Join(t.TempDir(), "note.md")
	if err := os.WriteFile(tempFile, []byte("# File Capture Note\nTesting capture from local text file."), 0644); err != nil {
		t.Fatalf("write temp file failed: %v", err)
	}
	stdout.Reset()
	stderr.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "capture", tempFile})
	if code != 0 {
		t.Fatalf("file capture failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "File Capture Note") {
		t.Errorf("expected file capture title in output: %s", stdout.String())
	}

	// 4. Forced category
	stdout.Reset()
	stderr.Reset()
	code = c.Execute([]string{"--vault", vaultDir, "--db", dbPath, "capture", "--category", "decision", "Decided to use WAL mode for SQLite."})
	if code != 0 {
		t.Fatalf("forced category capture failed: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "decision") {
		t.Errorf("expected category decision in output: %s", stdout.String())
	}
}
