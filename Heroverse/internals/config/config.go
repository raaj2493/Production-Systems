package config

import (
	"fmt"
	"log"

	"github.com/caarlos0/env/v11"
	"github.com/joho/godotenv"
)

// AppConfig holds general application-level settings.
type AppConfig struct {
	Env string `env:"APP_ENV" envDefault:"development"`
}

// ServerConfig holds HTTP server network configurations.
type ServerConfig struct {
	Port int `env:"SERVER_PORT" envDefault:"8080"`
}

// DatabaseConfig holds relational database connection parameters.
type DatabaseConfig struct {
	Host     string `env:"DATABASE_HOST" envDefault:"localhost"`
	Port     int    `env:"DATABASE_PORT" envDefault:"5432"`
	User     string `env:"DATABASE_USER" envDefault:"postgres"`
	Password string `env:"DATABASE_PASSWORD"`
	Name     string `env:"DATABASE_NAME" envDefault:"heroverse"`
}

// Config is the root struct aggregating all subsystem configurations.
type Config struct {
	App      AppConfig
	Server   ServerConfig
	Database DatabaseConfig
}

// DSN generates a formatted Data Source Name string required by PostgreSQL drivers.
func (db DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
		db.Host, db.Port, db.User, db.Password, db.Name,
	)
}

// Validate checks for critical missing configuration values before starting the app.
func (c *Config) Validate() error {
	if c.Database.Password == "" && c.App.Env == "production" {
		return fmt.Errorf("DATABASE_PASSWORD cannot be empty in production environment")
	}
	return nil
}

// Load loads environment variables from a .env file and system env into a Config struct.
func Load() (*Config, error) {
	// Step 1: Load .env file if available
	if err := godotenv.Load(); err != nil {
		log.Println("config: no .env file found, using system environment variables")
	}

	// Step 2: Initialize empty Config struct
	var cfg Config

	// Step 3: Parse environment variables into the struct
	if err := env.Parse(&cfg); err != nil {
		return nil, fmt.Errorf("config: failed to parse environment variables: %w", err)
	}

	// Step 4: Validate crucial fields
	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("config: validation failed: %w", err)
	}

	

	// Step 5: Return pointer to configured struct
	return &cfg, nil
}