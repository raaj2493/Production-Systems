package cli

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"edith-engine/internal/chat"
	"edith-engine/internal/config"
	"edith-engine/internal/contextpkg"
	"edith-engine/internal/engine"
	"edith-engine/internal/lint"
	"edith-engine/internal/store"
	"edith-engine/internal/workflows"
)

// CLI runs the command-line interface for the Edith knowledge engine.
type CLI struct {
	out io.Writer
	err io.Writer
}

// New constructs a new CLI runner.
func New(out, err io.Writer) *CLI {
	return &CLI{
		out: out,
		err: err,
	}
}

// Run parses arguments and dispatches to the corresponding subcommand.
func Run(args []string) int {
	c := New(os.Stdout, os.Stderr)
	return c.Execute(args)
}

// Execute handles CLI execution and returns an integer exit code.
func (c *CLI) Execute(args []string) int {
	defaultCfg, err := config.DefaultConfig()
	if err != nil {
		fmt.Fprintf(c.err, "Configuration error: %v\n", err)
		return 1
	}

	flags := flag.NewFlagSet("edith", flag.ContinueOnError)
	flags.SetOutput(c.err)

	vaultFlag := flags.String("vault", defaultCfg.VaultPath, "Path to Obsidian vault directory")
	dbFlag := flags.String("db", defaultCfg.DBPath, "Path to SQLite database file")
	envFlag := flags.String("env", "", "Path to .env configuration file")
	jsonFlag := flags.Bool("json", false, "Output results in JSON format")
	verboseFlag := flags.Bool("v", false, "Enable verbose output")

	flags.Usage = func() {
		c.printHelp()
	}

	normalizedArgs := reorderArgs(args)
	if err := flags.Parse(normalizedArgs); err != nil {
		return 1
	}

	// Load environment variables from .env file if available
	if *envFlag != "" {
		if err := config.LoadEnvFile(*envFlag); err != nil {
			fmt.Fprintf(c.err, "Warning: failed to load env file %s: %v\n", *envFlag, err)
		}
	} else {
		_ = config.LoadDefaultEnv()
	}

	remaining := flags.Args()
	if len(remaining) == 0 {
		c.printHelp()
		return 0
	}

	cmd := remaining[0]
	cmdArgs := remaining[1:]

	cfg := &config.Config{
		VaultPath: *vaultFlag,
		DBPath:    *dbFlag,
		JSON:      *jsonFlag,
		Verbose:   *verboseFlag,
	}

	switch cmd {
	case "help", "--help", "-h":
		c.printHelp()
		return 0

	case "scan":
		return c.handleScan(cfg)

	case "index":
		return c.handleIndex(cfg)

	case "reindex":
		return c.handleReindex(cfg)

	case "search":
		return c.handleSearch(cfg, cmdArgs)

	case "read":
		return c.handleRead(cfg, cmdArgs)

	case "status":
		return c.handleStatus(cfg)

	case "lint":
		return c.handleLint(cfg)

	case "proposals":
		return c.handleProposals(cfg, cmdArgs)

	case "graph":
		return c.handleGraph(cfg, cmdArgs)

	case "ingest":
		return c.handleIngest(cfg, cmdArgs)

	case "query":
		return c.handleQuery(cfg, cmdArgs)

	case "synthesize":
		return c.handleSynthesize(cfg, cmdArgs)

	case "review":
		return c.handleReview(cfg, cmdArgs)

	case "context":
		return c.handleContext(cfg, cmdArgs)

	case "chat":
		return c.handleChat(cfg, cmdArgs)

	case "capture":
		return c.handleCapture(cfg, cmdArgs)

	default:
		fmt.Fprintf(c.err, "Unknown command %q. Run 'edith help' for usage.\n", cmd)
		return 1
	}
}

func (c *CLI) initEngine(cfg *config.Config) (*engine.Engine, error) {
	eng, err := engine.New(cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize knowledge engine: %w", err)
	}
	return eng, nil
}

