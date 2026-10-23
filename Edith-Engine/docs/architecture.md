# Edith Engine — Architecture & Technical Design (Phase 1)

## Overview

Edith is designed as a local-first, lifelong knowledge management engine built around Markdown files in an Obsidian vault. Inspired by Andrej Karpathy's LLM Wiki blueprint, Edith strictly isolates raw source material, synthesized wiki concepts, and operational state.

---

## Architectural Breakdown

### 1. Separation of Concerns

```
edith-engine/
├── cmd/
├── internal/
│   ├── config/      # Configuration parsing, home dir expansion, path safety
│   ├── vault/       # Markdown discovery, symlink security, title & link extraction
│   ├── store/       # SQLite schema, FTS5 virtual tables, activity logging, revisions
│   ├── engine/      # High-level coordinator linking vault, store, and linter
│   ├── lint/        # Knowledge health diagnostics (broken links, orphans, duplicates)
│   ├── proposals/   # Safe change proposal lifecycle, conflict checks, atomic writes
│   └── cli/         # Command-line interface with text/JSON presentation
├── docs/            # Architecture and technical documentation
├── go.mod           # Go module definitions
├── go.sum           # Dependency checksums
└── main.go          # CLI entry point
```

### 2. Dependency Selection: `modernc.org/sqlite`

#### Why `modernc.org/sqlite` over `mattn/go-sqlite3`?
- **Zero Cgo Toolchain Requirement**: `modernc.org/sqlite` is a pure Go transpilation of SQLite. It requires no C compiler, headers, or Cgo runtime bindings on macOS Apple Silicon (arm64).
- **Built-in FTS5 Support**: SQLite FTS5 full-text search is compiled in by default.
- **Portability**: Pure Go compilation allows cross-compilation without Cgo cross-compiler setup.
- **Performance**: Near-native SQLite C execution speed for single-user local knowledge access with SQLite WAL mode.

### 3. Filesystem Security & Traversal Guards
- **Vault Root Confinement**: All file paths supplied to the engine are checked against path traversal (`..`) using `filepath.Clean` and `filepath.Rel`.
- **Symlink Boundary Checks**: Symlinks are evaluated with `filepath.EvalSymlinks`. Any symlink whose real canonical path resolves outside the vault root is discarded with a warning.
- **Directory Exclusion**: Hidden directories (`.obsidian`, `.git`, `.trash`) and software build artifacts (`node_modules`, `Edith-Engine`) are automatically ignored.

### 4. Indexing & FTS5 Strategy
- **External Database**: The SQLite database resides outside the Obsidian vault (default: `~/.edith/edith.db`) to ensure the user's Obsidian vault remains a pure, human-readable directory of Markdown files.
- **Incremental Indexing**: Uses SHA-256 hashes and modification timestamps. Unchanged notes require only stat checks, allowing sub-5ms sync runs on existing vaults.
- **Rebuildability**: If the database is deleted, running `reindex` completely reconstructs the metadata and search index from the Markdown files.
- **Search Ranking**: Uses SQLite FTS5 `bm25(notes_fts, 3.0, 1.0)`, weighting note titles higher than body content. Excerpts are generated using the native `snippet()` function.

### 5. Safe Change Proposals
- Automated systems and external agents are never granted direct write permissions to durable Markdown notes.
- Proposed modifications are stored in the `proposals` table with the SHA-256 hash of the target note at the time of creation.
- Upon approval:
  1. Target path confinement is re-validated.
  2. The target note's current disk hash is compared to `target_hash`. If a human edited the file in the interim, approval is blocked with a conflict error.
  3. The target note's current content is archived into `proposal_revisions`.
  4. The new content is written via a temporary file with `fsync` and atomic rename.
  5. The note is immediately reindexed in SQLite and FTS5.

### 6. Link Parsing & False-Positive Prevention
- **Code Fences and Inline Code**: Text inside fenced code blocks (``` or ~~~) and inline backtick spans (`...`) is treated as code. `ExtractLinks` ignores links embedded in these code contexts according to CommonMark specifications.
- **Instructional Syntax Recognition**: Mentions of `[[wikilinks]]` or `[[wikilink]]` in protocol notes or lines discussing Obsidian link syntax are recognized as instructional references rather than missing files. They are demoted to `SeverityInfo` (not errors).
- **Onboarding Tutorial Placeholders**: Default template placeholders like `[[create a link]]` in welcome notes (`Welcome.md`) are recognized as onboarding prompts and classified as `SeverityInfo`.
- **Preservation of Genuine Broken Link Errors**: Unresolved links in regular notes (e.g., `[[NonExistentNote]]` or broken paths) are strictly reported as `SeverityError` with exit code 1.

---

## Technical Trade-Offs

| Decision | Alternative Considered | Rationale |
| :--- | :--- | :--- |
| **Pure Go SQLite Driver** | `mattn/go-sqlite3` | Avoids Cgo dependencies and compilation issues on macOS arm64; includes FTS5 out of the box. |
| **External SQLite DB** | Storing DB inside vault `.obsidian/` | Keeps Obsidian clean and portable; prevents git noise if vault is git-versioned; ensures DB locks don't interfere with Obsidian plugins. |
| **Deterministic Link Resolution** | Fuzzy / AI Link Guessing | Deterministic matching (vault path first, base note name second) eliminates surprises and false broken link reports. |
| **Pre-Application Conflict Check** | Unconditional overwrite | Protects human edits from being clobbered by delayed proposal reviews. |
| **Instructional/Placeholder Demotion** | Broad regex suppression or silent omission | Transparently informs the user via `[INFO]` while maintaining a clean 0-error exit code; never hides genuine broken links. |

