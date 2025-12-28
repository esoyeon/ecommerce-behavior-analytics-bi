-- Create metabase database for Metabase internal use
CREATE DATABASE metabase;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA staging TO retail;
GRANT ALL PRIVILEGES ON SCHEMA marts TO retail;

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
