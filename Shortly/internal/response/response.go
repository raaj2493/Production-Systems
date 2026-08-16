package response

import (
	"github.com/gin-gonic/gin"
)

// Response defines the standard JSON wrapper structure
type Response struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   interface{} `json:"error,omitempty"`
}

// JSON sends a custom standardized JSON response
func JSON(c *gin.Context, statusCode int, success bool, data interface{}, err interface{}) {
	c.JSON(statusCode, Response{
		Success: success,
		Data:    data,
		Error:   err,
	})
}

// Success sends an HTTP success response with a payload
func Success(c *gin.Context, statusCode int, data interface{}) {
	JSON(c, statusCode, true, data, nil)
}

// Error sends an HTTP error response with an error payload
func Error(c *gin.Context, statusCode int, err interface{}) {
	JSON(c, statusCode, false, nil, err)
}