func (c *CLI) handleScan(cfg *config.Config) int {
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	summary, err := eng.Scan()
	if err != nil {
		fmt.Fprintf(c.err, "Scan failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(summary)
		return 0
	}

	fmt.Fprintf(c.out, "Discovered %d Markdown notes in vault (%s):\n", summary.TotalDiscovered, cfg.VaultPath)
	for _, n := range summary.Notes {
		fmt.Fprintf(c.out, "  • %s\n", n)
	}

	fmt.Fprintf(c.out, "\nScan summary: %d total, %d unindexed, %d modified, %d stale\n",
		summary.TotalDiscovered, summary.UnindexedCount, summary.ModifiedCount, summary.StaleCount)

	if len(summary.Warnings) > 0 {
		fmt.Fprintf(c.out, "\nWarnings:\n")
		for _, w := range summary.Warnings {
			fmt.Fprintf(c.out, "  [!] %s\n", w)
		}
	}

	return 0
}

func (c *CLI) handleIndex(cfg *config.Config) int {
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	summary, err := eng.Index()
	if err != nil {
		fmt.Fprintf(c.err, "Indexing failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(summary)
		return 0
	}

	fmt.Fprintf(c.out, "Incremental Index Complete (%v)\n", summary.Duration.Round(100*time.Microsecond))
	fmt.Fprintf(c.out, "  Discovered: %d notes\n", summary.DiscoveredCount)
	fmt.Fprintf(c.out, "  Added:      +%d\n", summary.AddedCount)
	fmt.Fprintf(c.out, "  Updated:    ~%d\n", summary.UpdatedCount)
	fmt.Fprintf(c.out, "  Unchanged:  =%d\n", summary.UnchangedCount)
	fmt.Fprintf(c.out, "  Removed:    -%d\n", summary.RemovedCount)
	if summary.FailedCount > 0 {
		fmt.Fprintf(c.out, "  Failed:     !%d\n", summary.FailedCount)
		for _, e := range summary.Errors {
			fmt.Fprintf(c.out, "    [Error] %s\n", e)
		}
		return 1
	}

	return 0
}

func (c *CLI) handleReindex(cfg *config.Config) int {
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	summary, err := eng.Reindex()
	if err != nil {
		fmt.Fprintf(c.err, "Full reindex failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(summary)
		return 0
	}

	fmt.Fprintf(c.out, "Full Reindex Complete (%v)\n", summary.Duration.Round(100*time.Microsecond))
	fmt.Fprintf(c.out, "  Indexed: %d notes fresh from vault\n", summary.AddedCount)
	if summary.FailedCount > 0 {
		fmt.Fprintf(c.out, "  Failed:  !%d\n", summary.FailedCount)
		for _, e := range summary.Errors {
			fmt.Fprintf(c.out, "    [Error] %s\n", e)
		}
		return 1
	}

	return 0
}

func (c *CLI) handleSearch(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith search [--fresh] [--graph] \"query\"\n")
		return 1
	}

	checkFreshness := false
	useGraph := false
	var queryParts []string
	for _, a := range args {
		if a == "--fresh" || a == "-fresh" {
			checkFreshness = true
		} else if a == "--graph" || a == "-graph" {
			useGraph = true
		} else {
			queryParts = append(queryParts, a)
		}
	}

	if len(queryParts) == 0 {
		fmt.Fprintf(c.err, "Usage: edith search [--fresh] [--graph] \"query\"\n")
		return 1
	}

	query := strings.Join(queryParts, " ")
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	if checkFreshness {
		summary, err := eng.Scan()
		if err == nil && (summary.UnindexedCount > 0 || summary.ModifiedCount > 0 || summary.StaleCount > 0) {
			fmt.Fprintf(c.err, "Warning: Index may be stale (unindexed: %d, modified: %d, stale: %d). Run 'edith index' to synchronize.\n",
				summary.UnindexedCount, summary.ModifiedCount, summary.StaleCount)
		}
	}

	if useGraph {
		matches, err := eng.Graph().SearchWithRelationships(query, 20, 1)
		if err != nil {
			fmt.Fprintf(c.err, "Search failed: %v\n", err)
			return 1
		}

		if cfg.JSON {
			c.printJSON(matches)
			return 0
		}

		if len(matches) == 0 {
			fmt.Fprintf(c.out, "No matching or related notes found for query: %q\n", query)
			return 0
		}

		fmt.Fprintf(c.out, "Found %d matching/related notes for %q (graph-aware):\n\n", len(matches), query)
		for i, m := range matches {
			fmt.Fprintf(c.out, "%d. %s\n", i+1, m.Title)
			fmt.Fprintf(c.out, "   Path:    %s\n", m.RelPath)
			fmt.Fprintf(c.out, "   Why:     %s (hops: %d)\n", m.InclusionReason, m.RelationshipHops)
			if m.Snippet != "" {
				fmt.Fprintf(c.out, "   Excerpt: %s\n", m.Snippet)
			}
			fmt.Fprintln(c.out)
		}
		return 0
	}

	results, err := eng.Search(query, 20)
	if err != nil {
		fmt.Fprintf(c.err, "Search failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(results)
		return 0
	}

	if len(results) == 0 {
		fmt.Fprintf(c.out, "No matching notes found for query: %q\n", query)
		return 0
	}

	fmt.Fprintf(c.out, "Found %d matching notes for %q:\n\n", len(results), query)
	for i, r := range results {
		fmt.Fprintf(c.out, "%d. %s\n", i+1, r.Title)
		fmt.Fprintf(c.out, "   Path:    %s\n", r.RelPath)
		if r.Snippet != "" {
			fmt.Fprintf(c.out, "   Excerpt: %s\n", r.Snippet)
		}
		fmt.Fprintln(c.out)
	}

	return 0
}

func (c *CLI) handleRead(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith read <relative-path>\n")
		return 1
	}

	relPath := args[0]
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	note, err := eng.ReadNote(relPath)
	if err != nil {
		fmt.Fprintf(c.err, "Read error: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(note)
		return 0
	}

	fmt.Fprintf(c.out, "--- Note: %s ---\n", note.Metadata.RelPath)
	fmt.Fprintf(c.out, "Title:     %s\n", note.Metadata.Title)
	fmt.Fprintf(c.out, "Modified:  %s\n", note.Metadata.ModTime.Format(time.RFC3339))
	fmt.Fprintf(c.out, "Size:      %d bytes\n", note.Metadata.SizeBytes)
	fmt.Fprintf(c.out, "Hash:      %s\n", note.Metadata.ContentHash[:12])
	fmt.Fprintf(c.out, "Links:     %d detected\n", len(note.Links))
	fmt.Fprintf(c.out, "----------------------------------------\n\n")
	fmt.Fprintln(c.out, note.Content)

	return 0
}

func (c *CLI) handleStatus(cfg *config.Config) int {
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	status, err := eng.Status()
	if err != nil {
		fmt.Fprintf(c.err, "Status error: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(status)
		return 0
	}

	fmt.Fprintf(c.out, "Edith Knowledge Brain Status\n")
	fmt.Fprintf(c.out, "============================\n")
	fmt.Fprintf(c.out, "Vault Directory:  %s\n", status.VaultPath)
	fmt.Fprintf(c.out, "SQLite Database:  %s\n", status.DBPath)
	fmt.Fprintf(c.out, "Notes on Disk:    %d\n", status.DiskNoteCount)
	fmt.Fprintf(c.out, "Notes Indexed:    %d\n", status.DBNoteCount)
	if status.LastIndexedAt.IsZero() {
		fmt.Fprintf(c.out, "Last Indexed:     Never\n")
	} else {
		fmt.Fprintf(c.out, "Last Indexed:     %s\n", status.LastIndexedAt.Format(time.RFC822))
	}
	fmt.Fprintf(c.out, "Database Size:    %d bytes\n", status.DBSizeBytes)

	if len(status.RecentLogs) > 0 {
		fmt.Fprintf(c.out, "\nRecent Activity Log:\n")
		for _, l := range status.RecentLogs {
			fmt.Fprintf(c.out, "  [%s] %-10s %s\n", l.Timestamp.Format("15:04:05"), strings.ToUpper(l.Operation), l.Details)
		}
	}

	return 0
}

func (c *CLI) handleLint(cfg *config.Config) int {
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	report, err := eng.Lint()
	if err != nil {
		fmt.Fprintf(c.err, "Lint failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(report)
		return 0
	}

	fmt.Fprintf(c.out, "Knowledge Maintenance Report\n")
	fmt.Fprintf(c.out, "============================\n")

	if len(report.Findings) == 0 {
		fmt.Fprintf(c.out, "All checks passed! No broken links, orphans, or anomalies detected.\n")
		return 0
	}

	for _, f := range report.Findings {
		prefix := "[INFO]"
		if f.Severity == lint.SeverityError {
			prefix = "[ERROR]"
		} else if f.Severity == lint.SeverityWarning {
			prefix = "[WARN]"
		}

		lineStr := ""
		if f.LineNumber > 0 {
			lineStr = fmt.Sprintf(":%d", f.LineNumber)
		}

		fmt.Fprintf(c.out, "%-7s %s%s: %s\n", prefix, f.Path, lineStr, f.Message)
		if f.Details != "" {
			fmt.Fprintf(c.out, "        %s\n", f.Details)
		}
	}

	fmt.Fprintf(c.out, "\nSummary: %d errors, %d warnings, %d info\n",
		report.TotalErrors, report.TotalWarnings, report.TotalInfo)

	if report.TotalErrors > 0 {
		return 1
	}
	return 0
}

func (c *CLI) handleProposals(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith proposals [list|approve <id>|reject <id>|create ...]\n")
		return 1
	}

	subCmd := args[0]
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	ps := eng.Proposals()

	switch subCmd {
	case "list":
		filter := "pending"
		if len(args) > 1 && args[1] == "--all" {
			filter = ""
		}
		props, err := ps.ListProposals(filter)
		if err != nil {
			fmt.Fprintf(c.err, "Failed listing proposals: %v\n", err)
			return 1
		}

		if cfg.JSON {
			c.printJSON(props)
			return 0
		}

		if len(props) == 0 {
			fmt.Fprintf(c.out, "No %s proposals found.\n", filter)
			return 0
		}

		fmt.Fprintf(c.out, "%-26s %-10s %-30s %s\n", "ID", "STATUS", "TARGET", "REASON")
		fmt.Fprintln(c.out, strings.Repeat("-", 80))
		for _, p := range props {
			fmt.Fprintf(c.out, "%-26s %-10s %-30s %s\n", p.ID, strings.ToUpper(p.Status), p.TargetPath, p.Reason)
		}
		return 0

	case "approve":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith proposals approve <proposal-id> [review-notes]\n")
			return 1
		}
		id := args[1]
		notes := "Approved via CLI"
		if len(args) > 2 {
			notes = strings.Join(args[2:], " ")
		}

		if err := ps.Approve(id, notes); err != nil {
			fmt.Fprintf(c.err, "Approval failed: %v\n", err)
			return 1
		}

		fmt.Fprintf(c.out, "Proposal %s successfully approved and safely applied to vault.\n", id)
		return 0

	case "reject":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith proposals reject <proposal-id> [review-notes]\n")
			return 1
		}
		id := args[1]
		notes := "Rejected via CLI"
		if len(args) > 2 {
			notes = strings.Join(args[2:], " ")
		}

		if err := ps.Reject(id, notes); err != nil {
			fmt.Fprintf(c.err, "Rejection failed: %v\n", err)
			return 1
		}

		fmt.Fprintf(c.out, "Proposal %s rejected. Target note was not modified.\n", id)
		return 0

	case "show":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith proposals show <proposal-id>\n")
			return 1
		}
		id := args[1]
		p, err := ps.GetProposal(id)
		if err != nil {
			fmt.Fprintf(c.err, "Proposal not found: %v\n", err)
			return 1
		}

		if cfg.JSON {
			c.printJSON(p)
			return 0
		}

		fmt.Fprintf(c.out, "Proposal Details: %s\n", p.ID)
		fmt.Fprintf(c.out, "========================================\n")
		fmt.Fprintf(c.out, "Status:       %s\n", strings.ToUpper(p.Status))
		fmt.Fprintf(c.out, "Target Note:  %s\n", p.TargetPath)
		fmt.Fprintf(c.out, "Target Hash:  %s\n", p.TargetHash)
		fmt.Fprintf(c.out, "Reason:       %s\n", p.Reason)
		fmt.Fprintf(c.out, "Created At:   %s\n", p.CreatedAt.Format(time.RFC822))
		if !p.ReviewedAt.IsZero() {
			fmt.Fprintf(c.out, "Reviewed At:  %s\n", p.ReviewedAt.Format(time.RFC822))
			fmt.Fprintf(c.out, "Review Notes: %s\n", p.ReviewNotes)
		}
		fmt.Fprintf(c.out, "\nProposed Content:\n-----------------\n%s\n", p.ProposedContent)
		return 0

	case "revisions":
		target := ""
		if len(args) > 1 {
			target = args[1]
		}
		revs, err := ps.ListRevisions(target)
		if err != nil {
			fmt.Fprintf(c.err, "Failed listing revisions: %v\n", err)
			return 1
		}

		if cfg.JSON {
			c.printJSON(revs)
			return 0
		}

		if len(revs) == 0 {
			fmt.Fprintf(c.out, "No revisions found.\n")
			return 0
		}

		fmt.Fprintf(c.out, "%-6s %-20s %-30s %s\n", "ID", "APPLIED AT", "TARGET", "ORIGINAL HASH")
		fmt.Fprintln(c.out, strings.Repeat("-", 80))
		for _, r := range revs {
			hashSnippet := r.OriginalHash
			if len(hashSnippet) > 16 {
				hashSnippet = hashSnippet[:16] + "..."
			}
			fmt.Fprintf(c.out, "%-6d %-20s %-30s %s\n",
				r.ID, r.AppliedAt.Format("2006-01-02 15:04:05"), r.TargetPath, hashSnippet)
		}
		return 0

	case "restore":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith proposals restore <revision-id> [review-notes]\n")
			return 1
		}
		var revID int64
		if _, err := fmt.Sscanf(args[1], "%d", &revID); err != nil || revID <= 0 {
			fmt.Fprintf(c.err, "Invalid revision ID %q: must be a positive integer\n", args[1])
			return 1
		}

		notes := "Restored via CLI"
		if len(args) > 2 {
			notes = strings.Join(args[2:], " ")
		}

		if err := ps.RestoreRevision(revID, notes); err != nil {
			fmt.Fprintf(c.err, "Restore failed: %v\n", err)
			return 1
		}

		fmt.Fprintf(c.out, "Successfully restored revision %d to vault. Pre-restoration snapshot archived.\n", revID)
		return 0

	case "create":
		// Helper for tests and programmatic proposal staging
		if len(args) < 4 {
			fmt.Fprintf(c.err, "Usage: edith proposals create <target-path> <reason> <proposed-content>\n")
			return 1
		}
		target := args[1]
		reason := args[2]
		content := args[3]
		p, err := ps.CreateProposal(target, reason, nil, content)
		if err != nil {
			fmt.Fprintf(c.err, "Create proposal failed: %v\n", err)
			return 1
		}
		fmt.Fprintf(c.out, "Proposal created: %s (Target: %s)\n", p.ID, p.TargetPath)
		return 0

	default:
		fmt.Fprintf(c.err, "Unknown proposals subcommand %q. Choose from: list, show, approve, reject, revisions, restore, create.\n", subCmd)
		return 1
	}
}

