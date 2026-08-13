package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/security"
)

const (
	ContextUserIDKey = "user_id"
	ContextUserRole  = "user_role"
)

// Authenticate verifies the Bearer JWT token in the Authorization header.
func Authenticate(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 1. Extract Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    "UNAUTHORIZED",
			"message": "authorization header required",
		})
		c.Abort()
		return
	}

	// 2. Parse "Bearer <token>" format
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    "UNAUTHORIZED",
			"message": "invalid authorization header format (must be Bearer <token>)",
		})
		c.Abort()
		return
	}

	tokenString := parts[1]

	// 3. Validate token signature and claims
	claims, err := security.ValidateJWT(tokenString, jwtSecret)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    "UNAUTHORIZED",
			"message": "invalid or expired token",
		})
			c.Abort()
			return
		}

		// 4. Attach extracted identity into Gin context for downstream handlers
		c.Set(ContextUserIDKey, claims.UserID)
		c.Set(ContextUserRole, claims.Role)

		// 5. Allow request to proceed
		c.Next()
	}
}