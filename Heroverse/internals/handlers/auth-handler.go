package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/services"
)

type AuthHandler struct {
	authService *services.AuthService
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

// Helper struct for binding incoming Auth JSON payloads
type authPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var body authPayload
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, APIError{
			Code:    "INVALID_INPUT",
			Message: "invalid request body",
		})
		return
	}

	user, err := h.authService.Create(c.Request.Context(), body.Email, body.Password)
	if err != nil {
		if errors.Is(err, services.ErrInvalidEmail) ||
			errors.Is(err, services.ErrWeakPassword) ||
			errors.Is(err, services.ErrEmailAlreadyExists) {
			c.JSON(http.StatusBadRequest, APIError{
				Code:    "INVALID_INPUT",
				Message: err.Error(),
			})
			return
		}
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusCreated, user)
}

func (h *AuthHandler) Login(c *gin.Context) {
	var body authPayload
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, APIError{
			Code:    "INVALID_INPUT",
			Message: "invalid request body",
		})
		return
	}

	token, user, err := h.authService.Login(c.Request.Context(), body.Email, body.Password)
	if err != nil {
		if errors.Is(err, services.ErrInvalidCredentials) {
			c.JSON(http.StatusUnauthorized, APIError{
				Code:    "UNAUTHORIZED",
				Message: services.ErrInvalidCredentials.Error(),
			})
			return
		}
		RespondWithError(c, err)
		return
	}

	// Return token and user info directly
	RespondWithData(c, http.StatusOK, gin.H{
		"token": token,
		"user":  user,
	})
}