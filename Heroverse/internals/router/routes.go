package router

import (
	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/handlers"
	"github.com/raaj2493/production-systems/heroverse/internals/middleware"
)

// SetupRouter initializes Gin, registers global routes, and wires API v1 group endpoints.
func SetupRouter(env string, heroHandler *handlers.HeroHandler, authHandler *handlers.AuthHandler, jwtSecret string) *gin.Engine {
	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()

	// Global Health Check
	r.GET("/health", handlers.HealthHandler())

	// API v1 Router Group
	v1 := r.Group("/api/v1")
	{
		registerAuthRoutes(v1, authHandler)
		registerHeroRoutes(v1, heroHandler, jwtSecret)
	}

	return r
}

// registerAuthRoutes registers public authentication endpoints under /api/v1/auth
func registerAuthRoutes(rg *gin.RouterGroup, authHandler *handlers.AuthHandler) {
	auth := rg.Group("/auth")
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
	}
}

// registerHeroRoutes registers public and protected /api/v1/heroes endpoints
func registerHeroRoutes(rg *gin.RouterGroup, heroHandler *handlers.HeroHandler, jwtSecret string) {
	// 1. Public Read-Only Hero Routes
	rg.GET("/heroes", heroHandler.GetAll)
	rg.GET("/heroes/:id", heroHandler.GetByID)

	// 2. Protected Hero Routes (Authentication Required)
	protected := rg.Group("")
	protected.Use(middleware.Authenticate(jwtSecret))
	{
		protected.POST("/heroes", heroHandler.Create)
		protected.PUT("/heroes/:id", heroHandler.Update)
		protected.DELETE("/heroes/:id", heroHandler.Delete)
	}
}