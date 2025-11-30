-- Migration: Remove passenger_type column from passenger table
-- Date: 2025-01-XX
-- This removes the type column since all passengers are app users
-- 
-- Instructions:
-- 1. Copy this entire file
-- 2. Open Supabase Dashboard > SQL Editor
-- 3. Paste and click Run

-- Step 1: Drop the type column from passenger table
ALTER TABLE IF EXISTS passenger 
DROP COLUMN IF EXISTS type;

-- Step 2: (Optional) Drop the enum type if it exists and is not used elsewhere
-- Uncomment the following lines if you want to completely remove the enum:
-- DO $$ 
-- BEGIN
--     IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'passenger_type') THEN
--         DROP TYPE passenger_type;
--         RAISE NOTICE 'Dropped passenger_type enum';
--     END IF;
-- END $$;

-- Verification: Check that column is removed
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'passenger' 
AND column_name = 'type';
-- Should return 0 rows if successful

