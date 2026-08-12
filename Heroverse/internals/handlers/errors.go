package handlers

import (
	"errors"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/services"
)

type APIError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func RespondWithError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, services.ErrHeroNotFound):
		c.JSON(http.StatusNotFound, APIError{
			Code:    "HERO_NOT_FOUND",
			Message: "the requested hero was not found",
		})

	case errors.Is(err, services.ErrEmptyName),
		errors.Is(err, services.ErrEmptyPower),
		errors.Is(err, services.ErrInvalidHeroID),
		errors.Is(err, services.ErrNilHeroData),
		errors.Is(err, services.ErrInvalidPage),
		errors.Is(err, services.ErrInvalidLimit),
		errors.Is(err, services.ErrInvalidSortBy),
		errors.Is(err, services.ErrInvalidOrder):
		c.JSON(http.StatusBadRequest, APIError{
			Code:    "INVALID_INPUT",
			Message: err.Error(),
		})

	default:
		log.Printf("[ERROR] Internal failure: %v", err)
		c.JSON(http.StatusInternalServerError, APIError{
			Code:    "INTERNAL_ERROR",
			Message: "an unexpected internal error occurred",
		})
	}
}