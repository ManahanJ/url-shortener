-- V2__add_indexes.sql
CREATE INDEX idx_urls_short_code ON urls(short_code);

-- Add index on created_at for analytics queries
CREATE INDEX idx_urls_created_at ON urls(created_at);

-- Add partial index for frequently accessed URLs (recent ones)
CREATE INDEX idx_urls_recent ON urls(created_at)
    WHERE created_at > (CURRENT_TIMESTAMP - INTERVAL '30 days');