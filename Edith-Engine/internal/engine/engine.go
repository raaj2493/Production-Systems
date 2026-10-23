package engine

import (
	"fmt"
	"time"

	"edith-engine/internal/config"
	"edith-engine/internal/lint"
	"edith-engine/internal/proposals"
	"edith-engine/internal/store"
	"edith-engine/internal/vault"
)

// ScanSummary contains the outcome of scanning the vault against current index status.
type ScanSummary struct {
	TotalDiscovered int      `json:"total_discovered"`
	Notes           []string `json:"notes"`
	UnindexedCount  int      `json:"unindexed_count"`
	ModifiedCount   int      `json:"modified_count"`
	StaleCount      int      `json:"stale_count"`
	Warnings        []string `json:"warnings"`
}

// IndexSummary summarizes notes processed during an indexing or reindexing run.
type IndexSummary struct {
	DiscoveredCount int           `json:"discovered_count"`
	AddedCount      int           `json:"added_count"`
	UpdatedCount    int           `json:"updated_count"`
	UnchangedCount  int           `json:"unchanged_count"`
	RemovedCount    int           `json:"removed_count"`
	FailedCount     int           `json:"failed_count"`
	Duration        time.Duration `json:"duration"`
	Errors          []string      `json:"errors"`
}

// EngineStatus describes the runtime health and statistics of the knowledge brain.
type EngineStatus struct {
	VaultPath     string                 `json:"vault_path"`
	DBPath        string                 `json:"db_path"`
	DiskNoteCount int                    `json:"disk_note_count"`
	DBNoteCount   int                    `json:"db_note_count"`
	LastIndexedAt time.Time              `json:"last_indexed_at"`
	DBSizeBytes   int64                  `json:"db_size_bytes"`
	RecentLogs    []store.ActivityRecord `json:"recent_logs"`
}

// Engine coordinates the vault filesystem, SQLite persistence, search, and knowledge maintenance.
type Engine struct {
	cfg       *config.Config
	scanner   *vault.Scanner
	reader    *vault.Reader
	db        *store.DB
	proposals *proposals.Service
}

// New initializes an Engine instance using the provided configuration.
func New(cfg *config.Config) (*Engine, error) {
	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("configuration error: %w", err)
	}

	scanner, err := vault.NewScanner(cfg.VaultPath)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize scanner: %w", err)
	}

	reader, err := vault.NewReader(cfg.VaultPath)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize reader: %w", err)
	}

	db, err := store.Open(cfg.DBPath)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize database: %w", err)
	}

	propService := proposals.NewService(cfg.VaultPath, db, reader)

	return &Engine{
		cfg:       cfg,
		scanner:   scanner,
		reader:    reader,
		db:        db,
		proposals: propService,
	}, nil
}

// Close gracefully shuts down the database connection and operational resources.
func (e *Engine) Close() error {
	if e.db != nil {
		return e.db.Close()
	}
	return nil
}

// Scan discovers all eligible notes and checks their synchronization state with the database.
func (e *Engine) Scan() (*ScanSummary, error) {
	paths, err := e.scanner.Scan()
	if err != nil {
		return nil, fmt.Errorf("failed scanning vault: %w", err)
	}

	dbNotes, err := e.db.ListAllNotes()
	if err != nil {
		return nil, fmt.Errorf("failed querying database notes: %w", err)
	}

	dbMap := make(map[string]*store.IndexedNote)
	for _, n := range dbNotes {
		dbMap[n.RelPath] = n
	}

	diskSet := make(map[string]bool)
	unindexed := 0
	modified := 0

	for _, p := range paths {
		diskSet[p] = true
		dn, exists := dbMap[p]
		if !exists {
			unindexed++
		} else {
			// Check modification without full re-parse if mod times differ
			note, err := e.reader.ReadNote(p)
			if err == nil && note.Metadata.ContentHash != dn.ContentHash {
				modified++
			}
		}
	}

	stale := 0
	for _, dn := range dbNotes {
		if !diskSet[dn.RelPath] {
			stale++
		}
	}

	summary := &ScanSummary{
		TotalDiscovered: len(paths),
		Notes:           paths,
		UnindexedCount:  unindexed,
		ModifiedCount:   modified,
		StaleCount:      stale,
		Warnings:        e.scanner.Warnings,
	}

	_ = e.db.LogActivity("scan", len(paths), modified, len(paths)-unindexed-modified, 0,
		fmt.Sprintf("Scanned vault: %d discovered, %d unindexed, %d modified, %d stale", len(paths), unindexed, modified, stale))

	return summary, nil
}

