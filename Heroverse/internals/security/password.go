package security

import (
	"errors"
	"fmt"

	"golang.org/x/crypto/bcrypt"
)


func HashedPassword (password string)(string , error){
	if password == "" {
		return "", errors.New("password cant be empty")
	}

	hashedByte , err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("security: failed to hash password: %w", err)
	}

	return string(hashedByte) , nil
}

func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}