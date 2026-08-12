package services

import (
	"context"
	"errors"
	"fmt"
	"net/mail"
	"strings"

	"github.com/raaj2493/production-systems/heroverse/internals/models"
	"github.com/raaj2493/production-systems/heroverse/internals/repository"
	"github.com/raaj2493/production-systems/heroverse/internals/security"
)

var (
	ErrInvalidEmail       = errors.New("invalid email address format")
	ErrWeakPassword       = errors.New("password must be at least 8 characters long")
	ErrEmailAlreadyExists = errors.New("user with this email already exists")
	ErrInvalidCredentials = errors.New("invalid email or password")
)


type AuthService struct {
	userRepo  repository.UserRepository
	jwtSecret string
}


func NewAuthService (userRepo repository.UserRepository , jwtSecret string)*AuthService{
	return &AuthService{
		userRepo: userRepo,
		jwtSecret: jwtSecret,
	}
}

func(a *AuthService) Create (ctx context.Context , email string , password string)(*models.User , error){
	// 1. Sanitize email
	email = strings.ToLower(strings.TrimSpace(email))

	// 2. Validate inputs directly
	if _, err := mail.ParseAddress(email); err != nil || email == "" {
		return nil, ErrInvalidEmail
	}
	if len(password) < 8 {
		return nil, ErrWeakPassword
	}

	HashedPassword , err := security.HashedPassword(password)
	if err != nil {
		return nil, fmt.Errorf("auth_service: failed to hash password: %w", err)
	}

	// 4. Construct model directly
	user := &models.User{
		Email:        email,
		PasswordHash: HashedPassword,
		Role:         models.RoleUser, // Default role
	}

	// 5. Persist to DB
	if err := a.userRepo.Create(ctx, user); err != nil {
		if errors.Is(err, errors.New("User exist ")) {
			return nil, ErrEmailAlreadyExists
		}
		return nil, fmt.Errorf("auth_service: failed to register user: %w", err)
	}

	return user, nil
}

func(a *AuthService) Login(ctx context.Context , email , password string)(string , *models.User , error){
	email = strings.ToLower(strings.TrimSpace(email))

	if email == "" || password == "" {
		return "", nil, ErrInvalidCredentials
	}

	user , err := a.userRepo.GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, errors.New("user not found")) {
			return "", nil, ErrInvalidCredentials // Prevent user enumeration
		}
		return "", nil, fmt.Errorf("auth_service: failed to fetch user for login: %w", err)
	}

	// 2. Verify password hash
	if !security.CheckPasswordHash(password, user.PasswordHash) {
		return "", nil, ErrInvalidCredentials
	}

	// 3. Generate JWT token
	token, err := security.GenerateJWT(user.ID, string(user.Role), a.jwtSecret)
	if err != nil {
		return "", nil, fmt.Errorf("auth_service: failed to generate token: %w", err)
	}

	return token, user, nil
}