func (c *CLI) handleGraph(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith graph <subcommand> [arguments...]\nSubcommands: links, backlinks, orphans, broken, path, traverse\n")
		return 1
	}

	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	g := eng.Graph()
	subCmd := strings.ToLower(args[0])

	switch subCmd {
	case "links":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith graph links <note-path>\n")
			return 1
		}
		target := args[1]
		links, err := g.Outgoing(target)
		if err != nil {
			fmt.Fprintf(c.err, "Failed getting outgoing links: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(links)
			return 0
		}
		if len(links) == 0 {
			fmt.Fprintf(c.out, "No outgoing links from %q.\n", target)
			return 0
		}
		fmt.Fprintf(c.out, "Outgoing links from %s (%d total):\n", target, len(links))
		for _, l := range links {
			anchor := ""
			if l.HeadingAnchor != "" {
				anchor = "#" + l.HeadingAnchor
			}
			resolved := l.TargetPath
			if resolved == "" {
				resolved = "[UNRESOLVED]"
			}
			fmt.Fprintf(c.out, "  -> %s%s (target: %s, line: %d)\n", l.RawTarget, anchor, resolved, l.LineNumber)
		}
		return 0

	case "backlinks":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith graph backlinks <note-path>\n")
			return 1
		}
		target := args[1]
		links, err := g.Backlinks(target)
		if err != nil {
			fmt.Fprintf(c.err, "Failed getting backlinks: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(links)
			return 0
		}
		if len(links) == 0 {
			fmt.Fprintf(c.out, "No incoming backlinks to %q.\n", target)
			return 0
		}
		fmt.Fprintf(c.out, "Backlinks to %s (%d total):\n", target, len(links))
		for _, l := range links {
			fmt.Fprintf(c.out, "  <- %s (line: %d, text: %q)\n", l.SourcePath, l.LineNumber, l.DisplayText)
		}
		return 0

	case "orphans":
		orphans, err := g.Orphans()
		if err != nil {
			fmt.Fprintf(c.err, "Failed finding orphan notes: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(orphans)
			return 0
		}
		if len(orphans) == 0 {
			fmt.Fprintf(c.out, "No orphan notes found. Every note has at least one incoming backlink!\n")
			return 0
		}
		fmt.Fprintf(c.out, "Orphan notes (%d total without incoming links):\n", len(orphans))
		for _, o := range orphans {
			fmt.Fprintf(c.out, "  - %s\n", o)
		}
		return 0

	case "broken":
		broken, err := g.BrokenLinks()
		if err != nil {
			fmt.Fprintf(c.err, "Failed finding broken links: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(broken)
			return 0
		}
		if len(broken) == 0 {
			fmt.Fprintf(c.out, "No broken links found. All internal link targets resolve!\n")
			return 0
		}
		fmt.Fprintf(c.out, "Broken links (%d total unresolvable):\n", len(broken))
		for _, b := range broken {
			fmt.Fprintf(c.out, "  %s:%d -> %s (unresolved)\n", b.SourcePath, b.LineNumber, b.RawTarget)
		}
		return 0

	case "path":
		if len(args) < 3 {
			fmt.Fprintf(c.err, "Usage: edith graph path <start-path> <end-path>\n")
			return 1
		}
		start := args[1]
		end := args[2]
		path, err := g.ShortestPath(start, end)
		if err != nil {
			fmt.Fprintf(c.err, "Shortest path error: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(map[string]interface{}{
				"start": start,
				"end":   end,
				"found": path != nil,
				"path":  path,
			})
			return 0
		}
		if len(path) == 0 {
			fmt.Fprintf(c.out, "No connecting path found between %s and %s.\n", start, end)
			return 0
		}
		fmt.Fprintf(c.out, "Shortest path (%d hops, %d notes):\n", len(path)-1, len(path))
		for i, p := range path {
			if i == 0 {
				fmt.Fprintf(c.out, "  [START] %s\n", p)
			} else if i == len(path)-1 {
				fmt.Fprintf(c.out, "  [END]   %s\n", p)
			} else {
				fmt.Fprintf(c.out, "  ->      %s\n", p)
			}
		}
		return 0

	case "traverse":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith graph traverse <start-path> [--depth N] [--nodes N]\n")
			return 1
		}
		start := args[1]
		depth := 2
		nodes := 50
		for i := 2; i < len(args); i++ {
			if (args[i] == "--depth" || args[i] == "-depth") && i+1 < len(args) {
				fmt.Sscanf(args[i+1], "%d", &depth)
				i++
			} else if (args[i] == "--nodes" || args[i] == "-nodes") && i+1 < len(args) {
				fmt.Sscanf(args[i+1], "%d", &nodes)
				i++
			}
		}
		results, err := g.Traverse(start, depth, nodes)
		if err != nil {
			fmt.Fprintf(c.err, "Traverse failed: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(results)
			return 0
		}
		if len(results) == 0 {
			fmt.Fprintf(c.out, "No connected notes discovered from %s within depth %d.\n", start, depth)
			return 0
		}
		fmt.Fprintf(c.out, "Discovered %d connected notes from %s (depth <= %d):\n", len(results), start, depth)
		for _, r := range results {
			fmt.Fprintf(c.out, "  [Depth %d] %s (Path: %s)\n", r.Depth, r.Title, r.Path)
			fmt.Fprintf(c.out, "     Route: %s\n", strings.Join(r.HopPath, " -> "))
		}
		return 0

	default:
		fmt.Fprintf(c.err, "Unknown graph subcommand %q. Choose from: links, backlinks, orphans, broken, path, traverse.\n", subCmd)
		return 1
	}
}

