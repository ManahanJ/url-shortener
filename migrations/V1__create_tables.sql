-- V1__create_tables.sql
CREATE TABLE urls (
    id SERIAL PRIMARY KEY,
    original_url TEXT NOT NULL,
    short_code VARCHAR(10) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add check constraint to ensure URLs are not empty
ALTER TABLE urls ADD CONSTRAINT urls_original_url_not_empty
    CHECK (LENGTH(TRIM(original_url)) > 0);

-- Add check constraint for short_code format
ALTER TABLE urls ADD CONSTRAINT urls_short_code_format
    CHECK (short_code ~ '^[a-zA-Z0-9_-]+$');