package handlers

import (


	"github.com/gin-gonic/gin"
)

type PaginationMeta struct {
	Page       int   `json:"page"`
	Limit      int   `json:"limit"`
	Total      int64 `json:"total"`
	TotalPages int   `json:"total_pages"`
}

func RespondWithData(c *gin.Context, status int, data any) {
	c.JSON(status, gin.H{
		"data": data,
	})
}

func RespondWithPagination(c *gin.Context, status int, data any, meta PaginationMeta) {
	c.JSON(status, gin.H{
		"data": data,
		"meta": meta,
	})
}