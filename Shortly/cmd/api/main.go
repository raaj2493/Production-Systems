package main

import (
	"fmt"
	"log"
	"time"
	"net/http"
	"github.com/gin-gonic/gin"
	"github.com/raaj2493/production-systems/shortly/internal/config"
	"github.com/raaj2493/production-systems/shortly/internal/handler"
	"github.com/raaj2493/production-systems/shortly/internal/route"
)

func main(){

	cfg := config.LoadConfig()

	// 2. Set Gin mode
	if cfg.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	engine := gin.Default()


	healthHandler := handler.NewHealthHandler(cfg)

	router.SetupRoutes( engine, healthHandler)

	// Start HTTP server
	srv := &http.Server{
		Addr: fmt.Sprintf(":%s", cfg.Port),
		Handler: engine,
		ReadTimeout: 10 * time.Second,
		WriteTimeout: 10 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	// 7. Start server
	log.Printf("Server starting in [%s] mode on port %s...", cfg.Env, cfg.Port)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Failed to start server: %v", err)
	}

}