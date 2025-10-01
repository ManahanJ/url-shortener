package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/jonmanahan/url-shortener/internal/config"
	"github.com/jonmanahan/url-shortener/internal/handlers"
	"github.com/jonmanahan/url-shortener/internal/repository"
	"github.com/jonmanahan/url-shortener/internal/service"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Load configuration
	cfg := config.Load()

	// Initialize database
	db, err := repository.NewPostgresDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Initialize Redis (optional - service should work without it)
	var redisClient *repository.RedisClient
	if cfg.RedisURL != "" {
		redisClient = repository.NewRedisClient(cfg.RedisURL)
		defer redisClient.Close()
	}

	// Initialize repository
	urlRepo := repository.NewURLRepository(db)

	// Initialize services
	urlService := service.NewURLService(urlRepo, redisClient)

	// Initialize handlers
	h := handlers.New(urlService)

	// Setup router
	r := gin.Default()

	// Health check
	r.GET("/health", h.Health)

	// URL shortener endpoints
	r.POST("/shorten", h.Shorten)
	r.GET("/:shortCode", h.Resolve)

	// Setup server
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
	}

	// Start server
	go func() {
		log.Printf("Server starting on port %s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Server shutting down...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
