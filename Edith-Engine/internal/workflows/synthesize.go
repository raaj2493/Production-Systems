package workflows

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"edith-engine/internal/graph"
	"edith-engine/internal/proposals"
	"edith-engine/internal/store"
)

// SynthesizeRequest parameters for deterministic multi-source knowledge synthesis.
type SynthesizeRequest struct {
	Topic          string   `json:"topic"`
	SelectedNotes  []string `json:"selected_notes,omitempty"`
	MaxCandidates  int      `json:"max_candidates,omitempty"`
	SubmitProposal bool     `json:"submit_proposal,omitempty"`
	TargetFolder   string   `json:"target_folder,omitempty"`
}

// SynthesisEvidenceItem captures an excerpt from a source note with complete provenance.
type SynthesisEvidenceItem struct {
	SourcePath      string `json:"source_path"`
	SourceTitle     string `json:"source_title"`
	ContentHash     string `json:"content_hash"`
	Excerpt         string `json:"excerpt"`
	InclusionReason string `json:"inclusion_reason"`
}

// SynthesisEvidenceGroup organizes retrieved evidence by source or thematic subtopic.
type SynthesisEvidenceGroup struct {
	GroupName string                  `json:"group_name"`
	Items     []SynthesisEvidenceItem `json:"items"`
}

// ContradictionGroup preserves explicit conflicts and disagreements between notes.
type ContradictionGroup struct {
	Description string   `json:"description"`
	Notes       []string `json:"notes"`
	Excerpts    []string `json:"excerpts"`
}

// SynthesizeResult contains structured synthesis preparation and an optional staged proposal.
type SynthesizeResult struct {
	Topic             string                   `json:"topic"`
	GeneratedAt       time.Time                `json:"generated_at"`
	TotalSources      int                      `json:"total_sources"`
	EvidenceGroups    []SynthesisEvidenceGroup `json:"evidence_groups"`
	Contradictions    []ContradictionGroup     `json:"contradictions"`
	StructuredOutline string                   `json:"structured_outline"`
	ProposalID        string                   `json:"proposal_id,omitempty"`
	ProposedPath      string                   `json:"proposed_path,omitempty"`
}

// SynthesizeWorkflow coordinates deterministic synthesis preparation without AI hallucination.
type SynthesizeWorkflow struct {
	db        *store.DB
	graph     *graph.Service
	proposals *proposals.Service
}

// NewSynthesizeWorkflow creates a SynthesizeWorkflow.
func NewSynthesizeWorkflow(db *store.DB, g *graph.Service, ps *proposals.Service) *SynthesizeWorkflow {
	return &SynthesizeWorkflow{
		db:        db,
		graph:     g,
		proposals: ps,
	}
}

