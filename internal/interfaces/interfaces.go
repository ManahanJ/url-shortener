package interfaces

import (
	"context"

	"github.com/jonmanahan/url-shortener/internal/models"
)

// URLRepository interface for URL storage operations
type URLRepository interface {
	CreateURL(originalURL, shortCode string) (*models.URL, error)
	GetURLByShortCode(shortCode string) (*models.URL, error)
	ShortCodeExists(shortCode string) (bool, error)
}

// URLService interface for URL business logic operations
type URLService interface {
	ShortenURL(ctx context.Context, originalURL string) (*models.ShortenResponse, error)
	ResolveURL(ctx context.Context, shortCode string) (string, error)
	CheckRateLimit(ctx context.Context, clientIP string) (bool, error)
}
