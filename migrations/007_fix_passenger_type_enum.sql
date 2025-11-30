-- Migration: Fix passenger_type enum to include app_based
-- Date: 2025-01-XX
-- This ensures the enum matches the constant value used in the backend (app_based)
-- 
-- Instructions:
-- 1. Copy this entire file
-- 2. Open Supabase Dashboard > SQL Editor
-- 3. Paste and click Run

-- Step 1: Add 'app_based' to the enum if it doesn't exist
DO $$ 
BEGIN
    -- Check if enum type exists
    IF EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'passenger_type'
    ) THEN
        -- Check if 'app_based' value exists in the enum
        IF NOT EXISTS (
            SELECT 1 
            FROM pg_enum 
            WHERE enumlabel = 'app_based' 
            AND enumtypid = (
                SELECT oid 
                FROM pg_type 
                WHERE typname = 'passenger_type'
            )
        ) THEN
            -- Add 'app_based' to the enum
            ALTER TYPE passenger_type ADD VALUE 'app_based';
            RAISE NOTICE 'Added app_based to passenger_type enum';
        ELSE
            RAISE NOTICE 'app_based already exists in passenger_type enum';
        END IF;
    ELSE
        RAISE NOTICE 'passenger_type enum does not exist';
    END IF;
END $$;

-- Step 2: Update any existing passengers with NULL type to app_based
UPDATE passenger 
SET type = 'app_based' 
WHERE type IS NULL;

-- Step 3: Set default value for type column
ALTER TABLE IF EXISTS passenger 
ALTER COLUMN type SET DEFAULT 'app_based';

-- Step 4: Make type column NOT NULL (only if all rows have values)
-- First ensure all rows have app_based, then make it NOT NULL
DO $$ 
BEGIN
    -- Check if there are any NULL values
    IF NOT EXISTS (SELECT 1 FROM passenger WHERE type IS NULL) THEN
        -- All rows have values, safe to make NOT NULL
        ALTER TABLE IF EXISTS passenger 
        ALTER COLUMN type SET NOT NULL;
        RAISE NOTICE 'Set type column to NOT NULL';
    ELSE
        RAISE NOTICE 'Cannot set NOT NULL: some rows still have NULL type';
    END IF;
END $$;

-- Verification: Show current enum values
SELECT 
    enumlabel as passenger_type_values
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'passenger_type')
ORDER BY enumlabel;

