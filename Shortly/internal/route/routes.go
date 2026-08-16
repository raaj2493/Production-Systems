package router

import (
	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/shortly/internal/handler"
)

// SetupRoutes registers supplied handlers onto the Gin engine
func SetupRoutes(engine *gin.Engine, healthHandler *handler.HealthHandler) {
	api := engine.Group("/api")
	{
		api.GET("/health", healthHandler.Check)
	}
}