package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jonmanahan/url-shortener/internal/interfaces"
	"github.com/jonmanahan/url-shortener/internal/models"
)

type Handlers struct {
	urlService interfaces.URLService
}

func New(urlService interfaces.URLService) *Handlers {
	return &Handlers{
		urlService: urlService,
	}
}

func (h *Handlers) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "healthy",
		"service": "url-shortener",
	})
}

func (h *Handlers) Shorten(c *gin.Context) {
	var req models.ShortenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request format",
		})
		return
	}

	// Check rate limit
	clientIP := c.ClientIP()
	allowed, err := h.urlService.CheckRateLimit(c.Request.Context(), clientIP)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Internal server error",
		})
		return
	}
	if !allowed {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"error": "Rate limit exceeded",
		})
		return
	}

	// Shorten the URL
	response, err := h.urlService.ShortenURL(c.Request.Context(), req.URL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to shorten URL",
		})
		return
	}

	c.JSON(http.StatusCreated, response)
}

func (h *Handlers) Resolve(c *gin.Context) {
	shortCode := c.Param("shortCode")
	if shortCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Short code is required",
		})
		return
	}

	// Resolve the URL
	originalURL, err := h.urlService.ResolveURL(c.Request.Context(), shortCode)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Short code not found",
		})
		return
	}

	// Redirect to original URL
	c.Redirect(http.StatusMovedPermanently, originalURL)
}
