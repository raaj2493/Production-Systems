package store

import (
	"fmt"
	"strings"
	"unicode"
)

// SearchResult represents a single full-text search match.
type SearchResult struct {
	RelPath string  `json:"rel_path"`
	Title   string  `json:"title"`
	Snippet string  `json:"snippet"`
	Rank    float64 `json:"rank"`
}

// Search queries the FTS5 index using BM25 ranking and extracts snippets.
// Malformed or complex queries are handled gracefully.
func (db *DB) Search(rawQuery string, limit int) ([]SearchResult, error) {
	trimmed := strings.TrimSpace(rawQuery)
	if trimmed == "" {
		return []SearchResult{}, nil
	}

	if limit <= 0 {
		limit = 20
	}

	ftsQuery := buildFTSQuery(trimmed)
	if ftsQuery == "" {
		return []SearchResult{}, nil
	}

	results, err := db.executeSearch(ftsQuery, limit)
	if err != nil {
		// If custom FTS query fails syntax validation, fall back to safe quoted search
		safeFallback := quoteEntireQuery(trimmed)
		if safeFallback == "" || safeFallback == `""` {
			return []SearchResult{}, nil
		}
		results, err = db.executeSearch(safeFallback, limit)
		if err != nil {
			return nil, fmt.Errorf("search query error: %w", err)
		}
	}

	return results, nil
}

func (db *DB) executeSearch(query string, limit int) ([]SearchResult, error) {
	// Column 0: rel_path (unindexed, weight 0.0)
	// Column 1: title (weight 3.0)
	// Column 2: content (weight 1.0)
	// bm25(notes_fts, 0.0, 3.0, 1.0) weights title matches 3x over body matches.
	// snippet(notes_fts, -1, ...) automatically selects the column with the best match.
	stmt := `
		SELECT rel_path, title, snippet(notes_fts, -1, '>>>', '<<<', '...', 15), bm25(notes_fts, 0.0, 3.0, 1.0) AS score
		FROM notes_fts
		WHERE notes_fts MATCH ?
		ORDER BY score ASC
		LIMIT ?;
	`

	rows, err := db.conn.Query(stmt, query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []SearchResult
	for rows.Next() {
		var r SearchResult
		if err := rows.Scan(&r.RelPath, &r.Title, &r.Snippet, &r.Rank); err != nil {
			return nil, err
		}
		// Clean up snippet formatting
		r.Snippet = strings.ReplaceAll(r.Snippet, "\n", " ")
		results = append(results, r)
	}

	return results, rows.Err()
}

type queryToken struct {
	text     string
	isPhrase bool
	isPrefix bool
}

// buildFTSQuery builds a safe FTS5 query string from user input.
// It supports exact tokens, multiword queries with implicit AND,
// quoted phrases ("brute force"), explicit prefix wildcards (optim*),
// and sanitizes punctuation and standalone operators.
func buildFTSQuery(input string) string {
	tokens := parseQueryTokens(input)
	if len(tokens) == 0 {
		return ""
	}

	// Filter standalone operator words (AND, OR, NOT) if other tokens exist
	filtered := filterOperatorTokens(tokens)
	if len(filtered) == 0 {
		filtered = tokens
	}

	var parts []string
	for _, tok := range filtered {
		escaped := strings.ReplaceAll(tok.text, `"`, `""`)
		if tok.isPrefix {
			parts = append(parts, `"`+escaped+`"*`)
		} else {
			parts = append(parts, `"`+escaped+`"`)
		}
	}

	return strings.Join(parts, " ")
}

func parseQueryTokens(input string) []queryToken {
	var tokens []queryToken
	runes := []rune(input)
	n := len(runes)
	i := 0

	for i < n {
		for i < n && (unicode.IsSpace(runes[i]) || isFTSDelimiter(runes[i])) {
			i++
		}
		if i >= n {
			break
		}

		if runes[i] == '"' {
			i++ // skip opening quote
			start := i
			for i < n && runes[i] != '"' {
				i++
			}
			raw := string(runes[start:i])
			if i < n && runes[i] == '"' {
				i++ // skip closing quote
			}

			// Check for explicit prefix wildcard after closing quote or inside phrase end
			isPrefix := false
			if i < n && runes[i] == '*' {
				isPrefix = true
				i++
			} else if strings.HasSuffix(raw, "*") {
				isPrefix = true
				raw = strings.TrimRight(raw, "*")
			}

			clean := cleanTokenText(raw)
			if clean != "" {
				tokens = append(tokens, queryToken{
					text:     clean,
					isPhrase: true,
					isPrefix: isPrefix,
				})
			}
		} else {
			start := i
			for i < n && !unicode.IsSpace(runes[i]) && !isFTSDelimiter(runes[i]) && runes[i] != '"' {
				i++
			}
			raw := string(runes[start:i])
			isPrefix := strings.HasSuffix(raw, "*")
			clean := cleanTokenText(raw)
			if clean != "" {
				tokens = append(tokens, queryToken{
					text:     clean,
					isPhrase: false,
					isPrefix: isPrefix,
				})
			}
		}
	}

	return tokens
}

func isFTSDelimiter(r rune) bool {
	return r == ':' || r == '^' || r == '(' || r == ')'
}

func cleanTokenText(s string) string {
	s = strings.TrimSpace(s)
	// Strip leading/trailing unsafe punctuation, quotes, wildcards, and delimiters
	s = strings.Trim(s, " \t\r\n\"*-,;:^().?![]{}~#@`/$%&=")
	return s
}

func filterOperatorTokens(tokens []queryToken) []queryToken {
	var nonOperators []queryToken
	for _, tok := range tokens {
		if !tok.isPhrase && !tok.isPrefix && isOperatorWord(tok.text) {
			continue
		}
		nonOperators = append(nonOperators, tok)
	}
	return nonOperators
}

func isOperatorWord(w string) bool {
	return strings.EqualFold(w, "AND") || strings.EqualFold(w, "OR") || strings.EqualFold(w, "NOT")
}

func quoteEntireQuery(input string) string {
	clean := strings.ReplaceAll(input, `"`, `""`)
	clean = strings.TrimSpace(clean)
	if clean == "" {
		return ""
	}
	return `"` + clean + `"`
}
