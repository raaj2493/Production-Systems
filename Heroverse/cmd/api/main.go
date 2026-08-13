package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/raaj2493/production-systems/heroverse/internals/config"
	"github.com/raaj2493/production-systems/heroverse/internals/database"
	"github.com/raaj2493/production-systems/heroverse/internals/handlers"
	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
	"github.com/raaj2493/production-systems/heroverse/internals/router"
	"github.com/raaj2493/production-systems/heroverse/internals/services"
)

func main() {
	// 1. Load Config
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// 2. Connect Database
	db, err := database.Connect(&cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	log.Println("Database connected successfully.")

	// 3. Auto-Migrate Hero Schema
	if err := database.Migrate(db, &models.Hero{}); err != nil {
		log.Fatalf("Failed to auto-migrate database: %v", err)
	}
	log.Println("Database schema auto-migrated successfully.")

	// 4. Dependency Injection
	heroRepo := repository.NewHeroRepository(db)
	heroService := services.NewHeroService(heroRepo)
	heroHandler := handlers.NewHeroHandler(heroService)

	// 5. Initialize Router
	engine := router.SetupRouter(cfg.App.Env, heroHandler, &handlers.AuthHandler{}, cfg.JWT.Secret)

	// 6. Configure & Start HTTP Server
	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Server.Port),
		Handler: engine,
	}

	log.Printf("Starting server on port %d...", cfg.Server.Port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
}