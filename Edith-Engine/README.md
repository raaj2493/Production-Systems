# Edith Engine — Phase 1: Knowledge Brain Only

A local-first, lifelong personal second brain engine built in Go, inspired by [Andrej Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

Edith treats Markdown files in an Obsidian vault as the durable source of truth. The engine provides deterministic discovery, reading, indexing, full-text search, knowledge health checks (linting), and atomic change proposals—without any external cloud services, proprietary APIs, HTTP servers, or destructive edits.

---

## Table of Contents
- [Phase 1 Scope](#phase-1-scope)
- [Architecture & Design Principles](#architecture--design-principles)
- [Vault and Engine Relationship](#vault-and-engine-relationship)
- [Database Schema & Location](#database-schema--location)
- [Building and Running the CLI](#building-and-running-the-cli)
- [CLI Command Reference](#cli-command-reference)
- [Indexing & Incremental Updates](#indexing--incremental-updates)
- [Rebuilding the Index](#rebuilding-the-index)
- [Source File Protection & Safety](#source-file-protection--safety)
- [Safe Change Proposals Workflow](#safe-change-proposals-workflow)
- [Running Automated Tests](#running-automated-tests)
- [Known Limitations](#known-limitations)
- [Roadmap (Future Phases)](#roadmap-future-phases)

---

## Phase 1 Scope

Phase 1 implements the core **Knowledge Brain Only**:
- **Included**:
  - Safe, recursive Markdown scanner with directory exclusion and symlink boundary guards.
  - Markdown reader extracting metadata, titles, SHA-256 hashes, wikilinks (`[[...]]`), and standard links (`[...]`).
  - SQLite metadata persistence and SQLite FTS5 full-text indexing with BM25 ranking and snippet generation.
  - Incremental indexing skipping unchanged notes and cleaning stale entries without deleting disk files.
  - Full-text search with query sanitization and fallback mechanics.
  - Knowledge maintenance suite detecting broken links, orphan notes, suspicious titles, and duplicate candidates.
  - Proposal review engine with pre-application conflict detection, recoverable backups, and atomic writes.
  - Command-line interface with text and JSON outputs.
- **Excluded by Design in Phase 1**:
  - Web UI, frontend frameworks, or chatboxes.
  - HTTP servers or Gin routing.
  - AI SDKs, LLM model calls, or prompt chains.
  - Vector databases, dense embeddings, or external indexing services.

---

## Architecture & Design Principles

```
                  +-----------------------------------------+
                  |         Obsidian Markdown Vault         |
                  |     (Durable Human Source of Truth)     |
                  +-------------------+---------------------+
                                      |
                           (Read-Only by Default)
                                      v
+-------------------------------------------------------------------+
|                            Edith Engine                           |
|                                                                   |
|   +---------------+     +---------------+     +---------------+   |
|   | Vault Scanner | --> | Note Reader   | --> | Lint / Health |   |
|   | (Safe Walk)   |     | (Metadata/MD) |     | (Diagnostics) |   |
|   +---------------+     +---------------+     +---------------+   |
|                                 |                                 |
|                                 v                                 |
|   +-----------------------------------------------------------+   |
|   |                  Engine Coordinator                       |   |
|   +-----------------------------------------------------------+   |
|             |                                   |                 |
|             v                                   v                 |
|   +-------------------+               +-------------------+       |
|   | SQLite Persistence|               | Change Proposals  |       |
|   | Metadata & FTS5   |               | & Revision Backup |       |
|   +-------------------+               +-------------------+       |
+-------------------------------------------------------------------+
```

### Core Principles
1. **Markdown is the Durable Source of Truth**: The Obsidian vault owns all notes. The SQLite database is an ephemeral, high-speed index that can be rebuilt from scratch at any moment.
2. **Local-First and Privacy-Conscious**: Zero telemetry, zero cloud calls, zero external transmission. Vault content never leaves your machine.
3. **Safety by Default**: Notes are never modified during scanning, indexing, searching, or linting.
4. **Human Review for Mutations**: Automated systems can only submit proposals. Only an explicit user approval (`edith proposals approve <id>`) can mutate a target note, with atomic writes, conflict checks, and rollback history.

---

## Vault and Engine Relationship

- **Obsidian Vault Path**: `~/Documents/Projects/Edith` (configurable via `--vault`).
- **Engine Workspace**: `~/Documents/Projects/Backend/Production-Systems/Edith-Engine`.
- **Database Location**: Outside the vault at `~/.edith/edith.db` (configurable via `--db`).

The engine deliberately keeps its database and working state outside the vault to avoid cluttering your personal notes with binary files or database locks.

---

## Database Schema & Location

The engine uses SQLite with WAL (Write-Ahead Logging) mode and foreign keys enabled:

### Location
Default path: `~/.edith/edith.db`

### Tables
1. **`notes`**:
   - `id`: Auto-incrementing primary key.
   - `rel_path`: Vault-relative path (e.g. `00-System/Edith-Protocol.md`, UNIQUE).
   - `title`: Extracted note title.
   - `mod_time_unix`: File modification timestamp.
   - `content_hash`: SHA-256 hash of raw note content.
   - `size_bytes`: File size on disk.
   - `indexed_at_unix`: Timestamp of last indexing.
   - `status`: Index status (`indexed`, `failed`).
2. **`notes_fts`** (SQLite FTS5 Virtual Table):
   - `rel_path`: Unindexed path token.
   - `title`: Weighted note title (higher BM25 priority).
   - `content`: Full note Markdown body.
   - Tokenizer: `unicode61 remove_diacritics 1`.
3. **`activity_log`**:
   - Audit trail of engine actions (`scan`, `index`, `reindex`, `search`, `lint`, `proposal_create`, etc.).
   - Records counts and summary details without logging raw note contents.
4. **`proposals`**:
   - `id`: Unique proposal identifier (e.g., `prop-YYYYMMDDHHMMSS-xxxx`).
   - `target_path`: Vault-relative target note.
   - `target_hash`: SHA-256 hash of target file at proposal creation time.
   - `reason`: Rationale for proposed update.
   - `source_paths`: JSON list of provenance notes or raw sources.
   - `proposed_content`: Complete candidate content.
   - `status`: `pending`, `approved`, `rejected`.
   - `created_at_unix`, `reviewed_at_unix`, `review_notes`.
5. **`proposal_revisions`**:
   - Recoverable backup snapshots of original note content and hashes before approved changes are applied.

---

## Building and Running the CLI

### Prerequisites
- macOS / Linux with Go installed (`go1.25` or higher).

### Build Standalone Binary
```bash
# In the engine directory:
go build -buildvcs=false -o edith .
```

### Run Directly with `go run`
```bash
go run . help
```

---

## CLI Command Reference

All commands support `--vault <path>`, `--db <path>`, and `--json`.

### 1. `scan`
Discovers eligible Markdown notes and reports synchronization counts against the database:
```bash
./edith scan
# Or in JSON format:
./edith scan --json
```

### 2. `index`
Performs an incremental index run:
```bash
./edith index
```
- New files: Parsed and added to metadata and FTS5.
- Changed files: Re-parsed and updated in metadata and FTS5.
- Unchanged files: Skipped in sub-millisecond checks.
- Deleted files: Stale index entries cleaned without touching disk.

### 3. `reindex`
Wipes the SQLite index and rebuilds all metadata and FTS5 data from vault Markdown:
```bash
./edith reindex
```

### 4. `search <query>`
Executes local full-text search with BM25 ranking and keyword excerpts:
```bash
./edith search "Karpathy"
./edith search "durable knowledge store"
./edith search --json "protocol"
```

### 5. `read <relative-path>`
Safely displays a note's content, title, modification timestamp, content hash, and detected links:
```bash
./edith read "00-System/Edith-Architecture.md"
```

### 6. `status`
Displays runtime metrics, vault path, database file size, note count, and recent activity:
```bash
./edith status
./edith status --json
```

### 7. `lint`
Runs deterministic knowledge maintenance diagnostics:
```bash
./edith lint
```
Checks performed:
- Broken internal wikilinks (`[[target]]`) and relative Markdown links.
- Orphan notes (notes with zero inbound links).
- Missing or suspicious titles (untitled or generic names).
- Candidate duplicate notes (exact SHA-256 match or identical titles).
- Missing source references in wiki pages (`03-Wiki/`).
- Stale database entries and unindexed/modified notes.

### 8. `proposals`
Reviews, manages, and executes change proposals:
```bash
# List pending proposals
./edith proposals list

# List all proposals (including approved and rejected)
./edith proposals list --all

# Review and approve a proposal (applies change safely with backup)
./edith proposals approve <proposal-id> "Approved by user"

# Reject a proposal (never modifies disk)
./edith proposals reject <proposal-id> "Not needed"

# Create a change proposal manually
./edith proposals create "03-Wiki/Topic.md" "Add reference" "# New Content"
```

---

## Indexing & Incremental Updates

Incremental indexing ensures sub-second updates regardless of vault size:
1. The scanner walks the vault and computes vault-relative paths.
2. The engine loads indexed records from SQLite (`rel_path -> {mod_time, content_hash}`).
3. For each file, the engine checks:
   - Does `mod_time` and `content_hash` match the database? If yes, it is flagged as **unchanged** and FTS reprocessing is skipped.
   - Has the content or timestamp changed? If yes, it is re-parsed and updated atomically in both `notes` and `notes_fts`.
   - Is it a new file? It is indexed into `notes` and `notes_fts`.
4. Any database records whose files no longer exist on disk are removed from the index.

---

## Rebuilding the Index

If you ever delete, corrupt, or relocate your SQLite database:
```bash
./edith reindex
```
The entire index is reconstructed directly from your Markdown notes in seconds.

---

## Source File Protection & Safety

Edith enforces rigorous filesystem safety guards:
- **No Path Traversal**: Every path is checked using `filepath.Clean` and normalized to prevent `..` escaping the vault.
- **Symlink Boundary Checks**: Symlinks pointing outside the vault root are ignored with a safety warning. Circular symlinks are blocked.
- **Hidden Directory Exclusions**: `.obsidian`, `.git`, `.trash`, `node_modules`, and hidden dot-directories are skipped.
- **Read-Only Standard Operations**: `scan`, `index`, `reindex`, `search`, `read`, `status`, and `lint` never write to or modify your Markdown files.

---

## Safe Change Proposals Workflow

When automated agents or workflows wish to propose updates to your knowledge base:
1. **Proposal Staging**: The proposal records target note path, the baseline `target_hash` on disk, reason, provenance sources, and proposed content.
2. **Conflict Prevention**: When `edith proposals approve <id>` is executed, the engine computes the live SHA-256 hash of the target note on disk. If the note was modified since proposal creation, approval is **aborted with a conflict error** to prevent overwriting user edits.
3. **Automatic Revision Archival**: Before writing, the existing content and hash are backed up to the `proposal_revisions` table.
4. **Atomic Write**: The update is written to a temporary file in the target directory, synced to disk, and renamed atomically over the target note.
5. **Re-Indexing**: The updated note is immediately reindexed in SQLite and FTS5.

---

## Running Automated Tests

All tests run in isolated temporary directories with in-memory or temporary SQLite databases. Tests never touch your real vault.

```bash
# Run all tests with verbose output
go test -v ./...

# Run all tests without cache
go test -count=1 ./...

# Run static analysis
go vet ./...

# Verify code formatting
gofmt -l .
```

---

## Known Limitations

- **FTS5 Stopwords & Stemming**: FTS5 uses SQLite's `unicode61` tokenizer. Specialized technical identifiers with underscores or hyphens are treated as individual tokens unless quoted in search.
- **Headings Anchors in Wikilinks**: Wikilinks with section anchors (`[[Note#Heading]]`) are validated against note existence; individual heading existence inside the target note is not strictly enforced in Phase 1.
- **Single-Writer Database**: SQLite operates with WAL mode for concurrency, but concurrent multi-process writes are managed via busy timeouts.

---

## Roadmap (Future Phases)

The knowledge brain built in Phase 1 serves as the modular foundation for upcoming phases:

### Phase 2: Retrieval Improvements & Knowledge-Query Preparation
- Hybrid ranking: BM25 score combined with link graph centrality (inbound link weights).
- Multi-hop traversal: Graph query utility discovering notes connected within 1 to 2 hops of search hits.
- Context window packager: Assembling compact evidence passages with note headings and provenance for downstream reasoning.

### Phase 3: Optional Local AI Integration & Evidence-Grounded Responses
- Pluggable local LLM runner (e.g., Ollama or local inference server).
- Strict evidence grounding: AI responses must cite exact note paths and excerpts retrieved by Phase 1/2 search.
- Autonomous proposal generator: Generating structured change proposals (`edith proposals create`) from new source ingestion without touching the vault directly.

### Phase 4: Chat Interface & User-Facing Experience
- Lightweight browser-based chatbox interface (HTML/CSS/Vanilla JS) connected to a local Go API.
- Live review dashboard for inspecting and approving pending proposals.
- Interactive knowledge graph visualizer and maintenance monitor.
