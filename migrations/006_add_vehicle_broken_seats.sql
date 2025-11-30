-- Migration: Add broken seats tracking to vehicles
-- Date: 2025-11-20

ALTER TABLE IF EXISTS vehicle
  ADD COLUMN IF NOT EXISTS broken_seats TEXT[] DEFAULT ARRAY[]::TEXT[];

