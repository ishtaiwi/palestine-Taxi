-- Migration: Create password_reset_token table
-- Date: 2025-11-16

CREATE TABLE IF NOT EXISTS password_reset_token (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  userid uuid NOT NULL REFERENCES public."user"(userid) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_token_userid
  ON password_reset_token (userid);

CREATE INDEX IF NOT EXISTS idx_password_reset_token_token
  ON password_reset_token (token);

