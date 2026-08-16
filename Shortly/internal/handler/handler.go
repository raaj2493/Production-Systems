package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/shortly/internal/config"
	"github.com/raaj2493/production-systems/shortly/internal/response"
)

type HealthHandler struct {
	cfg *config.Config
}

func NewHealthHandler(cfg *config.Config) *HealthHandler {
	return &HealthHandler{cfg: cfg}
}

func (h *HealthHandler) Check(c *gin.Context) {
	healthData := gin.H{
		"status":  "ok",
		"env":     h.cfg.Env,
		"time":    time.Now().Format(time.RFC3339),
		"service": "shortlt",
	}

	response.Success(c, http.StatusOK, healthData)
}