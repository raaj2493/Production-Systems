package repository

import (
	"context"
	"fmt"
	"strings"

	"gorm.io/gorm"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
)

// HeroFilter encapsulates criteria for filtering, searching, and sorting heroes.
type HeroFilter struct {
	Name   string
	Power  string
	Search string
	SortBy string // Column to sort by: id, name, power, created_at
	Order  string // Order direction: asc, desc
}

type HeroRepository interface {
	Create(ctx context.Context, hero *models.Hero) error
	GetByID(ctx context.Context, id uint) (*models.Hero, error)
	GetAll(ctx context.Context, filter HeroFilter, offset int, limit int) ([]models.Hero, int64, error)
	Update(ctx context.Context, hero *models.Hero) error
	Delete(ctx context.Context, id uint) error
}

type gormHeroRepository struct {
	db *gorm.DB
}

func NewHeroRepository(db *gorm.DB) HeroRepository {
	return &gormHeroRepository{
		db: db,
	}
}

func (r *gormHeroRepository) Create(ctx context.Context, hero *models.Hero) error {
	if err := r.db.WithContext(ctx).Create(hero).Error; err != nil {
		return fmt.Errorf("failed to create hero: %w", err)
	}
	return nil
}

func (r *gormHeroRepository) GetByID(ctx context.Context, id uint) (*models.Hero, error) {
	var hero models.Hero
	if err := r.db.WithContext(ctx).First(&hero, id).Error; err != nil {
		return nil, fmt.Errorf("failed to get hero by id %d: %w", id, err)
	}
	return &hero, nil
}

func (r *gormHeroRepository) GetAll(ctx context.Context, filter HeroFilter, offset int, limit int) ([]models.Hero, int64, error) {
	var heroes []models.Hero
	var total int64

	// Start constructing base query
	query := r.db.WithContext(ctx).Model(&models.Hero{})

	// Field-specific Filter: Name
	if filter.Name != "" {
		query = query.Where("name ILIKE ?", "%"+filter.Name+"%")
	}

	// Field-specific Filter: Power
	if filter.Power != "" {
		query = query.Where("power ILIKE ?", "%"+filter.Power+"%")
	}

	// Global Search: Matches across Name OR Power
	if filter.Search != "" {
		searchTerm := "%" + filter.Search + "%"
		query = query.Where(
			r.db.Where("name ILIKE ?", searchTerm).Or("power ILIKE ?", searchTerm),
		)
	}

	// 1. Count total matching records before applying pagination & sorting
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to count heroes: %w", err)
	}

	// 2. Build deterministic ORDER BY clause
	var orderClause string
	sortBy := strings.ToLower(filter.SortBy)
	orderDir := strings.ToUpper(filter.Order)

	if sortBy == "id" {
		orderClause = fmt.Sprintf("id %s", orderDir)
	} else {
		// Secondary tie-breaker by id ASC for non-ID sorting
		orderClause = fmt.Sprintf("%s %s, id ASC", sortBy, orderDir)
	}

	// 3. Fetch paginated and sorted subset
	if err := query.
		Order(orderClause).
		Limit(limit).
		Offset(offset).
		Find(&heroes).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to fetch heroes: %w", err)
	}

	return heroes, total, nil
}

func (r *gormHeroRepository) Update(ctx context.Context, hero *models.Hero) error {
	if err := r.db.WithContext(ctx).Save(hero).Error; err != nil {
		return fmt.Errorf("failed to update hero %d: %w", hero.ID, err)
	}
	return nil
}

func (r *gormHeroRepository) Delete(ctx context.Context, id uint) error {
	if err := r.db.WithContext(ctx).Delete(&models.Hero{}, id).Error; err != nil {
		return fmt.Errorf("failed to delete hero %d: %w", id, err)
	}
	return nil
}