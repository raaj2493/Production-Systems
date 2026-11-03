package contextpkg

import "time"

const SchemaVersion = "1.0.0"

// EpistemicClassification categorizes knowledge items based on explicitly available metadata.
type EpistemicClassification string

const (
	ClassOriginalSource EpistemicClassification = "original_source"
	ClassWikiNote       EpistemicClassification = "wiki_note"
	ClassInterpretation EpistemicClassification = "user_interpretation"
	ClassPlan           EpistemicClassification = "plan"
	ClassConflict       EpistemicClassification = "conflict"
	ClassUnknown        EpistemicClassification = "unknown"
)

// ContextRequest defines parameters for assembling a bounded evidence context package.
type ContextRequest struct {
	Query           string   `json:"query"`
	SelectedNotes   []string `json:"selected_notes,omitempty"`
	MaxResults      int      `json:"max_results,omitempty"`
	MaxContextBytes int      `json:"max_context_bytes,omitempty"`
	GraphDepth      int      `json:"graph_depth,omitempty"`
	EnableGraph     bool     `json:"enable_graph"`
	AllowedPaths    []string `json:"allowed_paths,omitempty"`
	ExcludedPaths   []string `json:"excluded_paths,omitempty"`
}

// EvidenceItem represents a single verifiable grounded evidence excerpt with full provenance.
type EvidenceItem struct {
	RelPath          string                  `json:"rel_path"`
	Title            string                  `json:"title"`
	ContentHash      string                  `json:"content_hash"`
	Classification   EpistemicClassification `json:"classification"`
	Excerpt          string                  `json:"excerpt"`
	SizeBytes        int                     `json:"size_bytes"`
	LexicalScore     float64                 `json:"lexical_score"`
	RelationshipHops int                     `json:"relationship_hops"`
	InclusionReason  string                  `json:"inclusion_reason"`
	SourceHit        string                  `json:"source_hit,omitempty"`
	LinksUsed        []string                `json:"links_used,omitempty"`
	SourceMetadata   map[string]string       `json:"source_metadata,omitempty"`
}

// ConflictGroup captures an explicit disagreement or conflicting claims across notes.
type ConflictGroup struct {
	ConflictDescription string   `json:"conflict_description"`
	ContradictingNotes  []string `json:"contradicting_notes"`
	Excerpts            []string `json:"excerpts"`
}

// ExcludedCandidate logs notes that matched retrieval criteria but were omitted.
type ExcludedCandidate struct {
	RelPath string `json:"rel_path"`
	Reason  string `json:"reason"`
}

// ContextPackage is the complete, versioned, bounded context structure for future AI synthesis.
type ContextPackage struct {
	SchemaVersion      string              `json:"schema_version"`
	RequestID          string              `json:"request_id"`
	Query              string              `json:"query"`
	GeneratedAt        time.Time           `json:"generated_at"`
	Settings           ContextRequest      `json:"settings"`
	TotalEvidenceCount int                 `json:"total_evidence_count"`
	TotalContextBytes  int                 `json:"total_context_bytes"`
	MaxContextBytes    int                 `json:"max_context_bytes"`
	IsTruncated        bool                `json:"is_truncated"`
	TruncationReason   string              `json:"truncation_reason,omitempty"`
	Evidence           []EvidenceItem      `json:"evidence"`
	ConflictGroups     []ConflictGroup     `json:"conflict_groups,omitempty"`
	ExcludedCandidates []ExcludedCandidate `json:"excluded_candidates,omitempty"`
	Warnings           []string            `json:"warnings,omitempty"`
}
