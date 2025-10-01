package models

import "time"

type URL struct {
	ID          int       `json:"id" db:"id"`
	OriginalURL string    `json:"original_url" db:"original_url"`
	ShortCode   string    `json:"short_code" db:"short_code"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type ShortenRequest struct {
	URL string `json:"url" binding:"required,url"`
}

type ShortenResponse struct {
	ShortCode   string `json:"short_code"`
	OriginalURL string `json:"original_url"`
	ShortURL    string `json:"short_url"`
}