func (c *CLI) handleIngest(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith ingest <file-path-or-text> [--title \"...\"] [--author \"...\"] [--url \"...\"]\n")
		return 1
	}

	var input string
	var title, author, url string
	for i := 0; i < len(args); i++ {
		a := args[i]
		if (a == "--title" || a == "-title") && i+1 < len(args) {
			title = args[i+1]
			i++
		} else if (a == "--author" || a == "-author") && i+1 < len(args) {
			author = args[i+1]
			i++
		} else if (a == "--url" || a == "-url") && i+1 < len(args) {
			url = args[i+1]
			i++
		} else if input == "" {
			input = a
		} else {
			input += " " + a
		}
	}

	if input == "" {
		fmt.Fprintf(c.err, "Usage: edith ingest <file-path-or-text> [--title \"...\"] [--author \"...\"] [--url \"...\"]\n")
		return 1
	}

	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	req := workflows.IngestRequest{
		Title:  title,
		Author: author,
		URL:    url,
	}

	if _, err := os.Stat(input); err == nil {
		req.FilePath = input
	} else {
		req.RawContent = input
	}

	report, err := eng.Ingest(req)
	if err != nil {
		fmt.Fprintf(c.err, "Ingest failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(report)
		return 0
	}

	if report.Status == "duplicate" {
		fmt.Fprintf(c.out, "[DUPLICATE] Source already exists in database:\n")
		fmt.Fprintf(c.out, "  Source ID: %s\n", report.SourceID)
		fmt.Fprintf(c.out, "  Hash:      %s\n", report.ContentHash)
		for _, w := range report.Warnings {
			fmt.Fprintf(c.out, "  Warning:   %s\n", w)
		}
		return 0
	}

	fmt.Fprintf(c.out, "Source Ingested Successfully\n")
	fmt.Fprintf(c.out, "  Source ID:     %s\n", report.SourceID)
	fmt.Fprintf(c.out, "  Content Hash:  %s\n", report.ContentHash)
	fmt.Fprintf(c.out, "  Proposed Note: %s\n", report.ProposedPath)
	fmt.Fprintf(c.out, "  Proposal ID:   %s (Run 'edith review approve %s' to apply to vault)\n", report.ProposalID, report.ProposalID)
	if len(report.RelevantNotes) > 0 {
		fmt.Fprintf(c.out, "  Relevant Vault Notes Linked:\n")
		for _, rn := range report.RelevantNotes {
			fmt.Fprintf(c.out, "    - %s\n", rn)
		}
	}
	for _, w := range report.Warnings {
		fmt.Fprintf(c.out, "  Warning: %s\n", w)
	}

	return 0
}

func (c *CLI) handleQuery(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith query [--graph] [--limit N] \"query\"\n")
		return 1
	}

	useGraph := false
	limit := 10
	var queryParts []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == "--graph" || a == "-graph" {
			useGraph = true
		} else if (a == "--limit" || a == "-limit") && i+1 < len(args) {
			fmt.Sscanf(args[i+1], "%d", &limit)
			i++
		} else {
			queryParts = append(queryParts, a)
		}
	}

	if len(queryParts) == 0 {
		fmt.Fprintf(c.err, "Usage: edith query [--graph] [--limit N] \"query\"\n")
		return 1
	}

	query := strings.Join(queryParts, " ")
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	res, err := eng.Query(workflows.QueryRequest{
		Query:    query,
		UseGraph: useGraph,
		Limit:    limit,
	})
	if err != nil {
		fmt.Fprintf(c.err, "Query failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(res)
		return 0
	}

	if !res.EvidenceFound {
		fmt.Fprintf(c.out, "%s\n", res.Message)
		return 0
	}

	fmt.Fprintf(c.out, "Grounded Evidence for %q (%d candidate notes):\n\n", res.Query, len(res.Items))
	for i, item := range res.Items {
		hashSnippet := item.ContentHash
		if len(hashSnippet) > 12 {
			hashSnippet = hashSnippet[:12]
		}
		fmt.Fprintf(c.out, "%d. %s (`%s`)\n", i+1, item.Title, item.RelPath)
		fmt.Fprintf(c.out, "   Why:     %s (hops: %d, hash: %s)\n", item.InclusionReason, item.RelationshipHops, hashSnippet)
		if item.Snippet != "" {
			fmt.Fprintf(c.out, "   Excerpt: %s\n", item.Snippet)
		}
		fmt.Fprintln(c.out)
	}
	return 0
}

