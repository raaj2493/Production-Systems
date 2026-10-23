package vault

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// DefaultExcludedDirs contains directory names that are always skipped during scans.
var DefaultExcludedDirs = map[string]bool{
	".obsidian":    true,
	".git":         true,
	".trash":       true,
	".cache":       true,
	"node_modules": true,
	"Edith-Engine": true,
}

// Scanner discovers eligible Markdown notes within a vault directory safely.
type Scanner struct {
	VaultRoot    string
	ExcludedDirs map[string]bool
	Warnings     []string
}

// NewScanner creates a new Scanner instance for the specified vault root.
func NewScanner(vaultRoot string) (*Scanner, error) {
	absRoot, err := filepath.Abs(vaultRoot)
	if err != nil {
		return nil, fmt.Errorf("invalid vault path: %w", err)
	}

	info, err := os.Stat(absRoot)
	if err != nil {
		return nil, fmt.Errorf("cannot access vault: %w", err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("vault path is not a directory: %s", absRoot)
	}

	excluded := make(map[string]bool)
	for k, v := range DefaultExcludedDirs {
		excluded[k] = v
	}

	return &Scanner{
		VaultRoot:    filepath.Clean(absRoot),
		ExcludedDirs: excluded,
		Warnings:     make([]string, 0),
	}, nil
}

// Scan discovers all eligible Markdown notes relative to the vault root.
// It returns sorted vault-relative paths and any warnings encountered.
func (s *Scanner) Scan() ([]string, error) {
	s.Warnings = make([]string, 0)
	var discovered []string
	visitedDirs := make(map[string]bool)

	// Register canonical vault root
	canonicalRoot, err := filepath.EvalSymlinks(s.VaultRoot)
	if err != nil {
		canonicalRoot = s.VaultRoot
	}
	visitedDirs[canonicalRoot] = true

	err = filepath.WalkDir(s.VaultRoot, func(currentPath string, entry fs.DirEntry, err error) error {
		if err != nil {
			s.Warnings = append(s.Warnings, fmt.Sprintf("cannot read path %s: %v", currentPath, err))
			return nil // continue walking other entries
		}

		name := entry.Name()

		// Check directory exclusion
		if entry.IsDir() {
			if currentPath != s.VaultRoot {
				// Exclude hidden directories (starting with '.') or explicitly excluded dirs
				if strings.HasPrefix(name, ".") || s.ExcludedDirs[name] {
					return filepath.SkipDir
				}
			}
			return nil
		}

		// Handle symlinks
		if entry.Type()&os.ModeSymlink != 0 {
			resolvedTarget, err := filepath.EvalSymlinks(currentPath)
			if err != nil {
				s.Warnings = append(s.Warnings, fmt.Sprintf("cannot resolve symlink %s: %v", currentPath, err))
				return nil
			}

			// Ensure symlink target is inside vault
			relToVault, err := filepath.Rel(canonicalRoot, resolvedTarget)
			if err != nil || strings.HasPrefix(relToVault, "..") {
				s.Warnings = append(s.Warnings, fmt.Sprintf("skipping unsafe symlink pointing outside vault: %s -> %s", currentPath, resolvedTarget))
				return nil
			}

			targetInfo, err := os.Stat(resolvedTarget)
			if err != nil {
				s.Warnings = append(s.Warnings, fmt.Sprintf("cannot stat symlink target %s: %v", resolvedTarget, err))
				return nil
			}

			if targetInfo.IsDir() {
				if visitedDirs[resolvedTarget] {
					// Prevent circular symlinks
					return nil
				}
				visitedDirs[resolvedTarget] = true
				// Walk symlinked directory
				subScanner := &Scanner{
					VaultRoot:    resolvedTarget,
					ExcludedDirs: s.ExcludedDirs,
				}
				subNotes, _ := subScanner.Scan()
				for _, subNote := range subNotes {
					relPath, err := filepath.Rel(s.VaultRoot, filepath.Join(resolvedTarget, subNote))
					if err == nil && !strings.HasPrefix(relPath, "..") {
						discovered = append(discovered, filepath.ToSlash(relPath))
					}
				}
				return nil
			}

			// Symlinked file
			if !isMarkdownFile(resolvedTarget) {
				return nil
			}
		}

		// Check if file is markdown
		if !isMarkdownFile(name) {
			return nil
		}

		// Exclude hidden markdown files
		if strings.HasPrefix(name, ".") {
			return nil
		}

		relPath, err := filepath.Rel(s.VaultRoot, currentPath)
		if err != nil {
			s.Warnings = append(s.Warnings, fmt.Sprintf("failed to get relative path for %s: %v", currentPath, err))
			return nil
		}

		cleanRel := filepath.Clean(relPath)
		if strings.HasPrefix(cleanRel, "..") {
			s.Warnings = append(s.Warnings, fmt.Sprintf("path traversal detected for %s", currentPath))
			return nil
		}

		discovered = append(discovered, filepath.ToSlash(cleanRel))
		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("failed to scan vault: %w", err)
	}

	sort.Strings(discovered)
	return discovered, nil
}

func isMarkdownFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	return ext == ".md" || ext == ".markdown"
}
