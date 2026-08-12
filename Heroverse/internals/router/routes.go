package router

import (
	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/handlers"
)

// SetupRouter initializes Gin, registers global routes, and wires API v1 group endpoints.
func SetupRouter(env string, heroHandler *handlers.HeroHandler) *gin.Engine {
	if env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()

	// Global Health Check
	r.GET("/health", handlers.HealthHandler())

	// API v1 Router Group
	v1 := r.Group("/api/v1")
	{
		registerHeroRoutes(v1, heroHandler)
	}

	return r
}

// registerHeroRoutes registers all /api/v1/heroes endpoints
func registerHeroRoutes(rg *gin.RouterGroup, heroHandler *handlers.HeroHandler) {
	heroes := rg.Group("/heroes")
	{
		heroes.GET("", heroHandler.GetAll)
		heroes.GET("/:id", heroHandler.GetByID)
		heroes.POST("", heroHandler.Create)
		heroes.PUT("/:id", heroHandler.Update)
		heroes.DELETE("/:id", heroHandler.Delete)
	}
}