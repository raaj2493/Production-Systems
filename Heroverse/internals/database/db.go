package database

import (
	"fmt"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"github.com/raaj2493/production-systems/heroverse/internals/config"
)

func Connect(cfg *config.DatabaseConfig)(*gorm.DB , error ){

	// 1. Open GORM database connection
	db, err := gorm.Open(postgres.Open(cfg.DSN()), &gorm.Config{
		TranslateError: true,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	// 2. Retrieve underlying *sql.DB instance for pool configuration
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get underlying sql.DB instance: %w", err)
	}

	// 3. Configure connection pool settings
	sqlDB.SetMaxOpenConns(25)                 // Max open connections
	sqlDB.SetMaxIdleConns(10)                 // Max idle connections retained
	sqlDB.SetConnMaxLifetime(15 * time.Minute) // Connection max lifetime

	// 4. Verify network/database connectivity
	if err := sqlDB.Ping(); err != nil {
		return nil, fmt.Errorf("database ping failed: %w", err)
	}

	return db, nil
}

// Migrate automatically migrates the provided GORM models into PostgreSQL tables.
func Migrate(db *gorm.DB, models ...any) error {
	if err := db.AutoMigrate(models...); err != nil {
		return fmt.Errorf("failed to auto-migrate database schema: %w", err)
	}
	return nil
}