-- Migration: Make tripid nullable in reservation table
-- Date: 2025-01-XX
-- Description: Allows future bookings to be created without tripid (will be assigned later)

-- Step 1: Drop the NOT NULL constraint on tripid
ALTER TABLE IF EXISTS reservation
  ALTER COLUMN tripid DROP NOT NULL;

-- Step 2: Update foreign key constraint to allow NULL values
-- Note: Foreign key constraints already allow NULL by default in PostgreSQL
-- But we need to ensure the constraint exists and allows NULL

-- Step 3: Add comment explaining the change
COMMENT ON COLUMN reservation.tripid IS 'Trip ID - NULL for future bookings (assigned when trip opens), required for instant bookings';

-- Verification: Check that tripid can now be NULL
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'reservation' 
    AND column_name = 'tripid' 
    AND is_nullable = 'YES'
  ) THEN
    RAISE NOTICE '✅ tripid column is now nullable';
  ELSE
    RAISE WARNING '⚠️ tripid column is still NOT NULL - migration may have failed';
  END IF;
END $$;

