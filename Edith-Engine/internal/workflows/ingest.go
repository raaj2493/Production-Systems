package workflows

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"edith-engine/internal/proposals"
	"edith-engine/internal/store"
)

// IngestRequest defines parameters for ingesting an external source into Edith.
type IngestRequest struct {
	FilePath         string `json:"file_path,omitempty"`
	RawContent       string `json:"raw_content,omitempty"`
	SourceIdentifier string `json:"source_identifier,omitempty"`
	Title            string `json:"title,omitempty"`
	Author           string `json:"author,omitempty"`
	URL              string `json:"url,omitempty"`
	TargetFolder     string `json:"target_folder,omitempty"`
}

// IngestReport summarizes the outcome of the source ingestion workflow.
type IngestReport struct {
	SourceID         string   `json:"source_id"`
	ContentHash      string   `json:"content_hash"`
	Status           string   `json:"status"` // "new" | "duplicate"
	DuplicateOf      string   `json:"duplicate_of,omitempty"`
	ExtractionStatus string   `json:"extraction_status"` // "success" | "partial" | "failed"
	RelevantNotes    []string `json:"relevant_notes"`
	ProposedPath     string   `json:"proposed_path,omitempty"`
	ProposalID       string   `json:"proposal_id,omitempty"`
	Warnings         []string `json:"warnings"`
	Errors           []string `json:"errors"`
}

// IngestWorkflow orchestrates the safe, deterministic ingestion of source material.
type IngestWorkflow struct {
	db        *store.DB
	proposals *proposals.Service
}

// NewIngestWorkflow constructs an IngestWorkflow.
func NewIngestWorkflow(db *store.DB, ps *proposals.Service) *IngestWorkflow {
	return &IngestWorkflow{
		db:        db,
		proposals: ps,
	}
}

