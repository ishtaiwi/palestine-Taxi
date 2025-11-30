-- Migration: Add driver workflow fields to reservation table
-- Date: 2025-11-20

ALTER TABLE IF EXISTS reservation
  ADD COLUMN IF NOT EXISTS driver_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS driver_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_reservation_driver_status
  ON reservation (driver_status);

