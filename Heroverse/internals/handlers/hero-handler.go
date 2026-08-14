package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
	"github.com/raaj2493/production-systems/heroverse/internals/services"
	"github.com/raaj2493/production-systems/heroverse/internals/middleware"
)

type HeroHandler struct {
	service *services.HeroService
}

func NewHeroHandler(service *services.HeroService) *HeroHandler {
	return &HeroHandler{
		service: service,
	}
}

func parsePaginationParams(c *gin.Context) (int, int, error) {
	pageStr := c.Query("page")
	limitStr := c.Query("limit")

	page := 1
	limit := 20

	if pageStr != "" {
		parsedPage, err := strconv.Atoi(pageStr)
		if err != nil || parsedPage <= 0 {
			return 0, 0, services.ErrInvalidPage
		}
		page = parsedPage
	}

	if limitStr != "" {
		parsedLimit, err := strconv.Atoi(limitStr)
		if err != nil || parsedLimit <= 0 || parsedLimit > 100 {
			return 0, 0, services.ErrInvalidLimit
		}
		limit = parsedLimit
	}

	return page, limit, nil
}

func (h *HeroHandler) GetAll(c *gin.Context) {
	page, limit, err := parsePaginationParams(c)
	if err != nil {
		RespondWithError(c, err)
		return
	}

	searchQuery := c.Query("search")
	if searchQuery == "" {
		searchQuery = c.Query("q")
	}

	filter := repository.HeroFilter{
		Name:   c.Query("name"),
		Power:  c.Query("power"),
		Search: searchQuery,
		SortBy: c.Query("sort_by"),
		Order:  c.Query("order"),
	}

	heroes, total, err := h.service.GetAll(c.Request.Context(), filter, page, limit)
	if err != nil {
		RespondWithError(c, err)
		return
	}

	if heroes == nil {
		heroes = []models.Hero{}
	}

	totalPages := 0
	if total > 0 {
		totalPages = int((total + int64(limit) - 1) / int64(limit))
	}

	meta := PaginationMeta{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
	}

	RespondWithPagination(c, http.StatusOK, heroes, meta)
}

func (h *HeroHandler) Create(c *gin.Context) {
	// 1. Extract authenticated user ID from Gin context (attached by Authenticate middleware)
	userIDVal, exists := c.Get(middleware.ContextUserIDKey)
	if !exists {
		c.JSON(http.StatusUnauthorized, APIError{
			Code:    "UNAUTHORIZED",
			Message: "user context missing",
		})
		return
	}

	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusUnauthorized, APIError{
			Code:    "UNAUTHORIZED",
			Message: "invalid user context type",
		})
		return
	}

	// 2. Bind JSON request body to the Hero model
	var hero models.Hero
	if err := c.ShouldBindJSON(&hero); err != nil {
		RespondWithError(c, services.ErrNilHeroData)
		return
	}

	// 3. Set the owner ID BEFORE calling the service/database layer
	hero.UserID = userID

	// 4. Save hero to DB (GORM populates ID, CreatedAt, UpdatedAt)
	if err := h.service.Create(c.Request.Context(), &hero); err != nil {
		RespondWithError(c, err)
		return
	}

	// 5. Return created hero with populated ID and timestamps
	RespondWithData(c, http.StatusCreated, hero)
}

func (h *HeroHandler) GetByID(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 64)
	if err != nil || id == 0 {
		RespondWithError(c, services.ErrInvalidHeroID)
		return
	}

	hero, err := h.service.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, hero)
}

func (h *HeroHandler) Update(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, APIError{Code: "INVALID_ID", Message: "invalid hero ID"})
		return
	}

	// 1. Fetch existing hero from DB to check ownership
	existingHero, err := h.service.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		RespondWithError(c, err)
		return
	}

	// 2. Check Ownership or Admin role
	if !h.isOwnerOrAdmin(c, existingHero.UserID) {
		c.JSON(http.StatusForbidden, APIError{
			Code:    "FORBIDDEN",
			Message: "you do not have permission to modify this hero",
		})
		return
	}

	// 3. Bind new fields and update
	var updateData models.Hero
	if err := c.ShouldBindJSON(&updateData); err != nil {
		RespondWithError(c, services.ErrNilHeroData)
		return
	}

	existingHero.Name = updateData.Name
	existingHero.Power = updateData.Power

	if err := h.service.Update(c.Request.Context(), existingHero); err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, existingHero)
}

func (h *HeroHandler) Delete(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 64)
	if err != nil || id == 0 {
		RespondWithError(c, services.ErrInvalidHeroID)
		return
	}

	// 1. Fetch existing hero from DB to check ownership
	existingHero, err := h.service.GetByID(c.Request.Context(), uint(id))
	if err != nil {
		RespondWithError(c, err)
		return
	}

	// 2. Check Ownership or Admin role
	if !h.isOwnerOrAdmin(c, existingHero.UserID) {
		c.JSON(http.StatusForbidden, APIError{
			Code:    "FORBIDDEN",
			Message: "you do not have permission to delete this hero",
		})
		return
	}

	if err := h.service.Delete(c.Request.Context(), uint(id)); err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, gin.H{"message": "hero deleted successfully"})
}



// Helper to verify if the authenticated user owns the resource or is an admin
func (h *HeroHandler) isOwnerOrAdmin(c *gin.Context, ownerUserID uint) bool {
	userIDVal, exists := c.Get(middleware.ContextUserIDKey)
	if !exists {
		return false
	}
	currentUserID, _ := userIDVal.(uint)

	roleVal, _ := c.Get(middleware.ContextUserRole)
	currentUserRole, _ := roleVal.(string)

	// Admin bypass OR exact owner match
	return currentUserRole == string(models.RoleAdmin) || currentUserID == ownerUserID
}