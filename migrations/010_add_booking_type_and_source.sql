-- Migration: Add booking_type field to reservation table
-- Date: 2025-01-XX
-- Description: Adds support for Future/Instant bookings
-- Note: Kiosk uses the same app/API, so no separate source field is needed

-- Add booking_type column
-- Note: Using TEXT to allow 'future' or 'instant' values
ALTER TABLE IF EXISTS reservation
  ADD COLUMN IF NOT EXISTS booking_type TEXT NOT NULL DEFAULT 'instant';
  
-- Add constraint to ensure valid booking_type values
-- Note: Using DO block because ADD CONSTRAINT IF NOT EXISTS is not supported
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_booking_type'
  ) THEN
    ALTER TABLE reservation
      ADD CONSTRAINT check_booking_type 
      CHECK (booking_type IN ('future', 'instant'));
  END IF;
END $$;

-- Add scheduled_trip_time for Future bookings (links to specific trip departure time)
ALTER TABLE IF EXISTS reservation
  ADD COLUMN IF NOT EXISTS scheduled_trip_time TIMESTAMPTZ;

-- Add index for booking_type (for faster filtering)
CREATE INDEX IF NOT EXISTS idx_reservation_booking_type
  ON reservation (booking_type);

-- Add index for scheduled_trip_time (for Future bookings matching)
CREATE INDEX IF NOT EXISTS idx_reservation_scheduled_trip_time
  ON reservation (scheduled_trip_time)
  WHERE scheduled_trip_time IS NOT NULL;

-- Add composite index for matching Future bookings to trips
-- Note: status is USER-DEFINED enum, values: 'pending', 'confirmed', 'checked_in', 'cancelled', 'no_show', 'standby'
CREATE INDEX IF NOT EXISTS idx_reservation_future_matching
  ON reservation (booking_type, scheduled_trip_time, status)
  WHERE booking_type = 'future' AND status IN ('confirmed', 'pending');

-- Add comment to booking_type column
COMMENT ON COLUMN reservation.booking_type IS 'Type of booking: future (scheduled) or instant (next trip)';
COMMENT ON COLUMN reservation.scheduled_trip_time IS 'For future bookings: the scheduled departure time of the trip';