func (c *CLI) handleSynthesize(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith synthesize <topic> [--notes path1,path2] [--propose]\n")
		return 1
	}

	propose := false
	var selectedNotes []string
	var topicParts []string

	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == "--propose" || a == "-propose" {
			propose = true
		} else if (a == "--notes" || a == "-notes") && i+1 < len(args) {
			rawNotes := strings.Split(args[i+1], ",")
			for _, rn := range rawNotes {
				if tr := strings.TrimSpace(rn); tr != "" {
					selectedNotes = append(selectedNotes, tr)
				}
			}
			i++
		} else {
			topicParts = append(topicParts, a)
		}
	}

	topic := strings.Join(topicParts, " ")
	if topic == "" && len(selectedNotes) == 0 {
		fmt.Fprintf(c.err, "Usage: edith synthesize <topic> [--notes path1,path2] [--propose]\n")
		return 1
	}

	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	res, err := eng.Synthesize(workflows.SynthesizeRequest{
		Topic:          topic,
		SelectedNotes:  selectedNotes,
		SubmitProposal: propose,
	})
	if err != nil {
		fmt.Fprintf(c.err, "Synthesize failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(res)
		return 0
	}

	fmt.Fprintf(c.out, "%s\n", res.StructuredOutline)
	if res.ProposalID != "" {
		fmt.Fprintf(c.out, "\nProposal staged: %s -> %s (run 'edith review approve %s' to apply to vault)\n",
			res.ProposalID, res.ProposedPath, res.ProposalID)
	}

	return 0
}

func (c *CLI) handleReview(cfg *config.Config, args []string) int {
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	rw := eng.Review()

	subCmd := "list"
	if len(args) > 0 {
		subCmd = strings.ToLower(args[0])
	}

	switch subCmd {
	case "list":
		props, err := rw.ListPending()
		if err != nil {
			fmt.Fprintf(c.err, "Failed listing pending proposals: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(props)
			return 0
		}
		if len(props) == 0 {
			fmt.Fprintf(c.out, "No pending proposals awaiting review.\n")
			return 0
		}
		fmt.Fprintf(c.out, "Pending Proposals (%d total):\n", len(props))
		fmt.Fprintf(c.out, "%-18s %-30s %s\n", "PROPOSAL ID", "TARGET", "REASON")
		fmt.Fprintln(c.out, strings.Repeat("-", 80))
		for _, p := range props {
			fmt.Fprintf(c.out, "%-18s %-30s %s\n", p.ID, p.TargetPath, p.Reason)
		}
		return 0

	case "inspect", "show":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith review inspect <proposal-id>\n")
			return 1
		}
		id := args[1]
		insp, err := rw.Inspect(id)
		if err != nil {
			fmt.Fprintf(c.err, "Inspect failed: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(insp)
			return 0
		}

		fmt.Fprintf(c.out, "Proposal Inspection: %s\n", insp.Proposal.ID)
		fmt.Fprintf(c.out, "Target:        %s\n", insp.Proposal.TargetPath)
		fmt.Fprintf(c.out, "Status:        %s\n", insp.Proposal.Status)
		fmt.Fprintf(c.out, "Reason:        %s\n", insp.Proposal.Reason)
		fmt.Fprintf(c.out, "Sources:       %s\n", strings.Join(insp.Proposal.SourcePaths, ", "))
		fmt.Fprintf(c.out, "Expected Hash: %s\n", insp.ExpectedTargetHash)
		fmt.Fprintf(c.out, "Current Hash:  %s\n", insp.CurrentTargetHash)
		if insp.IsStaleConflict {
			fmt.Fprintf(c.out, "WARNING: Target has changed on disk! Applying will cause a STALE CONFLICT.\n")
		}
		fmt.Fprintf(c.out, "\n--- Proposed Content ---\n%s\n", insp.ProposedContent)
		return 0

	case "approve":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith review approve <proposal-id> [review-notes]\n")
			return 1
		}
		id := args[1]
		notes := "Approved via CLI review"
		if len(args) > 2 {
			notes = strings.Join(args[2:], " ")
		}
		if err := rw.Approve(id, notes); err != nil {
			fmt.Fprintf(c.err, "Approval failed: %v\n", err)
			return 1
		}
		fmt.Fprintf(c.out, "Proposal %s approved and safely applied to vault. Pre-change revision archived.\n", id)
		return 0

	case "reject":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith review reject <proposal-id> [review-notes]\n")
			return 1
		}
		id := args[1]
		notes := "Rejected via CLI review"
		if len(args) > 2 {
			notes = strings.Join(args[2:], " ")
		}
		if err := rw.Reject(id, notes); err != nil {
			fmt.Fprintf(c.err, "Rejection failed: %v\n", err)
			return 1
		}
		fmt.Fprintf(c.out, "Proposal %s rejected. Target note remains completely unmodified.\n", id)
		return 0

	case "history", "revisions":
		var target string
		if len(args) > 1 {
			target = args[1]
		}
		revs, err := rw.History(target)
		if err != nil {
			fmt.Fprintf(c.err, "Failed listing revision history: %v\n", err)
			return 1
		}
		if cfg.JSON {
			c.printJSON(revs)
			return 0
		}
		if len(revs) == 0 {
			fmt.Fprintf(c.out, "No revision snapshots found.\n")
			return 0
		}
		fmt.Fprintf(c.out, "%-6s %-20s %-30s %s\n", "ID", "APPLIED AT", "TARGET", "ORIGINAL HASH")
		fmt.Fprintln(c.out, strings.Repeat("-", 80))
		for _, r := range revs {
			hashSnippet := r.OriginalHash
			if len(hashSnippet) > 16 {
				hashSnippet = hashSnippet[:16] + "..."
			}
			fmt.Fprintf(c.out, "%-6d %-20s %-30s %s\n",
				r.ID, r.AppliedAt.Format("2006-01-02 15:04:05"), r.TargetPath, hashSnippet)
		}
		return 0

	case "restore":
		if len(args) < 2 {
			fmt.Fprintf(c.err, "Usage: edith review restore <revision-id> [notes]\n")
			return 1
		}
		var revID int64
		if _, err := fmt.Sscanf(args[1], "%d", &revID); err != nil || revID <= 0 {
			fmt.Fprintf(c.err, "Invalid revision ID %q: must be a positive integer\n", args[1])
			return 1
		}
		notes := "Restored via CLI review"
		if len(args) > 2 {
			notes = strings.Join(args[2:], " ")
		}
		if err := rw.Restore(revID, notes); err != nil {
			fmt.Fprintf(c.err, "Restore failed: %v\n", err)
			return 1
		}
		fmt.Fprintf(c.out, "Successfully restored revision %d to vault. Pre-restoration snapshot archived.\n", revID)
		return 0

	default:
		fmt.Fprintf(c.err, "Unknown review subcommand %q. Choose from: list, inspect, approve, reject, history, restore.\n", subCmd)
		return 1
	}
}

