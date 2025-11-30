-- Migration: Add fields for trip opening and automatic departure logic
-- Date: 2025-01-XX
-- Description: Adds support for trip opening time and automatic departure rules

-- Add trip_opening_time (when trip becomes available for bookings, e.g., 45 minutes before)
-- Note: Using TIMESTAMPTZ to match deptime type (timestamp without time zone in schema, but TIMESTAMPTZ is compatible)
ALTER TABLE IF EXISTS trip
  ADD COLUMN IF NOT EXISTS trip_opening_time TIMESTAMPTZ;

-- Add auto_departure_enabled flag
ALTER TABLE IF EXISTS trip
  ADD COLUMN IF NOT EXISTS auto_departure_enabled BOOLEAN NOT NULL DEFAULT true;

-- Add early_departure_allowed flag (depart when full)
ALTER TABLE IF EXISTS trip
  ADD COLUMN IF NOT EXISTS early_departure_allowed BOOLEAN NOT NULL DEFAULT true;

-- Add scheduled_departure_enforced flag (must depart at scheduled time)
ALTER TABLE IF EXISTS trip
  ADD COLUMN IF NOT EXISTS scheduled_departure_enforced BOOLEAN NOT NULL DEFAULT true;

-- Add index for trip_opening_time (for finding trips that should open)
CREATE INDEX IF NOT EXISTS idx_trip_opening_time
  ON trip (trip_opening_time, status)
  WHERE status = 'scheduled';

-- Add comment
COMMENT ON COLUMN trip.trip_opening_time IS 'Time when trip becomes available for bookings (typically 45 minutes before departure)';
COMMENT ON COLUMN trip.auto_departure_enabled IS 'Whether automatic departure logic is enabled for this trip';
COMMENT ON COLUMN trip.early_departure_allowed IS 'Whether trip can depart early when vehicle is full';
COMMENT ON COLUMN trip.scheduled_departure_enforced IS 'Whether trip must depart at scheduled time even if not full';

