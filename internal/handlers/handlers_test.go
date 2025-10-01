package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/jonmanahan/url-shortener/internal/models"
)

// Mock URL service for testing
type mockURLService struct {
	shouldFailShorten   bool
	shouldFailResolve   bool
	shouldFailRateLimit bool
	rateLimitExceeded   bool
}

func (m *mockURLService) ShortenURL(ctx context.Context, originalURL string) (*models.ShortenResponse, error) {
	if m.shouldFailShorten {
		return nil, context.DeadlineExceeded
	}

	return &models.ShortenResponse{
		ShortCode:   "test123",
		OriginalURL: originalURL,
		ShortURL:    "http://localhost:8080/test123",
	}, nil
}

func (m *mockURLService) ResolveURL(ctx context.Context, shortCode string) (string, error) {
	if m.shouldFailResolve {
		return "", context.DeadlineExceeded
	}

	if shortCode == "test123" {
		return "https://example.com", nil
	}

	return "", context.DeadlineExceeded
}

func (m *mockURLService) CheckRateLimit(ctx context.Context, clientIP string) (bool, error) {
	if m.shouldFailRateLimit {
		return false, context.DeadlineExceeded
	}

	return !m.rateLimitExceeded, nil
}

func TestHandlers_Health(t *testing.T) {
	gin.SetMode(gin.TestMode)

	h := New(nil)
	r := gin.New()
	r.GET("/health", h.Health)

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, w.Code)
	}

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	if err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	if response["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got %v", response["status"])
	}
}

func TestHandlers_Shorten_Success(t *testing.T) {
	gin.SetMode(gin.TestMode)

	mockService := &mockURLService{}
	h := New(mockService)
	r := gin.New()
	r.POST("/shorten", h.Shorten)

	reqBody := models.ShortenRequest{
		URL: "https://example.com",
	}
	jsonBody, _ := json.Marshal(reqBody)

	req := httptest.NewRequest("POST", "/shorten", bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("Expected status %d, got %d", http.StatusCreated, w.Code)
	}

	var response models.ShortenResponse
	err := json.Unmarshal(w.Body.Bytes(), &response)
	if err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	if response.ShortCode != "test123" {
		t.Errorf("Expected short code 'test123', got %s", response.ShortCode)
	}
}

func TestHandlers_Shorten_InvalidRequest(t *testing.T) {
	gin.SetMode(gin.TestMode)

	mockService := &mockURLService{}
	h := New(mockService)
	r := gin.New()
	r.POST("/shorten", h.Shorten)

	req := httptest.NewRequest("POST", "/shorten", bytes.NewBufferString("invalid json"))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestHandlers_Shorten_RateLimitExceeded(t *testing.T) {
	gin.SetMode(gin.TestMode)

	mockService := &mockURLService{rateLimitExceeded: true}
	h := New(mockService)
	r := gin.New()
	r.POST("/shorten", h.Shorten)

	reqBody := models.ShortenRequest{
		URL: "https://example.com",
	}
	jsonBody, _ := json.Marshal(reqBody)

	req := httptest.NewRequest("POST", "/shorten", bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("Expected status %d, got %d", http.StatusTooManyRequests, w.Code)
	}
}

func TestHandlers_Resolve_Success(t *testing.T) {
	gin.SetMode(gin.TestMode)

	mockService := &mockURLService{}
	h := New(mockService)
	r := gin.New()
	r.GET("/:shortCode", h.Resolve)

	req := httptest.NewRequest("GET", "/test123", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusMovedPermanently {
		t.Errorf("Expected status %d, got %d", http.StatusMovedPermanently, w.Code)
	}

	location := w.Header().Get("Location")
	if location != "https://example.com" {
		t.Errorf("Expected location 'https://example.com', got %s", location)
	}
}

func TestHandlers_Resolve_NotFound(t *testing.T) {
	gin.SetMode(gin.TestMode)

	mockService := &mockURLService{shouldFailResolve: true}
	h := New(mockService)
	r := gin.New()
	r.GET("/:shortCode", h.Resolve)

	req := httptest.NewRequest("GET", "/nonexistent", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("Expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}