func (c *CLI) handleContext(cfg *config.Config, args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(c.err, "Usage: edith context <query> [--bytes N] [--depth N] [--graph] [--limit N] [--notes <a>,<b>] [--allow <p>] [--exclude <p>]\n")
		return 1
	}

	bytesBudget := 16384
	depth := 1
	useGraph := false
	limit := 10
	var selectedNotes []string
	var allowedPaths []string
	var excludedPaths []string
	var queryParts []string

	for i := 0; i < len(args); i++ {
		a := args[i]
		if (a == "--bytes" || a == "-bytes") && i+1 < len(args) {
			fmt.Sscanf(args[i+1], "%d", &bytesBudget)
			i++
		} else if (a == "--depth" || a == "-depth") && i+1 < len(args) {
			fmt.Sscanf(args[i+1], "%d", &depth)
			i++
		} else if a == "--graph" || a == "-graph" {
			useGraph = true
		} else if (a == "--limit" || a == "-limit") && i+1 < len(args) {
			fmt.Sscanf(args[i+1], "%d", &limit)
			i++
		} else if (a == "--notes" || a == "-notes") && i+1 < len(args) {
			for _, n := range strings.Split(args[i+1], ",") {
				if tr := strings.TrimSpace(n); tr != "" {
					selectedNotes = append(selectedNotes, tr)
				}
			}
			i++
		} else if (a == "--allow" || a == "-allow") && i+1 < len(args) {
			for _, n := range strings.Split(args[i+1], ",") {
				if tr := strings.TrimSpace(n); tr != "" {
					allowedPaths = append(allowedPaths, tr)
				}
			}
			i++
		} else if (a == "--exclude" || a == "-exclude") && i+1 < len(args) {
			for _, n := range strings.Split(args[i+1], ",") {
				if tr := strings.TrimSpace(n); tr != "" {
					excludedPaths = append(excludedPaths, tr)
				}
			}
			i++
		} else {
			queryParts = append(queryParts, a)
		}
	}

	query := strings.Join(queryParts, " ")
	if query == "" && len(selectedNotes) == 0 {
		fmt.Fprintf(c.err, "Usage: edith context <query> [--bytes N] [--depth N] [--graph] [--limit N] [--notes <a>,<b>] [--allow <p>] [--exclude <p>]\n")
		return 1
	}

	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	pkg, err := eng.Context(contextpkg.ContextRequest{
		Query:           query,
		SelectedNotes:   selectedNotes,
		MaxResults:      limit,
		MaxContextBytes: bytesBudget,
		GraphDepth:      depth,
		EnableGraph:     useGraph,
		AllowedPaths:    allowedPaths,
		ExcludedPaths:   excludedPaths,
	})
	if err != nil {
		fmt.Fprintf(c.err, "Context packaging failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(pkg)
		return 0
	}

	fmt.Fprintf(c.out, "Context Package [Schema %s, Request ID: %s]\n", pkg.SchemaVersion, pkg.RequestID)
	fmt.Fprintf(c.out, "Query:           %s\n", pkg.Query)
	fmt.Fprintf(c.out, "Generated:       %s\n", pkg.GeneratedAt.Format(time.RFC3339))
	fmt.Fprintf(c.out, "Context Budget:  %d / %d bytes (Truncated: %v)\n", pkg.TotalContextBytes, pkg.MaxContextBytes, pkg.IsTruncated)
	if pkg.IsTruncated && pkg.TruncationReason != "" {
		fmt.Fprintf(c.out, "Truncation Note: %s\n", pkg.TruncationReason)
	}

	for _, w := range pkg.Warnings {
		fmt.Fprintf(c.out, "Warning:         %s\n", w)
	}

	if len(pkg.Evidence) == 0 {
		fmt.Fprintf(c.out, "\nNo evidence items selected.\n")
	} else {
		fmt.Fprintf(c.out, "\nSelected Evidence Items (%d total):\n", len(pkg.Evidence))
		fmt.Fprintln(c.out, strings.Repeat("-", 80))
		for i, ev := range pkg.Evidence {
			fmt.Fprintf(c.out, "%d. %s (`%s`) [%s]\n", i+1, ev.Title, ev.RelPath, ev.Classification)
			fmt.Fprintf(c.out, "   Why:     %s (hops: %d, score: %.2f, size: %d B)\n",
				ev.InclusionReason, ev.RelationshipHops, ev.LexicalScore, ev.SizeBytes)
			fmt.Fprintf(c.out, "   Hash:    %s\n", ev.ContentHash)
			fmt.Fprintf(c.out, "   Excerpt: %s\n\n", ev.Excerpt)
		}
	}

	if len(pkg.ConflictGroups) > 0 {
		fmt.Fprintf(c.out, "Conflict Groups (%d detected):\n", len(pkg.ConflictGroups))
		for _, cg := range pkg.ConflictGroups {
			fmt.Fprintf(c.out, "  [!] %s (Notes: %s)\n", cg.ConflictDescription, strings.Join(cg.ContradictingNotes, ", "))
		}
		fmt.Fprintln(c.out)
	}

	if len(pkg.ExcludedCandidates) > 0 {
		fmt.Fprintf(c.out, "Excluded Candidates (%d total):\n", len(pkg.ExcludedCandidates))
		for _, ex := range pkg.ExcludedCandidates {
			fmt.Fprintf(c.out, "  [-] %s: %s\n", ex.RelPath, ex.Reason)
		}
	}

	return 0
}

func (c *CLI) printHelp() {
	fmt.Fprintf(c.out, `Edith Engine — Local-first Personal Knowledge Engine

Usage:
  edith [flags] <command> [arguments...]

Knowledge Brain & Search:
  scan                   Discover eligible Markdown notes and report counts
  index                  Incrementally index notes into SQLite, FTS5 & graph
  reindex                Rebuild full SQLite metadata, FTS5 & graph from scratch
  search [--fresh] [--graph] <query>
                         Execute full-text search with relevance ranking & excerpts
                         (--fresh checks staleness, --graph includes connected notes)
  read <relative-path>   Display note content and metadata safely
  status                 Report vault, database, index statistics, and recent activity
  lint                   Run deterministic knowledge maintenance checks

Knowledge Graph:
  graph links <path>     List outgoing links from note
  graph backlinks <path> List incoming backlinks to note
  graph orphans          List notes with no incoming backlinks
  graph broken           List links whose targets cannot be resolved
  graph path <a> <b>     Find shortest path between two notes
  graph traverse <path>  Traverse graph up to N hops (default 2)

Knowledge Workflows:
  capture <file|text> [--category <cat>] [--target <note>] [--stdin]
                         Universally capture text or local file; auto-classify and organize safely
  ingest <file|text> [--title "..."] [--author "..."] [--url "..."]
                         Ingest external source safely, preserve raw artifact, stage proposal
  query [--graph] [--limit N] <query>
                         Execute deterministic grounded retrieval with provenance & explanations
  synthesize <topic> [--notes <a>,<b>] [--propose]
                         Synthesize multi-source evidence outline and preserve conflicting claims
  review [list|inspect|approve|reject|history|restore]
                         Manage proposal review lifecycle with hash checks and safe rollback
  context [--bytes N] [--depth N] [--graph] <query>
                         Assemble bounded evidence context package for future local AI

Conversational AI:
  chat [--addr <addr>] [--model <model>] [--bytes N] [--env <path>]
                         Start the local web chatbox powered by Groq (default: 127.0.0.1:8080)

Change Proposals & Revisions:
  proposals list [--all] List pending knowledge change proposals
  proposals show <id>    Inspect proposal details, target hash, and rationale
  proposals approve <id> Review and safely apply an approved change proposal to disk
  proposals reject <id>  Reject a change proposal without modifying disk files
  proposals revisions [target]
                         List archived pre-change revisions
  proposals restore <id> Restore target note to a prior revision safely
  proposals create ...   Create a change proposal (<target> <reason> <content>)

General:
  help                   Show this help message

Global Flags:
  --vault <path>         Obsidian vault directory (default: ~/Documents/Projects/Edith)
  --db <path>            SQLite database file (default: ~/.edith/edith.db)
  --env <path>           Path to .env configuration file (default: .env or ~/.edith/.env)
  --json                 Output results as JSON
  -v                     Enable verbose output
`)
}

