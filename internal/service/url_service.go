package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/jonmanahan/url-shortener/internal/interfaces"
	"github.com/jonmanahan/url-shortener/internal/models"
	"github.com/jonmanahan/url-shortener/internal/repository"
)

type URLService struct {
	repo        interfaces.URLRepository
	redisClient *repository.RedisClient
}

func NewURLService(repo interfaces.URLRepository, redisClient *repository.RedisClient) *URLService {
	return &URLService{
		repo:        repo,
		redisClient: redisClient,
	}
}

func (s *URLService) ShortenURL(ctx context.Context, originalURL string) (*models.ShortenResponse, error) {
	// Generate a unique short code
	shortCode, err := s.generateShortCode()
	if err != nil {
		return nil, fmt.Errorf("failed to generate short code: %w", err)
	}

	// Ensure short code is unique
	for {
		exists, err := s.repo.ShortCodeExists(shortCode)
		if err != nil {
			return nil, fmt.Errorf("failed to check short code uniqueness: %w", err)
		}
		if !exists {
			break
		}
		shortCode, err = s.generateShortCode()
		if err != nil {
			return nil, fmt.Errorf("failed to generate short code: %w", err)
		}
	}

	// Create URL in database
	url, err := s.repo.CreateURL(originalURL, shortCode)
	if err != nil {
		return nil, fmt.Errorf("failed to create URL: %w", err)
	}

	// Cache the short code -> original URL mapping if Redis is available
	if s.redisClient != nil {
		cacheKey := fmt.Sprintf("url:%s", shortCode)
		_ = s.redisClient.Set(ctx, cacheKey, originalURL, 24*time.Hour)
	}

	return &models.ShortenResponse{
		ShortCode:   url.ShortCode,
		OriginalURL: url.OriginalURL,
		ShortURL:    fmt.Sprintf("http://localhost:8080/%s", url.ShortCode),
	}, nil
}

func (s *URLService) ResolveURL(ctx context.Context, shortCode string) (string, error) {
	// Try Redis cache first if available
	if s.redisClient != nil {
		cacheKey := fmt.Sprintf("url:%s", shortCode)
		if originalURL, err := s.redisClient.Get(ctx, cacheKey); err == nil {
			return originalURL, nil
		}
	}

	// Fallback to database
	url, err := s.repo.GetURLByShortCode(shortCode)
	if err != nil {
		return "", fmt.Errorf("failed to resolve URL: %w", err)
	}

	// Update cache if Redis is available
	if s.redisClient != nil {
		cacheKey := fmt.Sprintf("url:%s", shortCode)
		_ = s.redisClient.Set(ctx, cacheKey, url.OriginalURL, 24*time.Hour)
	}

	return url.OriginalURL, nil
}

func (s *URLService) CheckRateLimit(ctx context.Context, clientIP string) (bool, error) {
	if s.redisClient == nil {
		// If no Redis, allow all requests
		return true, nil
	}

	// Rate limit: 10 requests per minute per IP
	key := fmt.Sprintf("rate_limit:%s", clientIP)
	count, err := s.redisClient.IncrementWithExpiry(ctx, key, time.Minute)
	if err != nil {
		// If Redis fails, allow the request
		return true, nil
	}

	return count <= 10, nil
}

func (s *URLService) generateShortCode() (string, error) {
	// Generate 6 random bytes and encode as base64
	bytes := make([]byte, 6)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}

	// Use URL-safe base64 encoding and remove padding
	shortCode := base64.URLEncoding.EncodeToString(bytes)
	shortCode = strings.TrimRight(shortCode, "=")

	// Ensure it's not too long
	if len(shortCode) > 8 {
		shortCode = shortCode[:8]
	}

	return shortCode, nil
}