// Run executes the synthesis preparation pipeline.
func (w *SynthesizeWorkflow) Run(req SynthesizeRequest) (*SynthesizeResult, error) {
	topic := strings.TrimSpace(req.Topic)
	if topic == "" && len(req.SelectedNotes) == 0 {
		return nil, fmt.Errorf("either topic or selected_notes must be provided")
	}

	maxNotes := req.MaxCandidates
	if maxNotes <= 0 {
		maxNotes = 10
	}
	if maxNotes > 30 {
		maxNotes = 30
	}

	// 1. Gather candidate notes
	candidatePaths := make([]string, 0)
	candidateReasons := make(map[string]string)
	visited := make(map[string]bool)

	// Explicitly selected notes
	for _, p := range req.SelectedNotes {
		clean := filepath.Clean(p)
		if !visited[clean] {
			visited[clean] = true
			candidatePaths = append(candidatePaths, clean)
			candidateReasons[clean] = "Explicitly selected note"
		}
	}

	// Search-retrieved notes if topic provided
	if topic != "" {
		if w.graph != nil {
			matches, err := w.graph.SearchWithRelationships(topic, maxNotes, 1)
			if err == nil {
				for _, m := range matches {
					if !visited[m.RelPath] && len(candidatePaths) < maxNotes {
						visited[m.RelPath] = true
						candidatePaths = append(candidatePaths, m.RelPath)
						candidateReasons[m.RelPath] = m.InclusionReason
					}
				}
			}
		} else {
			hits, err := w.db.Search(topic, maxNotes)
			if err == nil {
				for _, h := range hits {
					if !visited[h.RelPath] && len(candidatePaths) < maxNotes {
						visited[h.RelPath] = true
						candidatePaths = append(candidatePaths, h.RelPath)
						candidateReasons[h.RelPath] = "Lexical search match"
					}
				}
			}
		}
	}

	if len(candidatePaths) == 0 {
		return &SynthesizeResult{
			Topic:             topic,
			GeneratedAt:       time.Now().UTC(),
			TotalSources:      0,
			EvidenceGroups:    []SynthesisEvidenceGroup{},
			Contradictions:    []ContradictionGroup{},
			StructuredOutline: fmt.Sprintf("# Synthesis: %s\n\nNo evidence found in vault to synthesize.", topic),
		}, nil
	}

	// 2. Collect evidence items with provenance
	var groups []SynthesisEvidenceGroup
	noteContents := make(map[string]string)
	noteTitles := make(map[string]string)

	for _, p := range candidatePaths {
		note, err := w.db.GetNote(p)
		if err != nil || note == nil {
			continue
		}

		title := note.Title
		if title == "" {
			title = filepath.Base(p)
		}
		noteTitles[p] = title

		// Fetch content excerpt
		var excerpt string
		searchHits, err := w.db.Search(title, 1)
		if err == nil && len(searchHits) > 0 && searchHits[0].Snippet != "" {
			excerpt = searchHits[0].Snippet
		} else {
			excerpt = fmt.Sprintf("Source note: %s", title)
		}

		item := SynthesisEvidenceItem{
			SourcePath:      p,
			SourceTitle:     title,
			ContentHash:     note.ContentHash,
			Excerpt:         excerpt,
			InclusionReason: candidateReasons[p],
		}

		groups = append(groups, SynthesisEvidenceGroup{
			GroupName: title,
			Items:     []SynthesisEvidenceItem{item},
		})

		// Track title & content for contradiction detection
		noteContents[p] = note.Title
	}

	// 3. Detect conservative contradictions & textual disagreements
	var contradictions []ContradictionGroup
	for i := 0; i < len(candidatePaths); i++ {
		for j := i + 1; j < len(candidatePaths); j++ {
			p1, p2 := candidatePaths[i], candidatePaths[j]
			t1, t2 := strings.ToLower(noteTitles[p1]), strings.ToLower(noteTitles[p2])

			// If two notes have identical titles or mutual links with opposing terms
			if t1 == t2 && t1 != "" {
				contradictions = append(contradictions, ContradictionGroup{
					Description: fmt.Sprintf("Candidate duplicate/contradictory notes on %q", noteTitles[p1]),
					Notes:       []string{p1, p2},
					Excerpts: []string{
						fmt.Sprintf("Source %s (hash: %s)", p1, groups[i].Items[0].ContentHash[:8]),
						fmt.Sprintf("Source %s (hash: %s)", p2, groups[j].Items[0].ContentHash[:8]),
					},
				})
			}
		}
	}

	// 4. Generate structured outline with source references
	var sb strings.Builder
	titleHeading := topic
	if titleHeading == "" {
		titleHeading = "Knowledge Synthesis"
	}
	sb.WriteString(fmt.Sprintf("# Synthesis: %s\n\n", titleHeading))
	sb.WriteString(fmt.Sprintf("> Generated deterministically on %s. Evidence preserved from %d source notes.\n\n",
		time.Now().UTC().Format(time.RFC3339), len(groups)))

	sb.WriteString("## Evidence Groups & Citations\n\n")
	for _, grp := range groups {
		sb.WriteString(fmt.Sprintf("### %s\n", grp.GroupName))
		for _, item := range grp.Items {
			baseName := strings.TrimSuffix(filepath.Base(item.SourcePath), filepath.Ext(item.SourcePath))
			sb.WriteString(fmt.Sprintf("- **Citation**: [[%s]] (`%s`)\n", baseName, item.SourcePath))
			sb.WriteString(fmt.Sprintf("  - *Hash*: `%s`\n", item.ContentHash[:12]))
			sb.WriteString(fmt.Sprintf("  - *Inclusion*: %s\n", item.InclusionReason))
			if item.Excerpt != "" {
				sb.WriteString(fmt.Sprintf("  - *Excerpt*: %s\n", item.Excerpt))
			}
		}
		sb.WriteString("\n")
	}

	if len(contradictions) > 0 {
		sb.WriteString("## Potential Disagreements & Uncertainty\n\n")
		for _, c := range contradictions {
			sb.WriteString(fmt.Sprintf("- **Conflict**: %s\n", c.Description))
			for _, note := range c.Notes {
				sb.WriteString(fmt.Sprintf("  - Note: `%s`\n", note))
			}
		}
		sb.WriteString("\n")
	}

	sb.WriteString("## Synthesized Knowledge Outline\n\n")
	sb.WriteString("<!-- Grounded synthesis template for human review and future AI synthesis -->\n")
	sb.WriteString("- [ ] Core principles established across sources\n")
	sb.WriteString("- [ ] Divergences, edge cases, and differing viewpoints\n")
	sb.WriteString("- [ ] Open questions requiring further exploration\n")

	outline := sb.String()

	result := &SynthesizeResult{
		Topic:             topic,
		GeneratedAt:       time.Now().UTC(),
		TotalSources:      len(groups),
		EvidenceGroups:    groups,
		Contradictions:    contradictions,
		StructuredOutline: outline,
	}

	// 5. Submit proposal if requested
	if req.SubmitProposal {
		folder := req.TargetFolder
		if folder == "" {
			folder = "03-Wiki/Syntheses"
		}
		slug := sanitizeFilename(titleHeading)
		targetPath := filepath.Join(folder, slug+".md")
		result.ProposedPath = targetPath

		reason := fmt.Sprintf("Synthesize knowledge on %q from %d sources", titleHeading, len(candidatePaths))
		p, err := w.proposals.CreateProposal(targetPath, reason, candidatePaths, outline)
		if err == nil {
			result.ProposalID = p.ID
			_ = w.db.LogActivity("synthesize", len(candidatePaths), 0, 0, 0,
				fmt.Sprintf("Synthesized %s across %d sources into proposal %s", titleHeading, len(candidatePaths), p.ID))
		}
	}

	return result, nil
}
