package services

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"gorm.io/gorm"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
)

var (
	ErrHeroNotFound  = errors.New("hero not found")
	ErrInvalidHeroID = errors.New("hero id must be greater than zero")
	ErrEmptyName     = errors.New("hero name cannot be empty")
	ErrEmptyPower    = errors.New("hero power cannot be empty")
	ErrNilHeroData   = errors.New("hero data cannot be nil")
	ErrInvalidPage   = errors.New("page must be an integer greater than 0")
	ErrInvalidLimit  = errors.New("limit must be an integer between 1 and 100")
	ErrInvalidSortBy = errors.New("invalid sort_by field: allowed fields are id, name, power, created_at")
	ErrInvalidOrder  = errors.New("invalid order direction: allowed values are asc, desc")
)

type HeroService struct {
	repo repository.HeroRepository
}

func NewHeroService(repo repository.HeroRepository) *HeroService {
	return &HeroService{
		repo: repo,
	}
}

// Whitelist map of allowed sort fields
var allowedSortFields = map[string]bool{
	"id":         true,
	"name":       true,
	"power":      true,
	"created_at": true,
}

func (s *HeroService) Create(ctx context.Context, hero *models.Hero) error {
	if hero == nil {
		return ErrNilHeroData
	}

	hero.Name = strings.TrimSpace(hero.Name)
	hero.Power = strings.TrimSpace(hero.Power)

	if hero.Name == "" {
		return ErrEmptyName
	}
	if hero.Power == "" {
		return ErrEmptyPower
	}

	if err := s.repo.Create(ctx, hero); err != nil {
		return fmt.Errorf("service: failed to create hero: %w", err)
	}

	return nil
}

func (s *HeroService) GetByID(ctx context.Context, id uint) (*models.Hero, error) {
	if id == 0 {
		return nil, ErrInvalidHeroID
	}

	hero, err := s.repo.GetByID(ctx, id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrHeroNotFound
		}
		return nil, fmt.Errorf("service: failed to fetch hero: %w", err)
	}

	return hero, nil
}

func (s *HeroService) GetAll(ctx context.Context, filter repository.HeroFilter, page int, limit int) ([]models.Hero, int64, error) {
	filter.Name = strings.TrimSpace(filter.Name)
	filter.Power = strings.TrimSpace(filter.Power)
	filter.Search = strings.TrimSpace(filter.Search)

	// Set default sortBy if empty, otherwise validate against whitelist
	if filter.SortBy == "" {
		filter.SortBy = "id"
	} else {
		filter.SortBy = strings.ToLower(strings.TrimSpace(filter.SortBy))
		if !allowedSortFields[filter.SortBy] {
			return nil, 0, ErrInvalidSortBy
		}
	}

	// Set default order direction if empty, otherwise validate asc/desc
	if filter.Order == "" {
		filter.Order = "asc"
	} else {
		filter.Order = strings.ToLower(strings.TrimSpace(filter.Order))
		if filter.Order != "asc" && filter.Order != "desc" {
			return nil, 0, ErrInvalidOrder
		}
	}

	offset := (page - 1) * limit

	heroes, total, err := s.repo.GetAll(ctx, filter, offset, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("service: failed to list heroes: %w", err)
	}

	return heroes, total, nil
}

func (s *HeroService) Update(ctx context.Context, hero *models.Hero) error {
	if hero == nil {
		return ErrNilHeroData
	}
	if hero.ID == 0 {
		return ErrInvalidHeroID
	}

	hero.Name = strings.TrimSpace(hero.Name)
	hero.Power = strings.TrimSpace(hero.Power)

	if hero.Name == "" {
		return ErrEmptyName
	}
	if hero.Power == "" {
		return ErrEmptyPower
	}

	_, err := s.repo.GetByID(ctx, hero.ID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrHeroNotFound
		}
		return fmt.Errorf("service: hero not found for update: %w", err)
	}

	if err := s.repo.Update(ctx, hero); err != nil {
		return fmt.Errorf("service: failed to update hero: %w", err)
	}

	return nil
}

func (s *HeroService) Delete(ctx context.Context, id uint) error {
	if id == 0 {
		return ErrInvalidHeroID
	}

	_, err := s.repo.GetByID(ctx, id)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrHeroNotFound
		}
		return fmt.Errorf("service: hero not found for deletion: %w", err)
	}

	if err := s.repo.Delete(ctx, id); err != nil {
		return fmt.Errorf("service: failed to delete hero: %w", err)
	}

	return nil
}