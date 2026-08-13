package repository

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
)


type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepository{
	return UserRepository{
		db : db ,
	}
}

func (r *UserRepository) Create (ctx context.Context , user *models.User) error{
	err := r.db.WithContext(ctx).Create(user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey){
			return errors.New("user with this email already exists")
		}
		return fmt.Errorf("failed to create user: %w", err)
	}
	return nil
}

func(r *UserRepository) GetByID (ctx context.Context , id uint) (*models.User , error){
	var user models.User
	err := r.db.WithContext(ctx).First(&user, id).Error
	 if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("failed to get user by id %d: %w", id, err)
	}
	return &user, nil
}


func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User
	if err := r.db.WithContext(ctx).Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("failed to get user by email %s: %w", email, err)
	}
	return &user, nil
}