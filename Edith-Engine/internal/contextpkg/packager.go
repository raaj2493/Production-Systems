package contextpkg

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"edith-engine/internal/graph"
	"edith-engine/internal/store"
	"edith-engine/internal/vault"
)

// Packager coordinates model-independent grounded evidence retrieval and bounded context packaging.
type Packager struct {
	vaultRoot string
	db        *store.DB
	graph     *graph.Service
	reader    *vault.Reader
}

// NewPackager creates a new Packager.
func NewPackager(vaultRoot string, db *store.DB, g *graph.Service, reader *vault.Reader) *Packager {
	return &Packager{
		vaultRoot: filepath.Clean(vaultRoot),
		db:        db,
		graph:     g,
		reader:    reader,
	}
}

// Assemble validates the request, executes grounded retrieval, enforces the context byte budget,
// and returns a versioned, provenance-preserving ContextPackage.
func (p *Packager) Assemble(req ContextRequest) (*ContextPackage, error) {
	// 1. Input validation & default constraints
	if strings.TrimSpace(req.Query) == "" && len(req.SelectedNotes) == 0 {
		return nil, fmt.Errorf("either query or selected_notes must be provided")
	}

	maxResults := req.MaxResults
	if maxResults <= 0 {
		maxResults = 10
	}
	if maxResults > 50 {
		maxResults = 50 // hard safety upper bound
	}

	maxBytes := req.MaxContextBytes
	if maxBytes <= 0 {
		maxBytes = 16384 // 16 KB default safe approximation
	}
	if maxBytes < 256 {
		maxBytes = 256
	}
	if maxBytes > 131072 {
		maxBytes = 131072 // 128 KB hard upper bound
	}

	graphDepth := req.GraphDepth
	if graphDepth < 0 {
		graphDepth = 1
	}
	if graphDepth > 2 {
		graphDepth = 2 // bound expansion depth to preserve lexical relevance
	}

	// Validate path security (protection against vault escaping)
	for _, notePath := range req.SelectedNotes {
		if err := validateSafePath(notePath); err != nil {
			return nil, fmt.Errorf("invalid selected note path %q: %w", notePath, err)
		}
	}
	for _, ap := range req.AllowedPaths {
		if err := validateSafePath(ap); err != nil {
			return nil, fmt.Errorf("invalid allowed path %q: %w", ap, err)
		}
	}
	for _, ep := range req.ExcludedPaths {
		if err := validateSafePath(ep); err != nil {
			return nil, fmt.Errorf("invalid excluded path %q: %w", ep, err)
		}
	}

	reqID := fmt.Sprintf("ctx-%d", time.Now().UnixNano())
	pkg := &ContextPackage{
		SchemaVersion:      SchemaVersion,
		RequestID:          reqID,
		Query:              strings.TrimSpace(req.Query),
		GeneratedAt:        time.Now().UTC(),
		Settings:           req,
		MaxContextBytes:    maxBytes,
		Evidence:           make([]EvidenceItem, 0),
		ConflictGroups:     make([]ConflictGroup, 0),
		ExcludedCandidates: make([]ExcludedCandidate, 0),
		Warnings:           make([]string, 0),
	}

	// 2. Candidate collection
	type rawCandidate struct {
		path            string
		inclusionReason string
		lexicalRank     float64
		combinedScore   float64
		hops            int
		sourceHit       string
		isExplicit      bool
	}

	var candidates []rawCandidate
	visited := make(map[string]bool)

	// Step 2A: Explicitly selected notes (highest priority)
	for _, sel := range req.SelectedNotes {
		clean := filepath.Clean(filepath.ToSlash(sel))
		if !visited[clean] {
			visited[clean] = true
			candidates = append(candidates, rawCandidate{
				path:            clean,
				inclusionReason: "Explicitly selected note",
				lexicalRank:     0,
				combinedScore:   0,
				hops:            0,
				isExplicit:      true,
			})
		}
	}

	// Step 2B: Retrieval via query
	query := strings.TrimSpace(req.Query)
	if query != "" {
		if req.EnableGraph && p.graph != nil && graphDepth > 0 {
			graphMatches, err := p.graph.SearchWithRelationships(query, maxResults*2, graphDepth)
			if err == nil {
				for _, m := range graphMatches {
					if !visited[m.RelPath] {
						visited[m.RelPath] = true
						candidates = append(candidates, rawCandidate{
							path:            m.RelPath,
							inclusionReason: m.InclusionReason,
							lexicalRank:     m.LexicalRank,
							combinedScore:   m.CombinedScore,
							hops:            m.RelationshipHops,
							sourceHit:       m.SourceHit,
							isExplicit:      false,
						})
					}
				}
			}
		} else {
			hits, err := p.db.Search(query, maxResults*2)
			if err == nil {
				for _, h := range hits {
					if !visited[h.RelPath] {
						visited[h.RelPath] = true
						reason := "Direct lexical match"
						if strings.Contains(strings.ToLower(h.Title), strings.ToLower(query)) {
							reason = "Title match"
						}
						candidates = append(candidates, rawCandidate{
							path:            h.RelPath,
							inclusionReason: reason,
							lexicalRank:     h.Rank,
							combinedScore:   h.Rank,
							hops:            0,
							isExplicit:      false,
						})
					}
				}
			}
		}
	}

	// If no candidates found
	if len(candidates) == 0 {
		pkg.Warnings = append(pkg.Warnings, "No grounded evidence found matching query or selection criteria")
		return pkg, nil
	}

	// 3. Filtering: Allowed and Excluded Path Scope
	var filtered []rawCandidate
	for _, cand := range candidates {
		// Check excluded paths
		isExcluded := false
		for _, ep := range req.ExcludedPaths {
			cleanEP := filepath.Clean(filepath.ToSlash(ep))
			if strings.HasPrefix(cand.path, cleanEP) {
				pkg.ExcludedCandidates = append(pkg.ExcludedCandidates, ExcludedCandidate{
					RelPath: cand.path,
					Reason:  fmt.Sprintf("path matches excluded scope %q", ep),
				})
				isExcluded = true
				break
			}
		}
		if isExcluded {
			continue
		}

		// Check allowed paths
		if len(req.AllowedPaths) > 0 {
			isAllowed := false
			for _, ap := range req.AllowedPaths {
				cleanAP := filepath.Clean(filepath.ToSlash(ap))
				if strings.HasPrefix(cand.path, cleanAP) {
					isAllowed = true
					break
				}
			}
			if !isAllowed {
				pkg.ExcludedCandidates = append(pkg.ExcludedCandidates, ExcludedCandidate{
					RelPath: cand.path,
					Reason:  "path not within configured allowed scope",
				})
				continue
			}
		}

		filtered = append(filtered, cand)
	}

	// 4. Deterministic sorting:
	// Explicit notes first, then direct lexical matches (hops=0), then 1-hop, then 2-hop, tie-broken by CombinedScore, Title, RelPath
	sort.SliceStable(filtered, func(i, j int) bool {
		if filtered[i].isExplicit != filtered[j].isExplicit {
			return filtered[i].isExplicit // true before false
		}
		if filtered[i].hops != filtered[j].hops {
			return filtered[i].hops < filtered[j].hops
		}
		if filtered[i].combinedScore != filtered[j].combinedScore {
			return filtered[i].combinedScore < filtered[j].combinedScore
		}
		return filtered[i].path < filtered[j].path
	})

	// 5. Build evidence items & track conflict groups
	type builtItem struct {
		item      EvidenceItem
		fullBytes int
	}
	var builtItems []builtItem
	candidateTitles := make(map[string]string)
	candidateContents := make(map[string]string)

	for _, cand := range filtered {
		note, err := p.db.GetNote(cand.path)
		if err != nil || note == nil {
			pkg.ExcludedCandidates = append(pkg.ExcludedCandidates, ExcludedCandidate{
				RelPath: cand.path,
				Reason:  "note unindexed or missing from database",
			})
			continue
		}

		title := note.Title
		if title == "" {
			title = filepath.Base(cand.path)
		}
		candidateTitles[cand.path] = title

		// Read content to extract excerpt & classify
		var content string
		if readNote, err := p.reader.ReadNote(cand.path); err == nil && readNote != nil {
			content = readNote.Content
		}
		candidateContents[cand.path] = content

		// Deterministic excerpt extraction
		excerpt := extractRelevantExcerpt(content, query, title)
		classification := inferEpistemicClassification(cand.path, content)

		item := EvidenceItem{
			RelPath:          cand.path,
			Title:            title,
			ContentHash:      note.ContentHash,
			Classification:   classification,
			Excerpt:          excerpt,
			SizeBytes:        len([]byte(excerpt)),
			LexicalScore:     cand.lexicalRank,
			RelationshipHops: cand.hops,
			InclusionReason:  cand.inclusionReason,
			SourceHit:        cand.sourceHit,
		}

		builtItems = append(builtItems, builtItem{
			item:      item,
			fullBytes: len([]byte(excerpt)),
		})
	}

	// 6. Conflict detection: conservative textual contradiction preservation
	for i := 0; i < len(builtItems); i++ {
		for j := i + 1; j < len(builtItems); j++ {
			p1, p2 := builtItems[i].item.RelPath, builtItems[j].item.RelPath
			c1, c2 := candidateContents[p1], candidateContents[p2]
			t1, t2 := strings.ToLower(candidateTitles[p1]), strings.ToLower(candidateTitles[p2])

			// Conservative contradiction check: identical titles with active vs deprecated status
			if t1 == t2 && t1 != "" {
				l1, l2 := strings.ToLower(c1), strings.ToLower(c2)
				if (strings.Contains(l1, "status: active") && strings.Contains(l2, "status: deprecated")) ||
					(strings.Contains(l2, "status: active") && strings.Contains(l1, "status: deprecated")) {
					pkg.ConflictGroups = append(pkg.ConflictGroups, ConflictGroup{
						ConflictDescription: fmt.Sprintf("Direct contradiction on topic %q: one note is active, one is deprecated", candidateTitles[p1]),
						ContradictingNotes:  []string{p1, p2},
						Excerpts: []string{
							fmt.Sprintf("%s (hash: %s)", p1, builtItems[i].item.ContentHash[:12]),
							fmt.Sprintf("%s (hash: %s)", p2, builtItems[j].item.ContentHash[:12]),
						},
					})
				}
			}
		}
	}

	// 7. Budget enforcement (UTF-8 bytes limit)
	currentBytes := 0
	for idx, b := range builtItems {
		if len(pkg.Evidence) >= maxResults {
			pkg.ExcludedCandidates = append(pkg.ExcludedCandidates, ExcludedCandidate{
				RelPath: b.item.RelPath,
				Reason:  fmt.Sprintf("maximum result count limit (%d) reached", maxResults),
			})
			continue
		}

		itemBytes := b.fullBytes
		if currentBytes+itemBytes <= maxBytes {
			// Fits fully
			pkg.Evidence = append(pkg.Evidence, b.item)
			currentBytes += itemBytes
		} else {
			// Cannot fit fully
			remainingBudget := maxBytes - currentBytes
			truncationMarker := "\n[TRUNCATED: context budget reached]"
			markerBytes := len([]byte(truncationMarker))

			if remainingBudget > markerBytes+64 {
				// We can include a clean truncated excerpt
				sliceBudget := remainingBudget - markerBytes
				rawBytes := []byte(b.item.Excerpt)
				if sliceBudget > len(rawBytes) {
					sliceBudget = len(rawBytes)
				}
				// Ensure safe UTF-8 boundary
				for sliceBudget > 0 && (rawBytes[sliceBudget-1]&0xC0) == 0x80 {
					sliceBudget--
				}
				truncatedExcerpt := string(rawBytes[:sliceBudget]) + truncationMarker
				b.item.Excerpt = truncatedExcerpt
				b.item.SizeBytes = len([]byte(truncatedExcerpt))
				pkg.Evidence = append(pkg.Evidence, b.item)
				currentBytes += b.item.SizeBytes
			} else {
				// Not enough room to fit meaningful excerpt
				pkg.ExcludedCandidates = append(pkg.ExcludedCandidates, ExcludedCandidate{
					RelPath: b.item.RelPath,
					Reason:  "exceeded context byte budget",
				})
			}

			// Mark all subsequent candidates as excluded due to budget
			pkg.IsTruncated = true
			pkg.TruncationReason = fmt.Sprintf("Exceeded configured context byte budget of %d bytes", maxBytes)
			for next := idx + 1; next < len(builtItems); next++ {
				pkg.ExcludedCandidates = append(pkg.ExcludedCandidates, ExcludedCandidate{
					RelPath: builtItems[next].item.RelPath,
					Reason:  "exceeded context byte budget",
				})
			}
			break
		}
	}

	pkg.TotalEvidenceCount = len(pkg.Evidence)
	pkg.TotalContextBytes = currentBytes

	return pkg, nil
}

