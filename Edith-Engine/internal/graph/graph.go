package graph

import (
	"fmt"
	"sort"
	"strings"

	"edith-engine/internal/store"
)

// Edge represents a directed relationship between notes.
type Edge struct {
	SourcePath    string `json:"source_path"`
	TargetPath    string `json:"target_path"`
	RawTarget     string `json:"raw_target"`
	DisplayText   string `json:"display_text"`
	HeadingAnchor string `json:"heading_anchor,omitempty"`
	IsWikiLink    bool   `json:"is_wikilink"`
	LineNumber    int    `json:"line_number"`
}

// TraversalResult represents a note discovered during graph traversal.
type TraversalResult struct {
	Path    string   `json:"path"`
	Title   string   `json:"title"`
	Depth   int      `json:"depth"`
	HopPath []string `json:"hop_path"`
}

// RelationshipMatch represents an explainable result combining lexical search with graph proximity.
type RelationshipMatch struct {
	RelPath          string  `json:"rel_path"`
	Title            string  `json:"title"`
	Snippet          string  `json:"snippet"`
	LexicalRank      float64 `json:"lexical_rank"`
	CombinedScore    float64 `json:"combined_score"`
	InclusionReason  string  `json:"inclusion_reason"`
	RelationshipHops int     `json:"relationship_hops"`
	SourceHit        string  `json:"source_hit,omitempty"`
}

// Service provides graph operations and relationship-aware retrieval.
type Service struct {
	db *store.DB
}

// New creates a new graph Service.
func New(db *store.DB) *Service {
	return &Service{db: db}
}

// Outgoing returns all outgoing links from sourcePath.
func (s *Service) Outgoing(sourcePath string) ([]Edge, error) {
	links, err := s.db.GetOutgoingLinks(sourcePath)
	if err != nil {
		return nil, err
	}
	return toEdges(links), nil
}

// Backlinks returns all incoming links pointing to targetPath.
func (s *Service) Backlinks(targetPath string) ([]Edge, error) {
	links, err := s.db.GetBacklinks(targetPath)
	if err != nil {
		return nil, err
	}
	return toEdges(links), nil
}

// Orphans returns paths of notes that have 0 incoming backlinks.
func (s *Service) Orphans() ([]string, error) {
	return s.db.GetOrphanNotes()
}

// BrokenLinks returns links whose target could not be resolved to an existing note.
func (s *Service) BrokenLinks() ([]Edge, error) {
	links, err := s.db.GetBrokenLinks()
	if err != nil {
		return nil, err
	}
	return toEdges(links), nil
}

// Traverse executes a cycle-safe breadth-first traversal up to maxDepth and maxNodes.
func (s *Service) Traverse(startPath string, maxDepth int, maxNodes int) ([]TraversalResult, error) {
	if maxDepth <= 0 {
		maxDepth = 2
	}
	if maxDepth > 5 {
		maxDepth = 5 // hard safety upper bound
	}
	if maxNodes <= 0 {
		maxNodes = 50
	}
	if maxNodes > 200 {
		maxNodes = 200 // hard safety upper bound
	}

	visited := make(map[string]bool)
	visited[startPath] = true

	type queueItem struct {
		path    string
		depth   int
		hopPath []string
	}

	queue := []queueItem{{path: startPath, depth: 0, hopPath: []string{startPath}}}
	var results []TraversalResult

	for len(queue) > 0 && len(results) < maxNodes {
		curr := queue[0]
		queue = queue[1:]

		if curr.depth > 0 {
			title := curr.path
			if note, err := s.db.GetNote(curr.path); err == nil && note != nil && note.Title != "" {
				title = note.Title
			}
			results = append(results, TraversalResult{
				Path:    curr.path,
				Title:   title,
				Depth:   curr.depth,
				HopPath: curr.hopPath,
			})
		}

		if curr.depth >= maxDepth || len(results) >= maxNodes {
			continue
		}

		// Traverse outgoing links
		out, err := s.db.GetOutgoingLinks(curr.path)
		if err == nil {
			for _, edge := range out {
				if edge.TargetPath != "" && !visited[edge.TargetPath] {
					visited[edge.TargetPath] = true
					newHops := append(append([]string{}, curr.hopPath...), edge.TargetPath)
					queue = append(queue, queueItem{
						path:    edge.TargetPath,
						depth:   curr.depth + 1,
						hopPath: newHops,
					})
				}
			}
		}

		// Traverse incoming backlinks
		in, err := s.db.GetBacklinks(curr.path)
		if err == nil {
			for _, edge := range in {
				if edge.SourcePath != "" && !visited[edge.SourcePath] {
					visited[edge.SourcePath] = true
					newHops := append(append([]string{}, curr.hopPath...), edge.SourcePath)
					queue = append(queue, queueItem{
						path:    edge.SourcePath,
						depth:   curr.depth + 1,
						hopPath: newHops,
					})
				}
			}
		}
	}

	return results, nil
}