// Index performs an incremental synchronization between the vault files on disk and the SQLite index.
// Unchanged files are skipped; modified or new files are parsed and indexed; stale entries are removed.
func (e *Engine) Index() (*IndexSummary, error) {
	start := time.Now()
	paths, err := e.scanner.Scan()
	if err != nil {
		return nil, fmt.Errorf("failed scanning vault: %w", err)
	}

	dbNotes, err := e.db.ListAllNotes()
	if err != nil {
		return nil, fmt.Errorf("failed querying indexed notes: %w", err)
	}

	dbMap := make(map[string]*store.IndexedNote)
	for _, n := range dbNotes {
		dbMap[n.RelPath] = n
	}

	summary := &IndexSummary{
		DiscoveredCount: len(paths),
		Errors:          make([]string, 0),
	}

	diskSet := make(map[string]bool)

	for _, p := range paths {
		diskSet[p] = true
		note, err := e.reader.ReadNote(p)
		if err != nil {
			summary.FailedCount++
			summary.Errors = append(summary.Errors, fmt.Sprintf("cannot read %s: %v", p, err))
			continue
		}

		dn, exists := dbMap[p]
		if !exists {
			// New note: index
			if err := e.db.IndexNote(note); err != nil {
				summary.FailedCount++
				summary.Errors = append(summary.Errors, fmt.Sprintf("failed indexing %s: %v", p, err))
			} else {
				summary.AddedCount++
			}
		} else if dn.ContentHash != note.Metadata.ContentHash || dn.ModTime.Unix() != note.Metadata.ModTime.Unix() {
			// Changed note: update index
			if err := e.db.IndexNote(note); err != nil {
				summary.FailedCount++
				summary.Errors = append(summary.Errors, fmt.Sprintf("failed updating %s: %v", p, err))
			} else {
				summary.UpdatedCount++
			}
		} else {
			// Unchanged note: skip
			summary.UnchangedCount++
		}
	}

	// Remove stale database entries (files that disappeared from vault)
	for _, dn := range dbNotes {
		if !diskSet[dn.RelPath] {
			if err := e.db.DeleteNote(dn.RelPath); err != nil {
				summary.Errors = append(summary.Errors, fmt.Sprintf("failed removing stale entry %s: %v", dn.RelPath, err))
			} else {
				summary.RemovedCount++
			}
		}
	}

	summary.Duration = time.Since(start)

	_ = e.db.LogActivity("index", summary.DiscoveredCount, summary.AddedCount+summary.UpdatedCount,
		summary.UnchangedCount, summary.FailedCount,
		fmt.Sprintf("Indexed notes in %v: +%d added, ~%d updated, =%d unchanged, -%d removed, !%d failed",
			summary.Duration.Round(time.Millisecond), summary.AddedCount, summary.UpdatedCount, summary.UnchangedCount, summary.RemovedCount, summary.FailedCount))

	return summary, nil
}

// Reindex clears the existing SQLite index and rebuilds all metadata and FTS5 entries from scratch.
func (e *Engine) Reindex() (*IndexSummary, error) {
	start := time.Now()

	if err := e.db.ClearAllNotes(); err != nil {
		return nil, fmt.Errorf("failed to clear existing index: %w", err)
	}

	paths, err := e.scanner.Scan()
	if err != nil {
		return nil, fmt.Errorf("failed scanning vault: %w", err)
	}

	summary := &IndexSummary{
		DiscoveredCount: len(paths),
		Errors:          make([]string, 0),
	}

	for _, p := range paths {
		note, err := e.reader.ReadNote(p)
		if err != nil {
			summary.FailedCount++
			summary.Errors = append(summary.Errors, fmt.Sprintf("cannot read %s: %v", p, err))
			continue
		}

		if err := e.db.IndexNote(note); err != nil {
			summary.FailedCount++
			summary.Errors = append(summary.Errors, fmt.Sprintf("failed indexing %s: %v", p, err))
		} else {
			summary.AddedCount++
		}
	}

	summary.Duration = time.Since(start)

	_ = e.db.LogActivity("reindex", summary.DiscoveredCount, summary.AddedCount, 0, summary.FailedCount,
		fmt.Sprintf("Full reindex completed in %v: %d indexed, %d failed",
			summary.Duration.Round(time.Millisecond), summary.AddedCount, summary.FailedCount))

	return summary, nil
}

// Search performs a full-text search against the indexed notes using SQLite FTS5.
func (e *Engine) Search(query string, limit int) ([]store.SearchResult, error) {
	results, err := e.db.Search(query, limit)
	if err != nil {
		return nil, err
	}

	_ = e.db.LogActivity("search", 0, 0, 0, 0,
		fmt.Sprintf("Search query executed: %q returned %d matches", query, len(results)))

	return results, nil
}

// ReadNote retrieves the full content and parsed metadata of a note safely.
func (e *Engine) ReadNote(relPath string) (*vault.Note, error) {
	return e.reader.ReadNote(relPath)
}

// Status inspects the operational state and index metrics of the system.
func (e *Engine) Status() (*EngineStatus, error) {
	paths, err := e.scanner.Scan()
	if err != nil {
		return nil, fmt.Errorf("failed scanning vault: %w", err)
	}

	stats, err := e.db.GetStats()
	if err != nil {
		return nil, fmt.Errorf("failed reading store stats: %w", err)
	}

	recentLogs, _ := e.db.ListActivity(5)

	return &EngineStatus{
		VaultPath:     e.cfg.VaultPath,
		DBPath:        e.cfg.DBPath,
		DiskNoteCount: len(paths),
		DBNoteCount:   stats.TotalNotes,
		LastIndexedAt: stats.LastIndexedAt,
		DBSizeBytes:   stats.DBSizeBytes,
		RecentLogs:    recentLogs,
	}, nil
}

// Lint runs knowledge maintenance diagnostics against the vault and database.
func (e *Engine) Lint() (*lint.Report, error) {
	linter, err := lint.NewLinter(e.cfg.VaultPath, e.db)
	if err != nil {
		return nil, err
	}
	report, err := linter.Run()
	if err != nil {
		return nil, err
	}

	_ = e.db.LogActivity("lint", 0, 0, 0, 0,
		fmt.Sprintf("Lint completed: %d errors, %d warnings, %d info findings",
			report.TotalErrors, report.TotalWarnings, report.TotalInfo))

	return report, nil
}

// Proposals returns the proposal review service.
func (e *Engine) Proposals() *proposals.Service {
	return e.proposals
}
