-- Migration: Make plateno required (NOT NULL) and unique
-- Date: 2025-01-XX
-- Description: Makes vehicle plate number mandatory and unique to ensure each vehicle has a unique plate
-- This migration is compatible with the schema where plateno is defined as: character varying
-- After running this migration: plateno will be NOT NULL and UNIQUE

-- ============================================
-- 1. UPDATE EXISTING NULL VALUES (if any)
-- ============================================
-- First, update any existing NULL plateno values to a temporary value
-- This is necessary before adding NOT NULL constraint
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_count
    FROM vehicle
    WHERE plateno IS NULL;
    
    IF null_count > 0 THEN
        RAISE WARNING 'Found % vehicles with NULL plateno. These will be set to temporary values.', null_count;
        
        -- Set temporary unique values for NULL plates
        UPDATE vehicle
        SET plateno = 'TEMP-' || vehicleid::text
        WHERE plateno IS NULL;
        
        RAISE NOTICE 'Updated % NULL plateno values to temporary values', null_count;
    ELSE
        RAISE NOTICE 'No NULL plateno values found';
    END IF;
END $$;

-- ============================================
-- 2. REMOVE DUPLICATE PLATENO VALUES (if any)
-- ============================================
-- If there are duplicate plateno values, keep the first one and update others
DO $$
DECLARE
    dup_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO dup_count
    FROM (
        SELECT plateno, COUNT(*) as cnt
        FROM vehicle
        WHERE plateno IS NOT NULL
        GROUP BY plateno
        HAVING COUNT(*) > 1
    ) duplicates;
    
    IF dup_count > 0 THEN
        RAISE WARNING 'Found duplicate plateno values. These will be updated to unique values.';
        
        -- Update duplicates to unique values (keep first, update others)
        UPDATE vehicle v1
        SET plateno = v1.plateno || '-DUP-' || v1.vehicleid::text
        FROM (
            SELECT plateno, vehicleid,
                   ROW_NUMBER() OVER (PARTITION BY plateno ORDER BY vehicleid) as rn
            FROM vehicle
            WHERE plateno IS NOT NULL
        ) ranked
        WHERE v1.vehicleid = ranked.vehicleid
        AND ranked.rn > 1;
        
        RAISE NOTICE 'Updated duplicate plateno values to unique values';
    ELSE
        RAISE NOTICE 'No duplicate plateno values found';
    END IF;
END $$;

-- ============================================
-- 3. ADD NOT NULL CONSTRAINT
-- ============================================
ALTER TABLE vehicle
ALTER COLUMN plateno SET NOT NULL;

-- ============================================
-- 4. ADD UNIQUE CONSTRAINT
-- ============================================
-- Remove existing unique constraint if exists (from migration 009)
DO $$
DECLARE
    constraint_name text;
BEGIN
    -- Find unique constraint on plateno
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
    
    IF constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE vehicle DROP CONSTRAINT IF EXISTS %I', constraint_name);
        RAISE NOTICE 'Dropped existing unique constraint: %', constraint_name;
    END IF;
END $$;

-- Add new UNIQUE constraint
ALTER TABLE vehicle
ADD CONSTRAINT vehicle_plateno_unique UNIQUE (plateno);

-- ============================================
-- 5. ADD INDEX FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_vehicle_plateno
ON vehicle (plateno);

-- ============================================
-- 6. ADD COMMENTS
-- ============================================
COMMENT ON COLUMN vehicle.plateno IS 'Vehicle plate number - REQUIRED and UNIQUE (format: number-4digits-letter, e.g., 3-1234-A)';

-- ============================================
-- 7. VERIFICATION
-- ============================================
DO $$
DECLARE
    is_nullable text;
    has_unique boolean;
BEGIN
    -- Check NOT NULL constraint
    SELECT is_nullable INTO is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'vehicle'
    AND column_name = 'plateno';
    
    IF is_nullable = 'NO' THEN
        RAISE NOTICE '✅ plateno is now NOT NULL';
    ELSE
        RAISE WARNING '⚠️ plateno is still nullable - constraint may have failed';
    END IF;
    
    -- Check UNIQUE constraint
    SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'vehicle'::regclass
        AND conname = 'vehicle_plateno_unique'
        AND contype = 'u'
    ) INTO has_unique;
    
    IF has_unique THEN
        RAISE NOTICE '✅ UNIQUE constraint on plateno is active';
    ELSE
        RAISE WARNING '⚠️ UNIQUE constraint on plateno not found';
    END IF;
END $$;

