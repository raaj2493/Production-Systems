package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	DefaultVaultRelPath = "Documents/Projects/Edith"
	DefaultDBRelDir     = ".edith"
	DefaultDBFileName   = "edith.db"
)

// Config represents runtime configuration for the Edith knowledge engine.
type Config struct {
	VaultPath string
	DBPath    string
	Verbose   bool
	JSON      bool
}

// ExpandHome resolves a leading "~" or "~/" to the user's home directory.
func ExpandHome(path string) (string, error) {
	if path == "" {
		return "", errors.New("path cannot be empty")
	}

	if path == "~" || strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("could not determine user home directory: %w", err)
		}
		if path == "~" {
			return home, nil
		}
		return filepath.Join(home, path[2:]), nil
	}

	return path, nil
}

// DefaultConfig returns the default configuration based on the user's home directory.
func DefaultConfig() (*Config, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("could not resolve home directory: %w", err)
	}

	defaultVault := filepath.Join(home, DefaultVaultRelPath)
	defaultDB := filepath.Join(home, DefaultDBRelDir, DefaultDBFileName)

	return &Config{
		VaultPath: defaultVault,
		DBPath:    defaultDB,
		Verbose:   false,
		JSON:      false,
	}, nil
}

// Validate verifies that paths are valid, resolves them to absolute paths,
// and ensures filesystem safety rules are respected.
func (c *Config) Validate() error {
	if c.VaultPath == "" {
		return errors.New("vault path cannot be empty")
	}
	if c.DBPath == "" {
		return errors.New("database path cannot be empty")
	}

	vaultAbs, err := ExpandHome(c.VaultPath)
	if err != nil {
		return fmt.Errorf("invalid vault path: %w", err)
	}
	vaultAbs, err = filepath.Abs(vaultAbs)
	if err != nil {
		return fmt.Errorf("failed to make vault path absolute: %w", err)
	}
	c.VaultPath = filepath.Clean(vaultAbs)

	dbAbs, err := ExpandHome(c.DBPath)
	if err != nil {
		return fmt.Errorf("invalid database path: %w", err)
	}
	dbAbs, err = filepath.Abs(dbAbs)
	if err != nil {
		return fmt.Errorf("failed to make database path absolute: %w", err)
	}
	c.DBPath = filepath.Clean(dbAbs)

	// Check if vault path exists and is a directory
	info, err := os.Stat(c.VaultPath)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("vault directory does not exist: %s", c.VaultPath)
		}
		return fmt.Errorf("cannot access vault directory: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("vault path is not a directory: %s", c.VaultPath)
	}

	// Safety check: Database should not be located inside the vault directory
	rel, err := filepath.Rel(c.VaultPath, c.DBPath)
	if err == nil && !strings.HasPrefix(rel, "..") && rel != "." {
		return fmt.Errorf("database path (%s) cannot be inside the Obsidian vault (%s)", c.DBPath, c.VaultPath)
	}

	// Ensure parent directory for database exists or can be created
	dbDir := filepath.Dir(c.DBPath)
	if err := os.MkdirAll(dbDir, 0755); err != nil {
		return fmt.Errorf("cannot create database directory %s: %w", dbDir, err)
	}

	return nil
}
