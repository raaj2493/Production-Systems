package workflows

import (
	"fmt"
	"strings"
	"time"

	"edith-engine/internal/graph"
	"edith-engine/internal/store"
)

// QueryRequest parameters for the deterministic knowledge-retrieval workflow.
type QueryRequest struct {
	Query    string `json:"query"`
	UseGraph bool   `json:"use_graph"`
	Limit    int    `json:"limit"`
}

// QueryEvidenceItem represents a piece of grounded evidence extracted from a vault note.
type QueryEvidenceItem struct {
	RelPath          string  `json:"rel_path"`
	Title            string  `json:"title"`
	Snippet          string  `json:"snippet"`
	ContentHash      string  `json:"content_hash"`
	Score            float64 `json:"score"`
	InclusionReason  string  `json:"inclusion_reason"`
	RelationshipHops int     `json:"relationship_hops"`
	SourceHit        string  `json:"source_hit,omitempty"`
}

// QueryResult encapsulates the complete grounded evidence retrieved for a query.
type QueryResult struct {
	Query           string              `json:"query"`
	EvidenceFound   bool                `json:"evidence_found"`
	Message         string              `json:"message"`
	TotalCandidates int                 `json:"total_candidates"`
	Items           []QueryEvidenceItem `json:"items"`
	ExecutedAt      time.Time           `json:"executed_at"`
}

// QueryWorkflow coordinates deterministic, explainable retrieval across FTS5 and the Knowledge Graph.
type QueryWorkflow struct {
	db    *store.DB
	graph *graph.Service
}

// NewQueryWorkflow creates a QueryWorkflow.
func NewQueryWorkflow(db *store.DB, g *graph.Service) *QueryWorkflow {
	return &QueryWorkflow{
		db:    db,
		graph: g,
	}
}

// Run executes the query pipeline.
func (w *QueryWorkflow) Run(req QueryRequest) (*QueryResult, error) {
	trimmed := strings.TrimSpace(req.Query)
	if trimmed == "" {
		return nil, fmt.Errorf("query string cannot be empty")
	}

	limit := req.Limit
	if limit <= 0 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}

	res := &QueryResult{
		Query:      trimmed,
		Items:      make([]QueryEvidenceItem, 0),
		ExecutedAt: time.Now().UTC(),
	}

	if req.UseGraph && w.graph != nil {
		// Graph-aware retrieval
		matches, err := w.graph.SearchWithRelationships(trimmed, limit, 1)
		if err != nil {
			return nil, fmt.Errorf("graph search failed: %w", err)
		}

		if len(matches) == 0 {
			res.EvidenceFound = false
			res.Message = fmt.Sprintf("No evidence found for query %q in vault notes or knowledge graph.", trimmed)
			return res, nil
		}

		for _, m := range matches {
			var hash string
			if note, err := w.db.GetNote(m.RelPath); err == nil && note != nil {
				hash = note.ContentHash
			}

			res.Items = append(res.Items, QueryEvidenceItem{
				RelPath:          m.RelPath,
				Title:            m.Title,
				Snippet:          m.Snippet,
				ContentHash:      hash,
				Score:            m.CombinedScore,
				InclusionReason:  m.InclusionReason,
				RelationshipHops: m.RelationshipHops,
				SourceHit:        m.SourceHit,
			})
		}
	} else {
		// Lexical BM25 retrieval
		hits, err := w.db.Search(trimmed, limit)
		if err != nil {
			return nil, fmt.Errorf("lexical search failed: %w", err)
		}

		if len(hits) == 0 {
			res.EvidenceFound = false
			res.Message = fmt.Sprintf("No evidence found for query %q in indexed notes.", trimmed)
			return res, nil
		}

		for _, h := range hits {
			var hash string
			if note, err := w.db.GetNote(h.RelPath); err == nil && note != nil {
				hash = note.ContentHash
			}

			reason := "Direct lexical match"
			if strings.Contains(strings.ToLower(h.Title), strings.ToLower(trimmed)) {
				reason = "Title match"
			}

			res.Items = append(res.Items, QueryEvidenceItem{
				RelPath:          h.RelPath,
				Title:            h.Title,
				Snippet:          h.Snippet,
				ContentHash:      hash,
				Score:            h.Rank,
				InclusionReason:  reason,
				RelationshipHops: 0,
			})
		}
	}

	res.EvidenceFound = len(res.Items) > 0
	res.TotalCandidates = len(res.Items)
	res.Message = fmt.Sprintf("Retrieved %d grounded evidence items for %q", len(res.Items), trimmed)

	return res, nil
}
