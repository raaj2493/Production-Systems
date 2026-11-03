package config

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// LoadDefaultEnv looks for an .env file in standard locations and loads variables
// into the environment if not already defined:
// 1. ./.env (current working directory)
// 2. ~/.edith/.env
func LoadDefaultEnv() error {
	// 1. Current working directory .env
	if _, err := os.Stat(".env"); err == nil {
		return LoadEnvFile(".env")
	}

	// 2. ~/.edith/.env
	home, err := os.UserHomeDir()
	if err == nil {
		globalEnv := filepath.Join(home, DefaultDBRelDir, ".env")
		if _, err := os.Stat(globalEnv); err == nil {
			return LoadEnvFile(globalEnv)
		}
	}

	return nil
}

// LoadEnvFile parses a given .env file and sets any environment variables
// that are not already present in the current process environment.
func LoadEnvFile(path string) error {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("could not open env file %s: %w", path, err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Support "export KEY=value"
		if strings.HasPrefix(line, "export ") {
			line = strings.TrimSpace(strings.TrimPrefix(line, "export "))
		}

		idx := strings.Index(line, "=")
		if idx == -1 {
			continue
		}

		key := strings.TrimSpace(line[:idx])
		val := strings.TrimSpace(line[idx+1:])

		// Strip surrounding single or double quotes
		if (strings.HasPrefix(val, "\"") && strings.HasSuffix(val, "\"")) ||
			(strings.HasPrefix(val, "'") && strings.HasSuffix(val, "'")) {
			if len(val) >= 2 {
				val = val[1 : len(val)-1]
			}
		}

		// Only set if not already defined in environment (existing env takes precedence)
		if key != "" && os.Getenv(key) == "" {
			_ = os.Setenv(key, val)
		}
	}

	return scanner.Err()
}
