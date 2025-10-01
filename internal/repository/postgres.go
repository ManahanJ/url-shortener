package repository

import (
	"database/sql"
	"fmt"

	"github.com/jonmanahan/url-shortener/internal/models"
	_ "github.com/lib/pq"
)

type PostgresDB struct {
	db *sql.DB
}

func NewPostgresDB(databaseURL string) (*PostgresDB, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return &PostgresDB{db: db}, nil
}

func (p *PostgresDB) Close() error {
	return p.db.Close()
}

type URLRepository struct {
	db *PostgresDB
}

func NewURLRepository(db *PostgresDB) *URLRepository {
	return &URLRepository{db: db}
}

func (r *URLRepository) CreateURL(originalURL, shortCode string) (*models.URL, error) {
	query := `
		INSERT INTO urls (original_url, short_code, created_at, updated_at)
		VALUES ($1, $2, NOW(), NOW())
		RETURNING id, original_url, short_code, created_at, updated_at`

	url := &models.URL{}
	err := r.db.db.QueryRow(query, originalURL, shortCode).Scan(
		&url.ID,
		&url.OriginalURL,
		&url.ShortCode,
		&url.CreatedAt,
		&url.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create URL: %w", err)
	}

	return url, nil
}

func (r *URLRepository) GetURLByShortCode(shortCode string) (*models.URL, error) {
	query := `SELECT id, original_url, short_code, created_at, updated_at FROM urls WHERE short_code = $1`

	url := &models.URL{}
	err := r.db.db.QueryRow(query, shortCode).Scan(
		&url.ID,
		&url.OriginalURL,
		&url.ShortCode,
		&url.CreatedAt,
		&url.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("URL not found")
		}
		return nil, fmt.Errorf("failed to get URL: %w", err)
	}

	return url, nil
}

func (r *URLRepository) ShortCodeExists(shortCode string) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM urls WHERE short_code = $1)`

	var exists bool
	err := r.db.db.QueryRow(query, shortCode).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check if short code exists: %w", err)
	}

	return exists, nil
}