func (c *CLI) printJSON(v interface{}) {
	enc := json.NewEncoder(c.out)
	enc.SetIndent("", "  ")
	_ = enc.Encode(v)
}

func isGlobalFlag(arg string) bool {
	return arg == "--vault" || arg == "-vault" ||
		arg == "--db" || arg == "-db" ||
		arg == "--env" || arg == "-env" ||
		arg == "--json" || arg == "-json" ||
		arg == "-v" || arg == "--v"
}

func reorderArgs(args []string) []string {
	var flags []string
	var pos []string
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if isGlobalFlag(arg) {
			flags = append(flags, arg)
			if (arg == "--vault" || arg == "-vault" || arg == "--db" || arg == "-db" || arg == "--env" || arg == "-env") && i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") {
				i++
				flags = append(flags, args[i])
			}
		} else {
			pos = append(pos, arg)
		}
	}
	return append(flags, pos...)
}

func (c *CLI) handleChat(cfg *config.Config, args []string) int {
	chatFlags := flag.NewFlagSet("chat", flag.ContinueOnError)
	chatFlags.SetOutput(c.err)

	envFlag := chatFlags.String("env", "", "Path to .env configuration file")
	addrFlag := chatFlags.String("addr", "", "Local bind address and port (default 127.0.0.1:8080)")
	modelFlag := chatFlags.String("model", "", "Configured Groq model identifier (default llama-3.3-70b-versatile)")
	bytesFlag := chatFlags.Int("bytes", 0, "Maximum context package byte limit (default 16384)")

	if err := chatFlags.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return 0
		}
		return 1
	}

	// Load custom or default .env file
	if *envFlag != "" {
		if err := config.LoadEnvFile(*envFlag); err != nil {
			fmt.Fprintf(c.err, "Warning: failed to load env file %s: %v\n", *envFlag, err)
		}
	} else {
		_ = config.LoadDefaultEnv()
	}

	addr := *addrFlag
	if addr == "" {
		addr = os.Getenv("EDITH_ADDR")
		if addr == "" {
			addr = "127.0.0.1:8080"
		}
	}

	model := *modelFlag
	if model == "" {
		model = os.Getenv("GROQ_MODEL")
		if model == "" {
			model = chat.DefaultGroqModel
		}
	}

	maxBytes := *bytesFlag
	if maxBytes <= 0 {
		if envBytes := os.Getenv("EDITH_MAX_CONTEXT_BYTES"); envBytes != "" {
			if b, err := strconv.Atoi(envBytes); err == nil && b > 0 {
				maxBytes = b
			}
		}
		if maxBytes <= 0 {
			maxBytes = 16384
		}
	}

	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	// Ensure search index is up-to-date
	_, _ = eng.Index()

	db, err := store.Open(cfg.DBPath)
	if err != nil {
		fmt.Fprintf(c.err, "Database error: %v\n", err)
		return 1
	}
	defer db.Close()

	apiKey := os.Getenv("GROQ_API_KEY")
	groqClient, err := chat.NewClient(chat.ClientConfig{
		APIKey: apiKey,
		Model:  model,
	})
	if err != nil {
		fmt.Fprintf(c.err, "Failed to initialize Groq client: %v\n", err)
		return 1
	}

	chatService := chat.NewService(chat.ServiceConfig{
		Engine:          eng,
		Client:          groqClient,
		DB:              db,
		MaxContextBytes: maxBytes,
	})
	clipInbox := os.Getenv("EDITH_CLIPPER_INBOX")
	clipOutput := os.Getenv("EDITH_CLIPPER_OUTPUT")
	clipCtx, stopClipWatcher := context.WithCancel(context.Background())
	defer stopClipWatcher()
	if groqClient.IsConfigured() {
		clipWatcher := chat.NewClipWatcher(cfg.VaultPath, clipInbox, clipOutput, db, groqClient, func() error {
			_, indexErr := eng.Index()
			return indexErr
		}, func(format string, values ...any) {
			fmt.Fprintf(c.out, "[clipper] "+format+"\n", values...)
		})
		go clipWatcher.Run(clipCtx)
	} else {
		fmt.Fprintln(c.out, "[clipper] Watching disabled: configure GROQ_API_KEY to process web clips automatically.")
	}

	server, err := chat.NewServer(chat.ServerConfig{
		Addr:      addr,
		Service:   chatService,
		VaultPath: cfg.VaultPath,
	})
	if err != nil {
		fmt.Fprintf(c.err, "Failed to configure server: %v\n", err)
		return 1
	}

	groqStatus := "Ready (API key configured)"
	if !groqClient.IsConfigured() {
		groqStatus = "Not configured (set GROQ_API_KEY in .env or environment)"
	}

	fmt.Fprintf(c.out, "\n================================================================================\n")
	fmt.Fprintf(c.out, " Edith Chat — Local Knowledge Assistant\n")
	fmt.Fprintf(c.out, "================================================================================\n")
	fmt.Fprintf(c.out, " Web Chatbox:    http://%s\n", addr)
	fmt.Fprintf(c.out, " Authoritative:  %s\n", cfg.VaultPath)
	fmt.Fprintf(c.out, " SQLite Store:   %s\n", cfg.DBPath)
	fmt.Fprintf(c.out, " Selected Model: %s\n", model)
	fmt.Fprintf(c.out, " Context Budget: %d bytes\n", maxBytes)
	fmt.Fprintf(c.out, " Groq Status:    %s\n", groqStatus)
	fmt.Fprintf(c.out, " Security:       Bound to loopback %s; cross-origin requests blocked\n", addr)
	fmt.Fprintf(c.out, "--------------------------------------------------------------------------------\n")
	fmt.Fprintf(c.out, " Press Ctrl+C to stop the server.\n")
	fmt.Fprintf(c.out, "================================================================================\n\n")

	// Set up graceful shutdown channel
	stopChan := make(chan os.Signal, 1)
	signal.Notify(stopChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-stopChan
		fmt.Fprintf(c.out, "\nShutting down Edith Chat server...\n")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	if err := server.Start(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		fmt.Fprintf(c.err, "Server failed: %v\n", err)
		return 1
	}

	return 0
}

type cliGroqCompleter struct {
	client *chat.Client
}

