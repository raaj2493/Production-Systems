package cli

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"edith-engine/internal/config"
	"edith-engine/internal/engine"
	"edith-engine/internal/lint"
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
	jsonFlag := flags.Bool("json", false, "Output results in JSON format")
	verboseFlag := flags.Bool("v", false, "Enable verbose output")

	flags.Usage = func() {
		c.printHelp()
	}

	normalizedArgs := reorderArgs(args)
	if err := flags.Parse(normalizedArgs); err != nil {
		return 1
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
		fmt.Fprintf(c.err, "Usage: edith search \"query\"\n")
		return 1
	}

	query := strings.Join(args, " ")
	eng, err := c.initEngine(cfg)
	if err != nil {
		fmt.Fprintf(c.err, "Error: %v\n", err)
		return 1
	}
	defer eng.Close()

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
		fmt.Fprintf(c.err, "Unknown proposals subcommand %q. Choose from: list, approve, reject, create.\n", subCmd)
		return 1
	}
}

func (c *CLI) printHelp() {
	fmt.Fprintf(c.out, `Edith Engine — Local-first Personal Second Brain (Phase 1: Knowledge Brain)

Usage:
  edith [flags] <command> [arguments...]

Commands:
  scan                   Discover eligible Markdown notes and report counts
  index                  Incrementally index notes into SQLite and FTS5
  reindex                Rebuild full SQLite metadata and FTS5 index from scratch
  search <query>         Execute full-text search with relevance ranking & excerpts
  read <relative-path>   Display note content and metadata safely
  status                 Report vault, database, index statistics, and recent activity
  lint                   Run deterministic knowledge maintenance checks
  proposals list         List pending knowledge change proposals (--all for full history)
  proposals approve <id> Review and safely apply an approved change proposal to disk
  proposals reject <id>  Reject a change proposal without modifying disk files
  proposals create ...   Create a change proposal (<target> <reason> <content>)
  help                   Show this help message

Global Flags:
  --vault <path>         Obsidian vault directory (default: ~/Documents/Projects/Edith)
  --db <path>            SQLite database file (default: ~/.edith/edith.db)
  --json                 Output results as JSON
  -v                     Enable verbose output
`)
}

func (c *CLI) printJSON(v interface{}) {
	enc := json.NewEncoder(c.out)
	enc.SetIndent("", "  ")
	_ = enc.Encode(v)
}

func reorderArgs(args []string) []string {
	var flags []string
	var pos []string
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if strings.HasPrefix(arg, "-") {
			flags = append(flags, arg)
			if (arg == "--vault" || arg == "-vault" || arg == "--db" || arg == "-db") && i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") {
				i++
				flags = append(flags, args[i])
			}
		} else {
			pos = append(pos, arg)
		}
	}
	return append(flags, pos...)
}
