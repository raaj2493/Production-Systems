package config_test

import (
	"os"
	"path/filepath"
	"testing"

	"edith-engine/internal/config"
)

func TestLoadEnvFile(t *testing.T) {
	tempDir := t.TempDir()
	envPath := filepath.Join(tempDir, ".env")

	content := `
# Comment line
GROQ_API_KEY=gsk_test_12345
GROQ_MODEL="llama-3.3-70b-versatile"
EDITH_ADDR='127.0.0.1:9090'
export EDITH_MAX_CONTEXT_BYTES=32768
EMPTY_LINE=

# Another comment
EXISTING_VAR=file_value
`
	if err := os.WriteFile(envPath, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write env file: %v", err)
	}

	// Set an existing var to verify it is NOT overwritten
	_ = os.Setenv("EXISTING_VAR", "original_value")
	defer func() {
		_ = os.Unsetenv("GROQ_API_KEY")
		_ = os.Unsetenv("GROQ_MODEL")
		_ = os.Unsetenv("EDITH_ADDR")
		_ = os.Unsetenv("EDITH_MAX_CONTEXT_BYTES")
		_ = os.Unsetenv("EXISTING_VAR")
	}()

	if err := config.LoadEnvFile(envPath); err != nil {
		t.Fatalf("LoadEnvFile failed: %v", err)
	}

	if val := os.Getenv("GROQ_API_KEY"); val != "gsk_test_12345" {
		t.Errorf("expected gsk_test_12345, got %q", val)
	}
	if val := os.Getenv("GROQ_MODEL"); val != "llama-3.3-70b-versatile" {
		t.Errorf("expected llama-3.3-70b-versatile, got %q", val)
	}
	if val := os.Getenv("EDITH_ADDR"); val != "127.0.0.1:9090" {
		t.Errorf("expected 127.0.0.1:9090, got %q", val)
	}
	if val := os.Getenv("EDITH_MAX_CONTEXT_BYTES"); val != "32768" {
		t.Errorf("expected 32768, got %q", val)
	}
	// Existing var should be preserved
	if val := os.Getenv("EXISTING_VAR"); val != "original_value" {
		t.Errorf("expected existing var preserved as original_value, got %q", val)
	}
}

func TestLoadEnvFile_NonExistent(t *testing.T) {
	// Should gracefully return nil if file does not exist
	err := config.LoadEnvFile("/non/existent/path/.env")
	if err != nil {
		t.Errorf("expected nil for non-existent file, got %v", err)
	}
}
