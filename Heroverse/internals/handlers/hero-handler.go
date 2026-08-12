package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
	"github.com/raaj2493/production-systems/heroverse/internals/services"
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
	var hero models.Hero
	if err := c.ShouldBindJSON(&hero); err != nil {
		RespondWithError(c, services.ErrNilHeroData)
		return
	}

	if err := h.service.Create(c.Request.Context(), &hero); err != nil {
		RespondWithError(c, err)
		return
	}

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
	id, err := strconv.ParseUint(idParam, 10, 64)
	if err != nil || id == 0 {
		RespondWithError(c, services.ErrInvalidHeroID)
		return
	}

	var hero models.Hero
	if err := c.ShouldBindJSON(&hero); err != nil {
		RespondWithError(c, errors.New("invalid JSON body"))
		return
	}

	hero.ID = uint(id)

	if err := h.service.Update(c.Request.Context(), &hero); err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, hero)
}

func (h *HeroHandler) Delete(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 64)
	if err != nil || id == 0 {
		RespondWithError(c, services.ErrInvalidHeroID)
		return
	}

	if err := h.service.Delete(c.Request.Context(), uint(id)); err != nil {
		RespondWithError(c, err)
		return
	}

	RespondWithData(c, http.StatusOK, gin.H{"message": "hero deleted successfully"})
}