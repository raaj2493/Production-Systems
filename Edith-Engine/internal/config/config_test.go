package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestExpandHome(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatalf("failed to get home dir: %v", err)
	}

	tests := []struct {
		input    string
		expected string
	}{
		{"~", home},
		{"~/test", filepath.Join(home, "test")},
		{"/absolute/path", "/absolute/path"},
		{"relative/path", "relative/path"},
	}

	for _, tc := range tests {
		got, err := ExpandHome(tc.input)
		if err != nil {
			t.Fatalf("ExpandHome(%q) returned error: %v", tc.input, err)
		}
		if got != tc.expected {
			t.Errorf("ExpandHome(%q) = %q; want %q", tc.input, got, tc.expected)
		}
	}

	_, err = ExpandHome("")
	if err == nil {
		t.Errorf("expected error for empty path")
	}
}

func TestConfigValidation(t *testing.T) {
	tempDir := t.TempDir()
	vaultDir := filepath.Join(tempDir, "vault")
	if err := os.Mkdir(vaultDir, 0755); err != nil {
		t.Fatalf("failed to create temp vault: %v", err)
	}

	dbDir := filepath.Join(tempDir, "db")
	dbPath := filepath.Join(dbDir, "test.db")

	cfg := &Config{
		VaultPath: vaultDir,
		DBPath:    dbPath,
	}

	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected valid config, got error: %v", err)
	}

	// Test: DB inside vault should fail
	cfgInside := &Config{
		VaultPath: vaultDir,
		DBPath:    filepath.Join(vaultDir, "sub", "test.db"),
	}
	if err := cfgInside.Validate(); err == nil {
		t.Errorf("expected validation failure when DB is inside vault, got nil")
	}

	// Test: non-existent vault should fail
	cfgNonExistent := &Config{
		VaultPath: filepath.Join(tempDir, "does-not-exist"),
		DBPath:    dbPath,
	}
	if err := cfgNonExistent.Validate(); err == nil {
		t.Errorf("expected validation failure for non-existent vault, got nil")
	}
}
