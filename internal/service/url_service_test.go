package service

import (
	"context"
	"errors"
	"testing"

	"github.com/jonmanahan/url-shortener/internal/models"
)

// Mock repository for testing
type mockURLRepository struct {
	urls       map[string]*models.URL
	shortCodes map[string]bool
	shouldFail bool
}

func newMockURLRepository() *mockURLRepository {
	return &mockURLRepository{
		urls:       make(map[string]*models.URL),
		shortCodes: make(map[string]bool),
	}
}

func (m *mockURLRepository) CreateURL(originalURL, shortCode string) (*models.URL, error) {
	if m.shouldFail {
		return nil, errors.New("mock error")
	}

	url := &models.URL{
		ID:          1,
		OriginalURL: originalURL,
		ShortCode:   shortCode,
	}
	m.urls[shortCode] = url
	m.shortCodes[shortCode] = true
	return url, nil
}

func (m *mockURLRepository) GetURLByShortCode(shortCode string) (*models.URL, error) {
	if m.shouldFail {
		return nil, errors.New("mock error")
	}

	if url, exists := m.urls[shortCode]; exists {
		return url, nil
	}
	return nil, errors.New("URL not found")
}

func (m *mockURLRepository) ShortCodeExists(shortCode string) (bool, error) {
	if m.shouldFail {
		return false, errors.New("mock error")
	}
	return m.shortCodes[shortCode], nil
}

func TestURLService_ShortenURL(t *testing.T) {
	repo := newMockURLRepository()
	service := NewURLService(repo, nil) // No Redis for basic test

	ctx := context.Background()
	originalURL := "https://example.com"

	response, err := service.ShortenURL(ctx, originalURL)
	if err != nil {
		t.Fatalf("ShortenURL failed: %v", err)
	}

	if response.OriginalURL != originalURL {
		t.Errorf("Expected original URL %s, got %s", originalURL, response.OriginalURL)
	}

	if response.ShortCode == "" {
		t.Error("Expected non-empty short code")
	}

	if len(response.ShortCode) > 10 {
		t.Errorf("Short code too long: %s", response.ShortCode)
	}
}

func TestURLService_ResolveURL(t *testing.T) {
	repo := newMockURLRepository()
	service := NewURLService(repo, nil) // No Redis for basic test

	ctx := context.Background()
	originalURL := "https://example.com"

	// First, create a URL
	response, err := service.ShortenURL(ctx, originalURL)
	if err != nil {
		t.Fatalf("ShortenURL failed: %v", err)
	}

	// Then resolve it
	resolvedURL, err := service.ResolveURL(ctx, response.ShortCode)
	if err != nil {
		t.Fatalf("ResolveURL failed: %v", err)
	}

	if resolvedURL != originalURL {
		t.Errorf("Expected resolved URL %s, got %s", originalURL, resolvedURL)
	}
}

func TestURLService_ResolveURL_NotFound(t *testing.T) {
	repo := newMockURLRepository()
	service := NewURLService(repo, nil)

	ctx := context.Background()

	_, err := service.ResolveURL(ctx, "nonexistent")
	if err == nil {
		t.Error("Expected error for non-existent short code")
	}
}

func TestURLService_generateShortCode(t *testing.T) {
	service := NewURLService(nil, nil)

	shortCode, err := service.generateShortCode()
	if err != nil {
		t.Fatalf("generateShortCode failed: %v", err)
	}

	if shortCode == "" {
		t.Error("Expected non-empty short code")
	}

	if len(shortCode) > 8 {
		t.Errorf("Short code too long: %s", shortCode)
	}

	// Generate multiple codes to check uniqueness
	codes := make(map[string]bool)
	for i := 0; i < 100; i++ {
		code, err := service.generateShortCode()
		if err != nil {
			t.Fatalf("generateShortCode failed on iteration %d: %v", i, err)
		}

		if codes[code] {
			t.Errorf("Duplicate short code generated: %s", code)
		}
		codes[code] = true
	}
}