// ShortestPath finds the shortest path between startPath and endPath using cycle-safe BFS.
// It returns the sequence of note paths from start to end, or nil if no path exists.
func (s *Service) ShortestPath(startPath, endPath string) ([]string, error) {
	if startPath == endPath {
		return []string{startPath}, nil
	}

	visited := make(map[string]bool)
	visited[startPath] = true

	type queueItem struct {
		path    string
		hopPath []string
	}

	queue := []queueItem{{path: startPath, hopPath: []string{startPath}}}

	for len(queue) > 0 {
		curr := queue[0]
		queue = queue[1:]

		if curr.path == endPath {
			return curr.hopPath, nil
		}

		// Follow outgoing links
		out, err := s.db.GetOutgoingLinks(curr.path)
		if err != nil {
			return nil, err
		}

		for _, edge := range out {
			if edge.TargetPath == "" {
				continue
			}
			if edge.TargetPath == endPath {
				return append(curr.hopPath, endPath), nil
			}
			if !visited[edge.TargetPath] {
				visited[edge.TargetPath] = true
				newHops := append(append([]string{}, curr.hopPath...), edge.TargetPath)
				queue = append(queue, queueItem{path: edge.TargetPath, hopPath: newHops})
			}
		}
	}

	return nil, nil // no path exists
}

