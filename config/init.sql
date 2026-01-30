-- PostgreSQL initialization script for production
-- This script runs when the PostgreSQL container starts for the first time

-- Create the production database if it doesn't exist
-- (This is handled by the POSTGRES_DB env var, but keeping for reference)

-- Create any additional extensions needed
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Set up any additional database configurations
ALTER DATABASE goodsongs_api_production SET timezone = 'UTC';