func (g *cliGroqCompleter) CompletePrompt(ctx context.Context, systemPrompt, userContent string) (string, error) {
	if g.client == nil || !g.client.IsConfigured() {
		return "", errors.New("groq client not configured")
	}
	req := &chat.ChatRequest{
		Model: g.client.Model(),
		Messages: []chat.Message{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userContent},
		},
		Temperature: 0.1,
	}
	resp, err := g.client.Complete(ctx, req)
	if err != nil {
		return "", err
	}
	if len(resp.Choices) == 0 {
		return "", errors.New("no completion choices returned")
	}
	return resp.Choices[0].Message.Content, nil
}

func (c *CLI) handleCapture(cfg *config.Config, args []string) int {
	var input string
	var forcedCategory string
	var targetNote string
	var readStdin bool

	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == "--help" || a == "-h" || a == "help" {
			fmt.Fprintf(c.out, "Usage: edith capture <file-path-or-text> [flags]\n\n")
			fmt.Fprintf(c.out, "Universal capture workflow for notes, journal entries, decisions, and ideas.\n\n")
			fmt.Fprintf(c.out, "Flags:\n")
			fmt.Fprintf(c.out, "  --category <cat>   Manually specify category (knowledge, journal, decision, inbox)\n")
			fmt.Fprintf(c.out, "  --target <note>    Target note path if proposing an update to an existing note\n")
			fmt.Fprintf(c.out, "  --stdin            Read captured content from standard input\n")
			fmt.Fprintf(c.out, "  --json             Output results in structured JSON format\n")
			return 0
		} else if (a == "--category" || a == "-category" || a == "--as" || a == "-as") && i+1 < len(args) {
			forcedCategory = args[i+1]
			i++
		} else if (a == "--target" || a == "-target") && i+1 < len(args) {
			targetNote = args[i+1]
			i++
		} else if a == "--stdin" || a == "-stdin" {
			readStdin = true
		} else if input == "" {
			input = a
		} else {
			input += " " + a
		}
	}

	// Check for piped stdin if requested or if no arguments were given and stdin has data
	if readStdin || (input == "" && hasPipedStdin()) {
		stdinData, err := io.ReadAll(os.Stdin)
		if err == nil && len(stdinData) > 0 {
			if input != "" {
				input = input + "\n" + string(stdinData)
			} else {
				input = string(stdinData)
			}
		}
	}

	if strings.TrimSpace(input) == "" {
		fmt.Fprintf(c.err, "Usage: edith capture <file-path-or-text> [--category <cat>] [--target <note>] [--stdin]\n")
		return 1
	}

	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

	// If GROQ_API_KEY is configured in env, attach completer for secondary AI classification
	if apiKey := os.Getenv("GROQ_API_KEY"); apiKey != "" {
		groqClient, err := chat.NewClient(chat.ClientConfig{
			APIKey: apiKey,
			Model:  os.Getenv("GROQ_MODEL"),
		})
		if err == nil && groqClient.IsConfigured() {
			eng.SetCompleter(&cliGroqCompleter{client: groqClient})
		}
	}

	req := workflows.CaptureRequest{
		ForcedCategory: forcedCategory,
		TargetNote:     targetNote,
	}

	if _, err := os.Stat(input); err == nil && !strings.Contains(input, "\n") {
		req.FilePath = input
	} else {
		req.RawContent = input
	}

	report, err := eng.Capture(context.Background(), req)
	if err != nil {
		fmt.Fprintf(c.err, "Capture failed: %v\n", err)
		return 1
	}

	if cfg.JSON {
		c.printJSON(report)
		return 0
	}

	c.printCaptureReport(report)
	return 0
}

func hasPipedStdin() bool {
	stat, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return (stat.Mode() & os.ModeCharDevice) == 0
}

func (c *CLI) printCaptureReport(report *workflows.CaptureReport) {
	fmt.Fprintf(c.out, "\n%s\n", strings.Repeat("=", 80))
	fmt.Fprintf(c.out, " Edith Universal Capture — Intelligent Auto-Organization\n")
	fmt.Fprintf(c.out, "%s\n", strings.Repeat("=", 80))
	fmt.Fprintf(c.out, " Capture ID:    %s\n", report.CaptureID)
	fmt.Fprintf(c.out, " Timestamp:     %s\n", report.Timestamp.Format("2006-01-02 15:04:05 UTC"))
	fmt.Fprintf(c.out, " Content Hash:  %s\n", report.ContentHash)
	fmt.Fprintf(c.out, " Category:      %s (Confidence: %.0f%%)\n", report.Category, report.Confidence*100)
	fmt.Fprintf(c.out, " Understood:    %s\n", report.Title)
	if report.Summary != "" {
		fmt.Fprintf(c.out, " Summary:       %s\n", report.Summary)
	}

	var dispDesc string
	switch report.Disposition {
	case workflows.DispositionSavedAutomatically:
		dispDesc = "Saved automatically (Destination note created)"
	case workflows.DispositionPlacedInInbox:
		dispDesc = "Placed in Inbox (Ambiguous or low confidence)"
	case workflows.DispositionStagedForReview:
		dispDesc = fmt.Sprintf("Staged for review (Proposal %s created for existing note)", report.ProposalID)
	case workflows.DispositionDuplicate:
		dispDesc = "Duplicate (Identical content already captured)"
	default:
		dispDesc = report.Disposition
	}
	fmt.Fprintf(c.out, " Disposition:   %s\n", dispDesc)
	fmt.Fprintf(c.out, " Destination:   %s\n", report.DestinationPath)

	if report.Indexed {
		fmt.Fprintf(c.out, " Indexed:       Yes (Immediately searchable in FTS5 & graph)\n")
	} else if report.Disposition == workflows.DispositionStagedForReview {
		fmt.Fprintf(c.out, " Indexed:       Pending (Will be indexed upon proposal approval)\n")
	} else {
		fmt.Fprintf(c.out, " Indexed:       No\n")
	}

	if len(report.Topics) > 0 {
		fmt.Fprintf(c.out, " Topics:        %s\n", strings.Join(report.Topics, ", "))
	}
	if len(report.RelatedProjects) > 0 {
		fmt.Fprintf(c.out, " Projects:      %s\n", strings.Join(report.RelatedProjects, ", "))
	}
	if report.EventDate != "" {
		fmt.Fprintf(c.out, " Event Date:    %s\n", report.EventDate)
	}

	if len(report.RelatedNotes) > 0 {
		fmt.Fprintf(c.out, " Related Notes:\n")
		for _, rn := range report.RelatedNotes {
			fmt.Fprintf(c.out, "   • %s\n", rn)
		}
	}

	if len(report.OpenQuestions) > 0 {
		fmt.Fprintf(c.out, " Open Questions:\n")
		for _, q := range report.OpenQuestions {
			fmt.Fprintf(c.out, "   ? %s\n", q)
		}
	}

	if len(report.Warnings) > 0 {
		fmt.Fprintf(c.out, " Warnings:\n")
		for _, w := range report.Warnings {
			fmt.Fprintf(c.out, "   ⚠ %s\n", w)
		}
	}

	if len(report.Errors) > 0 {
		fmt.Fprintf(c.out, " Errors:\n")
		for _, e := range report.Errors {
			fmt.Fprintf(c.out, "   ✗ %s\n", e)
		}
	}

	fmt.Fprintf(c.out, "%s\n\n", strings.Repeat("=", 80))
}