func inferEpistemicClassification(relPath, content string) EpistemicClassification {
	lowerPath := strings.ToLower(relPath)
	lowerContent := strings.ToLower(content)

	if strings.HasPrefix(lowerPath, "00-sources/") || strings.HasPrefix(lowerPath, "02-raw-sources/") || strings.Contains(lowerContent, "type: source") {
		return ClassOriginalSource
	}
	if strings.HasPrefix(lowerPath, "03-wiki/") || strings.Contains(lowerContent, "type: wiki") {
		return ClassWikiNote
	}
	if strings.Contains(lowerContent, "#interpretation") || strings.Contains(lowerContent, "type: interpretation") {
		return ClassInterpretation
	}
	if strings.Contains(lowerContent, "#plan") || strings.Contains(lowerContent, "type: plan") {
		return ClassPlan
	}
	if strings.Contains(lowerContent, "conflict: true") || strings.Contains(lowerContent, "#conflict") {
		return ClassConflict
	}
	return ClassUnknown
}

func extractRelevantExcerpt(content, query, title string) string {
	if content == "" {
		return fmt.Sprintf("Note: %s", title)
	}

	lines := strings.Split(content, "\n")
	var usefulLines []string

	// Clean query terms (strip quotes, wildcards, delimiters)
	queryFields := strings.Fields(strings.ToLower(query))
	var cleanTerms []string
	for _, f := range queryFields {
		t := strings.Trim(f, `*"'(),;:.`)
		if len(t) > 2 {
			cleanTerms = append(cleanTerms, t)
		}
	}

	// If note is reasonably compact (<= 100 lines), include the entire note body
	// skipping frontmatter fences
	if len(lines) <= 100 {
		inFrontmatter := false
		fenceCount := 0
		for _, l := range lines {
			trimmed := strings.TrimSpace(l)
			if trimmed == "---" {
				fenceCount++
				if fenceCount <= 2 {
					inFrontmatter = (fenceCount == 1)
					continue
				}
			}
			if !inFrontmatter && trimmed != "" {
				usefulLines = append(usefulLines, trimmed)
			}
		}
		if len(usefulLines) > 0 {
			return strings.Join(usefulLines, "\n")
		}
	}

	// For longer notes, find the most relevant section
	// Prioritize matches in headings (#, ##, ###) over body text
	matchLineIdx := -1
	headingMatchIdx := -1

	if len(cleanTerms) > 0 {
		for i, l := range lines {
			lowerLine := strings.ToLower(l)
			isHeading := strings.HasPrefix(strings.TrimSpace(lowerLine), "#")
			for _, term := range cleanTerms {
				if strings.Contains(lowerLine, term) {
					if isHeading && headingMatchIdx == -1 {
						headingMatchIdx = i
					}
					if matchLineIdx == -1 {
						matchLineIdx = i
					}
					break
				}
			}
			if headingMatchIdx != -1 {
				break
			}
		}
	}

	bestMatchIdx := headingMatchIdx
	if bestMatchIdx == -1 {
		bestMatchIdx = matchLineIdx
	}

	if bestMatchIdx != -1 {
		start := bestMatchIdx - 2
		if start < 0 {
			start = 0
		}
		end := bestMatchIdx + 50
		if end > len(lines) {
			end = len(lines)
		}
		for i := start; i < end; i++ {
			trimmed := strings.TrimSpace(lines[i])
			if trimmed != "" && trimmed != "---" {
				usefulLines = append(usefulLines, trimmed)
			}
		}
	} else {
		// Take first 25 non-empty non-frontmatter lines
		inFrontmatter := false
		fenceCount := 0
		for _, l := range lines {
			trimmed := strings.TrimSpace(l)
			if trimmed == "---" {
				fenceCount++
				if fenceCount <= 2 {
					inFrontmatter = (fenceCount == 1)
					continue
				}
			}
			if !inFrontmatter && trimmed != "" {
				usefulLines = append(usefulLines, trimmed)
				if len(usefulLines) >= 25 {
					break
				}
			}
		}
	}

	if len(usefulLines) == 0 {
		return fmt.Sprintf("Note: %s", title)
	}
	return strings.Join(usefulLines, "\n")
}

func validateSafePath(p string) error {
	clean := filepath.Clean(filepath.ToSlash(p))
	if strings.HasPrefix(clean, "../") || clean == ".." || filepath.IsAbs(p) {
		return fmt.Errorf("path escapes vault root")
	}
	return nil
}