// SearchWithRelationships combines lexical FTS5 search with bounded graph expansion.
// It returns explainable results identifying direct lexical hits, title hits, and 1-2 hop relationships.
func (s *Service) SearchWithRelationships(query string, limit int, expandHops int) ([]RelationshipMatch, error) {
	if limit <= 0 {
		limit = 20
	}
	if expandHops < 0 {
		expandHops = 1
	}
	if expandHops > 2 {
		expandHops = 2 // bound expansion depth to avoid overwhelming lexical relevance
	}

	lexicalHits, err := s.db.Search(query, limit)
	if err != nil {
		return nil, err
	}

	if len(lexicalHits) == 0 {
		return []RelationshipMatch{}, nil
	}

	matchedPaths := make(map[string]bool)
	var matches []RelationshipMatch

	// 1. Direct lexical matches
	for _, hit := range lexicalHits {
		matchedPaths[hit.RelPath] = true
		reason := "Direct lexical match"
		if strings.Contains(strings.ToLower(hit.Title), strings.ToLower(query)) {
			reason = "Title match"
		}

		matches = append(matches, RelationshipMatch{
			RelPath:          hit.RelPath,
			Title:            hit.Title,
			Snippet:          hit.Snippet,
			LexicalRank:      hit.Rank,
			CombinedScore:    hit.Rank, // BM25 base score
			InclusionReason:  reason,
			RelationshipHops: 0,
		})
	}

	if expandHops == 0 {
		return matches, nil
	}

	// 2. Expand 1-hop (outgoing and backlinks)
	type hopCandidate struct {
		path        string
		sourceHit   string
		isBacklink  bool
		hopDistance int
	}

	var candidates []hopCandidate
	visitedGraph := make(map[string]bool)
	for p := range matchedPaths {
		visitedGraph[p] = true
	}

	for _, hit := range lexicalHits {
		// Outgoing links from search hit
		out, _ := s.db.GetOutgoingLinks(hit.RelPath)
		for _, e := range out {
			if e.TargetPath != "" && !visitedGraph[e.TargetPath] {
				visitedGraph[e.TargetPath] = true
				candidates = append(candidates, hopCandidate{
					path:        e.TargetPath,
					sourceHit:   hit.RelPath,
					isBacklink:  false,
					hopDistance: 1,
				})
			}
		}

		// Backlinks pointing to search hit
		in, _ := s.db.GetBacklinks(hit.RelPath)
		for _, e := range in {
			if e.SourcePath != "" && !visitedGraph[e.SourcePath] {
				visitedGraph[e.SourcePath] = true
				candidates = append(candidates, hopCandidate{
					path:        e.SourcePath,
					sourceHit:   hit.RelPath,
					isBacklink:  true,
					hopDistance: 1,
				})
			}
		}
	}

	// 3. Optional 2-hop expansion
	if expandHops >= 2 {
		var twoHopCandidates []hopCandidate
		for _, cand := range candidates {
			out, _ := s.db.GetOutgoingLinks(cand.path)
			for _, e := range out {
				if e.TargetPath != "" && !visitedGraph[e.TargetPath] {
					visitedGraph[e.TargetPath] = true
					twoHopCandidates = append(twoHopCandidates, hopCandidate{
						path:        e.TargetPath,
						sourceHit:   cand.sourceHit,
						isBacklink:  false,
						hopDistance: 2,
					})
				}
			}
		}
		candidates = append(candidates, twoHopCandidates...)
	}

	// Assemble graph matches
	for _, cand := range candidates {
		note, err := s.db.GetNote(cand.path)
		if err != nil || note == nil {
			continue
		}

		reason := fmt.Sprintf("Directly linked from search hit: %s", cand.sourceHit)
		if cand.isBacklink {
			reason = fmt.Sprintf("Backlink to search hit: %s", cand.sourceHit)
		} else if cand.hopDistance == 2 {
			reason = fmt.Sprintf("2-hop relationship from search hit: %s", cand.sourceHit)
		}

		// Modest relationship contribution that does not overwhelm lexical relevance:
		// Base score penalty of +0.5 for 1-hop, +1.0 for 2-hop
		combinedScore := float64(cand.hopDistance) * 0.5

		matches = append(matches, RelationshipMatch{
			RelPath:          note.RelPath,
			Title:            note.Title,
			Snippet:          fmt.Sprintf("Connected via knowledge graph (%s)", reason),
			LexicalRank:      0,
			CombinedScore:    combinedScore,
			InclusionReason:  reason,
			RelationshipHops: cand.hopDistance,
			SourceHit:        cand.sourceHit,
		})
	}

	// Deterministic sorting: direct hits first, then 1-hop, then 2-hop, tie-broken by Title and RelPath
	sort.SliceStable(matches, func(i, j int) bool {
		if matches[i].RelationshipHops != matches[j].RelationshipHops {
			return matches[i].RelationshipHops < matches[j].RelationshipHops
		}
		if matches[i].CombinedScore != matches[j].CombinedScore {
			return matches[i].CombinedScore < matches[j].CombinedScore
		}
		if matches[i].Title != matches[j].Title {
			return matches[i].Title < matches[j].Title
		}
		return matches[i].RelPath < matches[j].RelPath
	})

	maxAllowed := limit * 2
	if len(matches) > maxAllowed {
		matches = matches[:maxAllowed]
	}

	return matches, nil
}

func toEdges(links []store.NoteLink) []Edge {
	edges := make([]Edge, len(links))
	for i, l := range links {
		edges[i] = Edge{
			SourcePath:    l.SourcePath,
			TargetPath:    l.TargetPath,
			RawTarget:     l.RawTarget,
			DisplayText:   l.DisplayText,
			HeadingAnchor: l.HeadingAnchor,
			IsWikiLink:    l.IsWikiLink,
			LineNumber:    l.LineNumber,
		}
	}
	return edges
}