// Run executes the ingestion pipeline.
func (w *IngestWorkflow) Run(req IngestRequest) (*IngestReport, error) {
	report := &IngestReport{
		RelevantNotes: make([]string, 0),
		Warnings:      make([]string, 0),
		Errors:        make([]string, 0),
	}

	// 1. Obtain raw source content
	var content string
	var sourceIdent string

	if req.FilePath != "" {
		if strings.HasPrefix(req.FilePath, "http://") || strings.HasPrefix(req.FilePath, "https://") {
			return nil, fmt.Errorf("remote URL fetching is disabled; please provide local file or text")
		}
		data, err := os.ReadFile(req.FilePath)
		if err != nil {
			return nil, fmt.Errorf("failed to read source file %q: %w", req.FilePath, err)
		}
		content = string(data)
		sourceIdent = filepath.Clean(req.FilePath)
	} else if req.RawContent != "" {
		content = req.RawContent
		sourceIdent = req.SourceIdentifier
		if sourceIdent == "" {
			sourceIdent = "direct-text-input"
		}
	} else {
		return nil, fmt.Errorf("either FilePath or RawContent must be provided for ingestion")
	}

	if strings.TrimSpace(content) == "" {
		return nil, fmt.Errorf("source content cannot be empty")
	}

	// 2. Compute SHA-256 content hash
	h := sha256.Sum256([]byte(content))
	contentHash := hex.EncodeToString(h[:])
	report.ContentHash = contentHash

	// 3. Duplicate detection
	existing, err := w.db.GetSourceByHash(contentHash)
	if err != nil {
		return nil, fmt.Errorf("duplicate check failed: %w", err)
	}
	if existing != nil {
		report.Status = "duplicate"
		report.SourceID = existing.ID
		report.DuplicateOf = existing.ID
		report.ExtractionStatus = "success"
		report.Warnings = append(report.Warnings, fmt.Sprintf("Source with identical content hash already ingested as %s (%q)", existing.ID, existing.Title))
		return report, nil
	}

	// 4. Metadata extraction without inventing values
	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = extractTitleFromContent(content)
	}
	if title == "" && req.FilePath != "" {
		title = strings.TrimSuffix(filepath.Base(req.FilePath), filepath.Ext(req.FilePath))
	}
	if title == "" {
		title = fmt.Sprintf("Source-%s", contentHash[:8])
		report.Warnings = append(report.Warnings, "No title detected; generated title from hash")
	}

	author := strings.TrimSpace(req.Author)
	if author == "" {
		author = extractAuthorFromContent(content)
	}

	url := strings.TrimSpace(req.URL)
	if url == "" {
		url = extractURLFromContent(content)
	}

	// 5. Generate unique source identifier and persist immutable source record
	sourceID := fmt.Sprintf("src-%d-%s", time.Now().Unix(), contentHash[:8])
	report.SourceID = sourceID

	sourceRec := &store.SourceRecord{
		ID:               sourceID,
		SourceIdentifier: sourceIdent,
		ContentHash:      contentHash,
		Title:            title,
		Author:           author,
		URL:              url,
		RawContent:       content,
		IngestedAt:       time.Now().UTC(),
	}

	if err := w.db.SaveSource(sourceRec); err != nil {
		return nil, fmt.Errorf("failed to save immutable source record: %w", err)
	}

	report.Status = "new"
	report.ExtractionStatus = "success"

	// 6. Identify relevant existing notes via lexical search
	cleanSearchQuery := sanitizeQueryForSearch(title)
	if cleanSearchQuery != "" {
		hits, err := w.db.Search(cleanSearchQuery, 5)
		if err == nil {
			for _, hit := range hits {
				report.RelevantNotes = append(report.RelevantNotes, hit.RelPath)
			}
		}
	}

	// 7. Produce proposed source note in vault for review
	targetFolder := req.TargetFolder
	if targetFolder == "" {
		targetFolder = "00-Sources"
	}
	slug := sanitizeFilename(title)
	targetPath := filepath.Join(targetFolder, slug+".md")
	report.ProposedPath = targetPath

	// Build note with YAML frontmatter, relevant connections, and preserved source text
	var noteBuilder strings.Builder
	noteBuilder.WriteString("---\n")
	noteBuilder.WriteString(fmt.Sprintf("source_id: %s\n", sourceID))
	noteBuilder.WriteString(fmt.Sprintf("source_hash: %s\n", contentHash))
	noteBuilder.WriteString(fmt.Sprintf("title: %q\n", title))
	if author != "" {
		noteBuilder.WriteString(fmt.Sprintf("author: %q\n", author))
	}
	if url != "" {
		noteBuilder.WriteString(fmt.Sprintf("url: %q\n", url))
	}
	noteBuilder.WriteString(fmt.Sprintf("ingested_at: %s\n", sourceRec.IngestedAt.Format(time.RFC3339)))
	noteBuilder.WriteString("---\n\n")

	noteBuilder.WriteString(fmt.Sprintf("# %s\n\n", title))

	if len(report.RelevantNotes) > 0 {
		noteBuilder.WriteString("## Related Vault Notes\n\n")
		for _, rn := range report.RelevantNotes {
			baseName := strings.TrimSuffix(filepath.Base(rn), filepath.Ext(rn))
			noteBuilder.WriteString(fmt.Sprintf("- [[%s]]\n", baseName))
		}
		noteBuilder.WriteString("\n")
	}

	noteBuilder.WriteString("## Source Content\n\n")
	noteBuilder.WriteString(content)
	if !strings.HasSuffix(content, "\n") {
		noteBuilder.WriteString("\n")
	}

	proposedContent := noteBuilder.String()

	// 8. Submit to proposal engine so changes go through review before modifying the vault
	reason := fmt.Sprintf("Ingest new source: %s (Source ID: %s)", title, sourceID)
	p, err := w.proposals.CreateProposal(targetPath, reason, []string{sourceIdent}, proposedContent)
	if err != nil {
		report.Errors = append(report.Errors, fmt.Sprintf("Failed to stage proposal: %v", err))
		return report, nil
	}
	report.ProposalID = p.ID

	// 9. Record in activity log
	_ = w.db.LogActivity("ingest", 1, 0, 0, 0,
		fmt.Sprintf("Ingested source %s (%s). Staged proposal %s for %s", sourceID, title, p.ID, targetPath))

	return report, nil
}

func extractTitleFromContent(c string) string {
	lines := strings.Split(c, "\n")
	for _, l := range lines {
		trimmed := strings.TrimSpace(l)
		if strings.HasPrefix(trimmed, "# ") {
			return strings.TrimSpace(strings.TrimPrefix(trimmed, "# "))
		}
	}
	return ""
}

func extractAuthorFromContent(c string) string {
	re := regexp.MustCompile(`(?i)(?:author|by):\s*([^\n\r]+)`)
	m := re.FindStringSubmatch(c)
	if len(m) > 1 {
		return strings.Trim(strings.TrimSpace(m[1]), `"'`)
	}
	return ""
}

func extractURLFromContent(c string) string {
	re := regexp.MustCompile(`https?://[^\s)"]+`)
	m := re.FindString(c)
	return m
}

func sanitizeFilename(s string) string {
	reg := regexp.MustCompile(`[^\w\-\.]`)
	clean := reg.ReplaceAllString(s, "-")
	clean = regexp.MustCompile(`-+`).ReplaceAllString(clean, "-")
	// Remove trailing dots that sneak in from punctuation (e.g. "Housel.")
	clean = strings.Trim(clean, "-.")
	return clean
}

func sanitizeQueryForSearch(s string) string {
	words := strings.Fields(s)
	var clean []string
	for _, w := range words {
		alphanumeric := regexp.MustCompile(`^[a-zA-Z0-9]+$`)
		if alphanumeric.MatchString(w) && len(w) > 2 {
			clean = append(clean, w)
		}
	}
	if len(clean) > 3 {
		clean = clean[:3]
	}
	return strings.Join(clean, " ")
}
