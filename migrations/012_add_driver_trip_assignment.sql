-- Migration: Add driver assignment to trips for matching system
-- Date: 2025-01-XX
-- Description: Links trips to drivers from queue for automatic matching

-- Add driver assignment to trip (assigned from queue)
-- Note: Foreign key constraint matches existing driver table structure
ALTER TABLE IF EXISTS trip
  ADD COLUMN IF NOT EXISTS assigned_driverid UUID;
  
-- Add foreign key constraint separately to avoid issues if column already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'trip_assigned_driverid_fkey'
  ) THEN
    ALTER TABLE trip
      ADD CONSTRAINT trip_assigned_driverid_fkey 
      FOREIGN KEY (assigned_driverid) REFERENCES driver(driverid);
  END IF;
END $$;

-- Add assignment_time (when driver was assigned from queue)
-- Note: Using TIMESTAMPTZ for consistency with other timestamp fields
ALTER TABLE IF EXISTS trip
  ADD COLUMN IF NOT EXISTS assignment_time TIMESTAMPTZ;

-- Add index for assigned_driverid
CREATE INDEX IF NOT EXISTS idx_trip_assigned_driver
  ON trip (assigned_driverid, status)
  WHERE assigned_driverid IS NOT NULL;

-- Add comment
COMMENT ON COLUMN trip.assigned_driverid IS 'Driver assigned to this trip from the driver queue';
COMMENT ON COLUMN trip.assignment_time IS 'Timestamp when driver was assigned to this trip';

