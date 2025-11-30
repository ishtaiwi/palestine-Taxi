-- Migration: Add password column to user table
-- Date: 2025-11-16

-- Add password column to user table
ALTER TABLE "user" 
ADD COLUMN IF NOT EXISTS password VARCHAR(255);

-- Add index on email for faster lookups (if not exists)
CREATE INDEX IF NOT EXISTS idx_user_email ON "user"(email);

-- Add comment to the column
COMMENT ON COLUMN "user".password IS 'Hashed password using bcrypt';

