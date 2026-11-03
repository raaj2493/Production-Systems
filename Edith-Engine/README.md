# Edith Engine — Personal Knowledge Engine (Phases 1–5 Complete)

A reliable, local-first, lifelong personal knowledge engine built in Go, inspired by [Andrej Karpathy's LLM Wiki blueprint](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

Edith treats Markdown files in an Obsidian vault as the durable source of truth. The engine provides deterministic discovery, reading, indexing, full-text search, knowledge maintenance (linting), atomic change proposals with conflict detection, knowledge graph queries, complete workflows (INGEST, QUERY, LINT, SYNTHESIZE, REVIEW), and a bounded context packager ready to supply grounded evidence to a future local AI layer.

---

## Table of Contents
- [Core Principles & Product Vision](#core-principles--product-vision)
- [Supported Workflows & Architecture](#supported-workflows--architecture)
- [Installation & Build](#installation--build)
- [CLI Command Reference](#cli-command-reference)
  - [Knowledge Brain & Search](#knowledge-brain--search)
  - [Knowledge Graph](#knowledge-graph)
  - [Knowledge Workflows](#knowledge-workflows)
  - [Change Proposals & Safe Revisions](#change-proposals--safe-revisions)
- [Trust, Proposals, and Data Safety](#trust-proposals-and-data-safety)
- [Context Packager for Future Local AI](#context-packager-for-future-local-ai)
- [Backup and Recovery Procedures](#backup-and-recovery-procedures)
- [Privacy and Security Boundaries](#privacy-and-security-boundaries)
- [Running Automated Tests](#running-automated-tests)
- [Recommended Next Steps for Local AI Integration](#recommended-next-steps-for-local-ai-integration)

---

## Core Principles & Product Vision

1. **Trustworthiness Over Demos**: Deterministic algorithms, explainable ranking, explicit uncertainty, and zero fabricated claims.
2. **Local-First & Complete Privacy**: Zero telemetry, zero cloud calls, zero external transmission. Your vault never leaves your machine.
3. **Markdown is the Source of Truth**: The Obsidian vault owns all notes. The SQLite database is an ephemeral, high-speed index that can be rebuilt from scratch at any moment.
4. **Human Approval for Modifications**: Automated systems and external agents can only propose changes. Only an explicit user approval (`edith proposals approve <id>` or `edith review approve <id>`) can mutate a target note.
5. **Recoverability & Non-Destruction**: Original content is archived before destructive replacement. Every restore operation is itself 100% reversible.
6. **Model Independence**: Operates as a complete knowledge engine and context packager today without any AI model dependency.

---

## Supported Workflows & Architecture

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
|     |               |                           |           |     |
|     v               v                           v           v     |
|  +-----+       +---------+                 +---------+   +------+ |
|  | FTS5|       |Knowledge|                 |Proposals|   |Contxt| |
|  |Search       |  Graph  |                 |Revisions|   |Packgr| |
|  +-----+       +---------+                 +---------+   +------+ |
+-------------------------------------------------------------------+
```

---

## Installation & Build

### Requirements
- macOS (Apple Silicon or Intel) or Linux
- Go 1.22+

### Build
From the repository root:
```bash
go build -buildvcs=false -o edith main.go
```

Verify installation:
```bash
./edith help
```

---

## CLI Command Reference

### Global Flags
Available on all commands:
- `--vault <path>`: Path to Obsidian vault (default: `~/Documents/Projects/Edith`)
- `--db <path>`: Path to SQLite database (default: `~/.edith/edith.db`)
- `--json`: Output results formatted as JSON
- `-v`: Enable verbose logging

---

### Knowledge Brain & Search

#### 1. Scan Vault
Discovers eligible Markdown notes and reports discovered, unindexed, and modified counts:
```bash
./edith scan
```

#### 2. Incremental Index
Indexes newly added or modified notes into SQLite, FTS5, and the Knowledge Graph:
```bash
./edith index
```

#### 3. Full Reindex
Rebuilds SQLite metadata, FTS5 full-text tables, and Knowledge Graph from scratch:
```bash
./edith reindex
```

#### 4. Search
Full-text search with BM25 relevance ranking and excerpts:
```bash
# Lexical search
./edith search "distributed consensus"

# Pre-search freshness check (warns if direct edits occurred in Obsidian)
./edith search --fresh "architecture"

# Relationship-aware search (includes connected notes with explainable reasons)
./edith search --graph "superposition"

# Output as JSON
./edith --json search "pipeline"
```

#### 5. Read Note
Safely reads and displays note content and parsed metadata without modification:
```bash
./edith read "00-System/Edith-Protocol.md"
```

#### 6. Status
Reports vault statistics, database size, last index time, and recent activity:
```bash
./edith status
```

#### 7. Lint
Performs deterministic health checks across vault notes, graph links, and proposals:
```bash
./edith lint
```
Checks performed:
- Broken internal wikilinks
- Orphan notes (notes without incoming links)
- Missing or generic titles
- Duplicate content or suspiciously similar titles
- Missing source references in wiki notes
- Stale index entries and unindexed disk modifications
- Invalid source references
- Proposal integrity (pending proposals whose target note was modified or deleted on disk)
- Conservative contradiction detection (active vs deprecated notes sharing the same topic)

---

### Knowledge Graph

#### Outgoing Links
Lists all links originating from a note:
```bash
./edith graph links "03-Wiki/Engineering-Standards.md"
```

#### Backlinks
Lists all notes linking to the target note:
```bash
./edith graph backlinks "00-System/Edith-Protocol.md"
```

#### Orphan Notes
Lists all notes with zero incoming links:
```bash
./edith graph orphans
```

#### Broken Links
Lists all links whose targets cannot be resolved to an existing note:
```bash
./edith graph broken
```

#### Shortest Path
Finds the shortest directed path between two notes using cycle-safe BFS:
```bash
./edith graph path "README.md" "03-Wiki/Distributed-Consensus.md"
```

#### Graph Traversal
Traverses the knowledge graph up to N hops (cycle-safe):
```bash
./edith graph traverse "README.md" --depth 2 --nodes 50
```

---

### Knowledge Workflows

#### 1. INGEST
Ingests an external source file or text safely, computes SHA-256 hash, checks for duplicates, extracts metadata, discovers relevant existing notes in the vault, preserves the raw artifact in the database, and stages a reviewable proposal:
```bash
# Ingest local file
./edith ingest ./papers/raft-consensus.md --title "Raft Consensus Protocol" --author "Ongaro & Ousterhout"

# Ingest raw text
./edith ingest "Key architecture notes from design review." --title "Design Review Notes"
```

#### 2. QUERY
Deterministic knowledge-retrieval pipeline combining lexical search and graph proximity with explainable inclusion reasons:
```bash
./edith query "What are the rules of engagement?" --graph --limit 5
```

#### 3. SYNTHESIZE
Gathers multi-source evidence, preserves complete provenance citations, detects direct textual disagreements, and produces a structured outline:
```bash
# Synthesize topic and stage review proposal
./edith synthesize "Distributed Consensus" --propose

# Synthesize explicit notes
./edith synthesize "Architecture Comparison" --notes "03-Wiki/Raft.md,03-Wiki/Paxos.md"
```

#### 4. REVIEW
Unified workflow for reviewing change proposals, inspecting diffs and hashes, safely approving, rejecting, and restoring revisions:
```bash
# List pending proposals
./edith review list

# Inspect proposal details, target hash, and rationale
./edith review inspect <proposal-id>

# Approve and apply to vault (with pre-change backup snapshot)
./edith review approve <proposal-id> "Approved by user"

# Reject proposal (leaves target file completely unmodified)
./edith review reject <proposal-id> "Not needed"

# Inspect revision history
./edith review history [optional-target-path]

# Restore a prior revision snapshot safely
./edith review restore <revision-id> "Revert unwanted change"
```

---

### Context Packager for Future Local AI

Assembles grounded, trustworthy evidence into a bounded context package ready for local AI consumption:
```bash
# Text representation
./edith context "How have our distributed systems priorities evolved?" --bytes 16384 --depth 1 --graph

# JSON output for local model pipelines
./edith --json context "Database architecture" --bytes 32768
```

#### Context Package Features:
- **Versioned Schema (`1.0.0`)**: Structured JSON containing request ID, query, settings, evidence items, and conflict groups.
- **Strict Byte Budget**: Enforces configured context size limit (in UTF-8 bytes). Explicitly logs any excluded or truncated items.
- **Epistemic Classifications**: Classifies items into `original_source`, `wiki_note`, `user_interpretation`, `plan`, `conflict`, and `unknown`.
- **Conflict Groups**: Preserves explicit contradictions and disagreements rather than discarding conflicting evidence.
- **Path Confinement**: Prevents vault directory escape.

---

## Trust, Proposals, and Data Safety

Edith enforces strict safety guarantees to protect your knowledge:

1. **Per-Target Concurrency Lock**: A `sync.Mutex` lock per target file prevents concurrent approval race conditions.
2. **Pre-Application Conflict Check**: Verifies that the target file still exists and its current SHA-256 hash matches the baseline hash observed at proposal creation. If the file was modified in Obsidian, the proposal is blocked and marked `conflict`.
3. **Atomic Writes**: Writes are executed using temporary files in the same directory, followed by `fsync` and atomic rename.
4. **Pre-Change Snapshot Archive**: Before overwriting any file, the original content and hash are archived in `proposal_revisions`.
5. **Reversible Rollback**: Restoring a revision via `edith proposals restore <id>` or `edith review restore <id>` captures a new pre-restoration snapshot, making rollback itself 100% reversible.
6. **Safe Rejections**: Rejecting a proposal never alters disk files.

---

## Backup and Recovery Procedures

### 1. Obsidian Vault Backup
Your Obsidian vault (`~/Documents/Projects/Edith`) contains standard Markdown files. You can back it up using git, Time Machine, or any standard directory backup tool.

### 2. Database Rebuild Procedure
The SQLite database (`~/.edith/edith.db`) can be completely reconstructed from the vault at any time:
```bash
# Delete corrupt or stale database
rm ~/.edith/edith.db

# Rebuild complete metadata, FTS5 index, and knowledge graph
./edith reindex
```

### 3. Restoring an Overwritten Note
If an approved proposal or synthesis note needs to be rolled back:
```bash
# 1. View archived revisions for the target note
./edith review history "03-Wiki/Architecture.md"

# 2. Restore the desired revision ID
./edith review restore 3 "Restoring baseline architecture"
```

---

## Privacy and Security Boundaries

- **Zero External Network Calls**: Edith never connects to the internet, cloud APIs, or external telemetry endpoints.
- **Path Traversal Guards**: All user-supplied paths are validated with `filepath.Clean` and checked against escaping the configured vault root.
- **Symlink Confinement**: Symlinks pointing outside the vault root are ignored.
- **File Mutation Scoping**: Only `edith proposals approve`, `edith review approve`, and `edith review restore` can write to disk. All other commands are strictly read-only.

---

## Running Automated Tests

Run the complete test suite:
```bash
go test -count=1 ./...
```

Run tests with race detection:
```bash
go test -race ./...
```

Verify formatting and linting:
```bash
go vet ./...
gofmt -l .
```

---

## Edith Chat — Groq-Powered Conversational Assistant

Edith Chat provides a fast, minimal, local web interface where you can have natural, grounded conversations with your personal Obsidian knowledge base.

Instead of hallucinating answers or giving generic responses, Edith retrieves relevant evidence from your vault notes, maps sources to synthetic identifiers (`[S1]`, `[S2]`), and prompts Groq (`llama-3.3-70b-versatile` by default) to generate answers grounded strictly in the supplied excerpts.

### 1. Getting a Groq API Key
1. Go to the official Groq Console: [https://console.groq.com/keys](https://console.groq.com/keys).
2. Sign in and create an API key.
3. Keep this key confidential. **Never** commit it to Git, paste it into source code, or share it.

### 2. Setting Configuration in a `.env` File (Recommended)
You do not need to export your API key into your terminal. Simply create a `.env` file in the project root:

```bash
cp .env.example .env
```

Open `.env` and paste your key:
```bash
GROQ_API_KEY=gsk_your_actual_key_here
```

Edith automatically reads `.env` on startup (as well as `~/.edith/.env`). `.env` is already configured in `.gitignore` so your secrets will never be committed.

#### Optional Environment Configuration:
```bash
# Optional model choice (default: llama-3.3-70b-versatile)
GROQ_MODEL=llama-3.3-70b-versatile

# Optional server address (default: 127.0.0.1:8080)
EDITH_ADDR=127.0.0.1:8080

# Optional evidence budget (default: 16384 bytes)
EDITH_MAX_CONTEXT_BYTES=16384
```

*(Alternatively, you can still export `GROQ_API_KEY` directly in your terminal shell, or pass a custom file with `./edith chat --env /path/to/.env`).*

### 3. Starting Edith Chat
Start the local server:
```bash
./edith chat
```

Once the chat page is open, just write a daily update in plain language. Start with
“Today I learned…”, “Today I learnt…”, “Today I did…”, or “What I learned today…”.
Edith saves it immediately in `12-Logs/YYYY-MM-DD.md`; later daily updates are
appended to that date’s note. For clearer sections, use lines such as:

```text
Today I learned: how SQLite WAL checkpoints work.
Today I did: finished the Edith capture workflow.
Next: review the search results.
```

The vault defaults to `~/Documents/Projects/Edith`. Book captures are stored as
one Markdown file per chapter under `08-Resources/Books/<book>/`, with numbered
filenames so chapters stay in order. The book’s `<book>.md` note contains the
full content of every chapter, with links to each standalone chapter file. The
Quick Capture button and `⌘K` shortcut remain available for other kinds of notes.

To add a chapter in chat, start the message with the book and chapter, then paste
your notes. For example:

```text
Ingest Chapter 3 from The Psychology of Money

## Chapter 3: Never Enough
[your notes]
```

### Automatic Obsidian Web Clipper processing

Set your Obsidian Web Clipper template's **Folder** to `Clippings` (the Obsidian
default). While `./edith chat` is running with `GROQ_API_KEY` configured, Edith
watches that folder and `02-Raw-Sources/Web-Clips`, waits until each Markdown
clip has finished saving, and files its original under `02-Raw-Sources/` by
type (`Videos`, `Articles`, `Books`, or `PDFs`). Separately, it creates
comprehensive, bullet-based Groq notes under the top-level `Processed/` folder,
with matching category folders and links back to each raw source. Long clips
are processed in segments so later material is included too. Existing
processed clips are skipped. Configure an additional inbox with
`EDITH_CLIPPER_INBOX` or change the processed-notes base folder with
`EDITH_CLIPPER_OUTPUT` in `.env` (paths are relative to the vault).

For YouTube clips, Edith uses `yt-dlp` when available to fetch subtitle tracks
only (no video/audio download), then asks Groq to create transcript-grounded
summaries, timestamped pointers, and takeaways. If captions are unavailable or
blocked, the note states that it only had the clipped title/description rather
than presenting that limited text as a full-video summary. On macOS, install the
optional caption helper with `brew install yt-dlp`.

Or configure parameters directly via CLI flags:
```bash
./edith chat --addr 127.0.0.1:8080 --model llama-3.3-70b-versatile --bytes 16384
```

### 4. Opening the Web Interface
Once started, open your browser to:
```
http://127.0.0.1:8080
```

### 5. Verifying Server Readiness
You can verify backend status at any time without exposing secrets:
```bash
curl -s http://127.0.0.1:8080/api/v1/status | jq .
```
Expected output:
```json
{
  "ready": true,
  "groq_configured": true,
  "model": "llama-3.3-70b-versatile",
  "vault_path": "/Users/raajgiri/Documents/Projects/Edith",
  "conversations_count": 1
}
```

### 6. Grounded Answers and Citation Integrity
When you ask a question (such as *"What am I currently learning?"* or *"Explain our consensus safety strategy"*):
- Edith searches your vault notes using full-text search and knowledge graph traversal.
- Selected excerpts are packaged into a bounded context package with synthetic identifiers (`[S1]`, `[S2]`).
- Excerpts are wrapped in `<evidence id="S1">` tags with explicit prompt-injection defenses.
- Groq generates an answer referencing only the supplied evidence with bracketed citations (e.g. `[S1]`).
- The backend validates citations against the evidence actually supplied. Unsupplied or hallucinated IDs are stripped.
- In the chatbox UI, citations appear as clickable badges that open the source note path, title, and exact excerpt.
- If no evidence matches your question, Edith displays an explicit, honest notice: *"⚠️ Insufficient Vault Evidence: No matching notes were found in your vault."*

### 7. Stopping the Server
Press `Ctrl+C` in the terminal to trigger a graceful shutdown. Active connections finish and the database connection closes cleanly.

### 8. Data Boundaries & Privacy
- **Vault and SQLite database remain 100% local.**
- **What is sent to Groq:** Only the current user question, minimal system instructions, and the explicitly selected, bounded excerpts retrieved for that question.
- **What is NEVER sent:** The full vault, unselected notes, full database, API keys, private system credentials, or full past conversation transcripts.
- Transmission to Groq is subject to Groq's official API data-handling terms.

### 9. Managing Conversation History
- Conversations and messages are persisted locally in SQLite (`~/.edith/edith.db`, Migration 4).
- To delete a single conversation: hover over the conversation item in the sidebar and click the trash icon.
- To clear all conversation history: click **"Clear History"** at the bottom of the sidebar, or run:
  ```bash
  curl -X DELETE http://127.0.0.1:8080/api/v1/conversations
  ```
- **Important:** Deleting conversations only removes chat history from the local SQLite database. **Your Obsidian Markdown notes are NEVER modified or deleted.**

### 10. Troubleshooting Common Issues
| Issue | Cause | Solution |
| :--- | :--- | :--- |
| **Status badge shows "Groq Key Missing"** | `GROQ_API_KEY` was not set in the terminal environment | Run `export GROQ_API_KEY="gsk_..."` before starting `./edith chat`. |
| **HTTP 401 Unauthorized** | Invalid or revoked Groq API key | Verify key at [console.groq.com/keys](https://console.groq.com/keys) and update `GROQ_API_KEY`. |
| **HTTP 429 Rate Limit** | Groq account rate limit reached | Wait briefly or configure a lighter model like `llama-3.1-8b-instant`. |
| **Port already in use (`bind: address already in use`)** | Another process is using port `8080` | Start with a different port: `./edith chat --addr 127.0.0.1:8085`. |
| **"Forbidden cross-origin request" (403)** | Non-local or cross-origin browser request | Ensure you are accessing the UI at `http://127.0.0.1:8080` or `http://localhost:8080`. |
