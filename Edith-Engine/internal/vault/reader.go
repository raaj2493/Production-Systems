package vault

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

var (
	wikilinkRegex   = regexp.MustCompile(`\[\[(.*?)\]\]`)
	mdLinkRegex     = regexp.MustCompile(`(?:^|[^!])\[([^\]]+)\]\(([^)]+)\)`)
	headingRegex    = regexp.MustCompile(`^(#{1,6})\s+(.*)$`)
	frontmatterRule = regexp.MustCompile(`(?s)^---\r?\n(.*?)\r?\n---`)
)

// Reader safely loads and parses Markdown notes from a vault.
type Reader struct {
	VaultRoot string
}

// NewReader constructs a new Reader for a given vault root.
func NewReader(vaultRoot string) (*Reader, error) {
	absRoot, err := filepath.Abs(vaultRoot)
	if err != nil {
		return nil, fmt.Errorf("invalid vault path: %w", err)
	}
	return &Reader{
		VaultRoot: filepath.Clean(absRoot),
	}, nil
}

// ReadNote reads a note given its vault-relative path.
// It verifies filesystem safety, calculates content hashes, extracts titles,
// and parses internal and external links while preserving the exact raw content.
func (r *Reader) ReadNote(relPath string) (*Note, error) {
	cleanRel := filepath.Clean(filepath.ToSlash(relPath))
	if strings.HasPrefix(cleanRel, "..") || filepath.IsAbs(cleanRel) {
		return nil, fmt.Errorf("path traversal rejected: %s", relPath)
	}

	fullPath := filepath.Join(r.VaultRoot, filepath.FromSlash(cleanRel))

	info, err := os.Stat(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("note does not exist: %s", relPath)
		}
		return nil, fmt.Errorf("cannot stat note %s: %w", relPath, err)
	}

	if info.IsDir() {
		return nil, fmt.Errorf("specified path is a directory, not a note: %s", relPath)
	}

	bytes, err := os.ReadFile(fullPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read note %s: %w", relPath, err)
	}

	content := string(bytes)
	hash := computeSHA256(bytes)
	title := ExtractTitle(content, cleanRel)
	links := ExtractLinks(content, cleanRel)

	return &Note{
		Metadata: NoteMetadata{
			RelPath:     cleanRel,
			Title:       title,
			ModTime:     info.ModTime().UTC().Truncate(time.Second),
			ContentHash: hash,
			SizeBytes:   info.Size(),
		},
		Content: content,
		Links:   links,
	}, nil
}

func computeSHA256(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

// ExtractTitle finds the best human-readable title for a note:
// 1. Frontmatter 'title:' property
// 2. First Markdown heading (# or ##)
// 3. Basename of the file (fallback)
func ExtractTitle(content, relPath string) string {
	// 1. Check YAML frontmatter
	if fmMatch := frontmatterRule.FindStringSubmatch(content); len(fmMatch) > 1 {
		scanner := bufio.NewScanner(strings.NewReader(fmMatch[1]))
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if strings.HasPrefix(line, "title:") {
				val := strings.TrimSpace(strings.TrimPrefix(line, "title:"))
				val = strings.Trim(val, `"'`)
				if val != "" {
					return val
				}
			}
		}
	}

	// 2. Check for first Markdown heading
	scanner := bufio.NewScanner(strings.NewReader(content))
	inFrontmatter := false
	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := strings.TrimSpace(scanner.Text())

		if lineNum == 1 && line == "---" {
			inFrontmatter = true
			continue
		}
		if inFrontmatter {
			if line == "---" {
				inFrontmatter = false
			}
			continue
		}

		if match := headingRegex.FindStringSubmatch(line); len(match) > 2 {
			headingText := strings.TrimSpace(match[2])
			// Clean any wikilinks or formatting inside heading
			cleanHeading := cleanInlineFormatting(headingText)
			if cleanHeading != "" {
				return cleanHeading
			}
		}
	}

	// 3. Fallback: filename without extension
	base := filepath.Base(relPath)
	ext := filepath.Ext(base)
	title := strings.TrimSuffix(base, ext)
	if title == "" {
		return "Untitled"
	}
	return title
}

