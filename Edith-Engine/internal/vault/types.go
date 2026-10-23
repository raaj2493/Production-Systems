package vault

import (
	"time"
)

// NoteMetadata contains the indexed attributes of a note without full content.
type NoteMetadata struct {
	RelPath     string    `json:"rel_path"`
	Title       string    `json:"title"`
	ModTime     time.Time `json:"mod_time"`
	ContentHash string    `json:"content_hash"`
	SizeBytes   int64     `json:"size_bytes"`
}

// Link represents an internal or external reference discovered inside a note.
type Link struct {
	SourcePath    string `json:"source_path"`
	RawTarget     string `json:"raw_target"`
	CleanTarget   string `json:"clean_target"`
	DisplayText   string `json:"display_text"`
	HeadingAnchor string `json:"heading_anchor,omitempty"`
	LineNumber    int    `json:"line_number"`
	IsWikiLink    bool   `json:"is_wikilink"`
	IsExternal    bool   `json:"is_external"`
}

// Note represents a complete Markdown note loaded from the vault.
type Note struct {
	Metadata NoteMetadata `json:"metadata"`
	Content  string       `json:"content"`
	Links    []Link       `json:"links"`
}
