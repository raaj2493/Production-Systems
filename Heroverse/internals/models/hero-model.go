package models


import (
	"time"
)

// Hero represents the database schema for superheroes.
type Hero struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Name      string    `gorm:"size:100;not null" json:"name"`
	Power     string    `gorm:"size:255;not null" json:"power"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}