// cleanInlineFormatting strips wikilinks and basic markdown wrappers from heading text
func cleanInlineFormatting(text string) string {
	// Replace [[target|alias]] with alias, or [[target]] with target
	text = wikilinkRegex.ReplaceAllStringFunc(text, func(m string) string {
		inner := strings.TrimSuffix(strings.TrimPrefix(m, "[["), "]]")
		parts := strings.Split(inner, "|")
		if len(parts) > 1 {
			return parts[1]
		}
		return parts[0]
	})
	text = strings.Trim(text, "*_`~")
	return strings.TrimSpace(text)
}

// ExtractLinks finds all active wikilinks [[...]] and standard markdown links [...](...) in note content.
// Links inside fenced code blocks (``` or ~~~) or inside inline code spans (`...`) are ignored.
func ExtractLinks(content, sourceRelPath string) []Link {
	var links []Link
	sourceDir := filepath.Dir(sourceRelPath)
	if sourceDir == "." {
		sourceDir = ""
	}

	scanner := bufio.NewScanner(strings.NewReader(content))
	lineNum := 0
	inCodeFence := false
	var fenceChar byte
	var fenceLen int

	for scanner.Scan() {
		lineNum++
		line := scanner.Text()

		trimmed := strings.TrimLeft(line, " ")
		leadingSpaces := len(line) - len(trimmed)

		// Check for code fence start/end (must have < 4 leading spaces in CommonMark)
		if leadingSpaces < 4 && len(trimmed) >= 3 && (trimmed[0] == '`' || trimmed[0] == '~') {
			char := trimmed[0]
			count := 0
			for count < len(trimmed) && trimmed[count] == char {
				count++
			}
			if count >= 3 {
				if !inCodeFence {
					inCodeFence = true
					fenceChar = char
					fenceLen = count
					continue
				} else if char == fenceChar && count >= fenceLen {
					inCodeFence = false
					continue
				}
			}
		}

		if inCodeFence {
			continue
		}

		// Mask inline code spans on the line before searching for links
		maskedLine := maskInlineCode(line)

		// 1. Extract Wikilinks: [[target]] or [[target|display]] or [[target#anchor]]
		matches := wikilinkRegex.FindAllStringSubmatchIndex(maskedLine, -1)
		for _, idx := range matches {
			if len(idx) < 4 {
				continue
			}
			rawInner := line[idx[2]:idx[3]]
			link := parseWikilink(rawInner, sourceRelPath, lineNum)
			links = append(links, link)
		}

		// 2. Extract Standard Markdown Links: [label](target)
		mdMatches := mdLinkRegex.FindAllStringSubmatchIndex(maskedLine, -1)
		for _, idx := range mdMatches {
			if len(idx) < 6 {
				continue
			}
			label := strings.TrimSpace(line[idx[2]:idx[3]])
			rawTarget := strings.TrimSpace(line[idx[4]:idx[5]])

			link := parseMarkdownLink(rawTarget, label, sourceRelPath, sourceDir, lineNum)
			links = append(links, link)
		}
	}

	return links
}

// maskInlineCode replaces content within backtick code spans with spaces of identical length,
// ensuring that links embedded inside inline code are not extracted while preserving string offsets.
func maskInlineCode(line string) string {
	b := []byte(line)
	n := len(b)
	i := 0
	for i < n {
		if b[i] == '`' {
			start := i
			for i < n && b[i] == '`' {
				i++
			}
			tickLen := i - start

			// Find matching closing sequence of exact same length
			closing := -1
			j := i
			for j < n {
				if b[j] == '`' {
					cStart := j
					for j < n && b[j] == '`' {
						j++
					}
					if j-cStart == tickLen {
						closing = cStart
						break
					}
				} else {
					j++
				}
			}

			if closing != -1 {
				end := closing + tickLen
				for k := start; k < end; k++ {
					b[k] = ' '
				}
				i = end
			}
		} else {
			i++
		}
	}
	return string(b)
}

