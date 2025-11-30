-- Migration: Fix vehicle table - convert seatlayout enum to TEXT and make plateno nullable
-- Date: 2025-01-XX
-- This converts seatlayout from enum to TEXT to allow "4+1" and "7+1" values
-- Also makes plateno nullable since it's optional during registration
-- 
-- Instructions:
-- 1. Copy this entire file
-- 2. Open Supabase Dashboard > SQL Editor
-- 3. Paste and click Run

-- Step 1: Make plateno nullable (remove NOT NULL constraint first)
-- This must be done before removing UNIQUE constraint
ALTER TABLE vehicle 
ALTER COLUMN plateno DROP NOT NULL;

-- Step 2: Remove UNIQUE constraint from plateno (if exists)
-- Note: In PostgreSQL, UNIQUE allows multiple NULL values, but we remove it for clarity
DO $$ 
DECLARE
    constraint_name text;
BEGIN
    -- Try to find the unique constraint on plateno
    SELECT conname INTO constraint_name
    FROM pg_constraint 
    WHERE conrelid = 'vehicle'::regclass
    AND contype = 'u'
    AND EXISTS (
        SELECT 1 
        FROM pg_attribute 
        WHERE attrelid = conrelid 
        AND attnum = ANY(conkey) 
        AND attname = 'plateno'
    )
    LIMIT 1;
    
    -- Drop the constraint if found
    IF constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE vehicle DROP CONSTRAINT %I', constraint_name);
        RAISE NOTICE 'Dropped UNIQUE constraint: %', constraint_name;
    ELSE
        RAISE NOTICE 'No UNIQUE constraint found on plateno';
    END IF;
END $$;

-- Step 3: Convert seatlayout column from enum to TEXT
DO $$ 
BEGIN
    -- Check if seatlayout column exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'vehicle' 
        AND column_name = 'seatlayout'
    ) THEN
        -- Convert enum to text by casting
        ALTER TABLE vehicle 
        ALTER COLUMN seatlayout TYPE TEXT USING seatlayout::TEXT;
        
        -- Remove default value (or set new default)
        ALTER TABLE vehicle 
        ALTER COLUMN seatlayout DROP DEFAULT;
        
        -- Set new default to '4+1'
        ALTER TABLE vehicle 
        ALTER COLUMN seatlayout SET DEFAULT '4+1';
        
        RAISE NOTICE 'Converted seatlayout column from enum to TEXT with default 4+1';
    ELSE
        RAISE NOTICE 'seatlayout column does not exist';
    END IF;
END $$;

-- Step 4: (Optional) Drop the enum type if it exists and is not used elsewhere
-- Uncomment the following lines if you want to completely remove the enum:
-- DO $$ 
-- BEGIN
--     IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vehicle_layout') THEN
--         DROP TYPE vehicle_layout;
--         RAISE NOTICE 'Dropped vehicle_layout enum';
--     END IF;
-- END $$;

-- Verification: Check column types
SELECT 
    column_name, 
    data_type,
    udt_name,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vehicle' 
AND column_name IN ('seatlayout', 'plateno')
ORDER BY column_name;
-- seatlayout should show data_type = 'text' with default '4+1'
-- plateno should show is_nullable = 'YES'

