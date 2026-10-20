package main

import (
	"net/http"
	"github.com/gin-gonic/gin"
)

func main(){
	router := gin.Default()

	type Request struct {
		Name  string `json:"name"`
		Power int    `json:"power"`
	}

	router.GET("/heros", func(ctx *gin.Context) {
		var req Request

		if err := ctx.ShouldBindJSON(&req);
		err != nil{
			ctx.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid JSON payload",
			})
			return
		}

		// Conditional validation for required fields
		if req.Name == "" || req.Power <= 0 {
			ctx.JSON(http.StatusBadRequest, gin.H{
				"error": "Validation failed: 'name' must not be empty and 'power' must be greater than 0",
			})
			return
		}

		// Request is valid
		ctx.JSON(http.StatusCreated, gin.H{
			"message": "Hero created successfully",
			"data":    req,
		})
	})

	router.GET("/", func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, gin.H{
			"message" : "welcome to herovers",
		})
	})

	router.GET("/health", func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, gin.H{
			"status" : "ok",
		})
	})

	router.Run(":8080")
}