func parseWikilink(rawInner, sourceRelPath string, lineNum int) Link {
	rawTarget := rawInner
	displayText := rawInner
	var anchor string

	// Handle alias: [[Target|Display]]
	if strings.Contains(rawInner, "|") {
		parts := strings.SplitN(rawInner, "|", 2)
		rawTarget = strings.TrimSpace(parts[0])
		displayText = strings.TrimSpace(parts[1])
	}

	// Handle anchor: [[Target#Heading]]
	cleanTarget := rawTarget
	if strings.Contains(rawTarget, "#") {
		parts := strings.SplitN(rawTarget, "#", 2)
		cleanTarget = strings.TrimSpace(parts[0])
		anchor = strings.TrimSpace(parts[1])
	}

	// Normalize target: remove .md if provided, keep slashes uniform
	cleanTarget = strings.TrimSuffix(cleanTarget, ".md")
	cleanTarget = strings.TrimSuffix(cleanTarget, ".MD")

	return Link{
		SourcePath:    sourceRelPath,
		RawTarget:     rawInner,
		CleanTarget:   cleanTarget,
		DisplayText:   displayText,
		HeadingAnchor: anchor,
		LineNumber:    lineNum,
		IsWikiLink:    true,
		IsExternal:    false,
	}
}

func parseMarkdownLink(rawTarget, label, sourceRelPath, sourceDir string, lineNum int) Link {
	isExt := strings.HasPrefix(rawTarget, "http://") ||
		strings.HasPrefix(rawTarget, "https://") ||
		strings.HasPrefix(rawTarget, "obsidian://") ||
		strings.HasPrefix(rawTarget, "mailto:")

	cleanTarget := rawTarget
	var anchor string

	if !isExt {
		// Strip query or anchors from local link
		if strings.Contains(cleanTarget, "#") {
			parts := strings.SplitN(cleanTarget, "#", 2)
			cleanTarget = parts[0]
			anchor = parts[1]
		}
		if strings.Contains(cleanTarget, "?") {
			parts := strings.SplitN(cleanTarget, "?", 2)
			cleanTarget = parts[0]
		}

		// Resolve relative paths if note is nested
		if sourceDir != "" && !filepath.IsAbs(cleanTarget) && !strings.HasPrefix(cleanTarget, "/") {
			resolved := filepath.Join(sourceDir, cleanTarget)
			cleanTarget = filepath.Clean(filepath.ToSlash(resolved))
		} else {
			cleanTarget = filepath.Clean(filepath.ToSlash(cleanTarget))
		}
		cleanTarget = strings.TrimPrefix(cleanTarget, "/")
	}

	return Link{
		SourcePath:    sourceRelPath,
		RawTarget:     rawTarget,
		CleanTarget:   cleanTarget,
		DisplayText:   label,
		HeadingAnchor: anchor,
		LineNumber:    lineNum,
		IsWikiLink:    false,
		IsExternal:    isExt,
	}
}

// EnsureSafePath verifies a path does not escape the given root directory.
func EnsureSafePath(root, relPath string) (string, error) {
	cleanRel := filepath.Clean(filepath.ToSlash(relPath))
	if strings.HasPrefix(cleanRel, "..") || filepath.IsAbs(cleanRel) {
		return "", errors.New("path traversal rejected: invalid relative path")
	}
	fullPath := filepath.Join(root, filepath.FromSlash(cleanRel))
	relToRoot, err := filepath.Rel(root, fullPath)
	if err != nil || strings.HasPrefix(relToRoot, "..") {
		return "", errors.New("path escapes root directory")
	}
	return fullPath, nil
}
