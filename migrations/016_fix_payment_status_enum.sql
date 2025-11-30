-- Migration: Fix payment_status enum to include all required values
-- Date: 2025-01-XX
-- Description: Ensures payment_status enum contains: pending, completed, failed, refunded

-- First, check if enum exists and get its current values
DO $$
DECLARE
    enum_exists boolean;
    enum_type_name text := 'payment_status';
BEGIN
    -- Check if enum type exists
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = enum_type_name
    ) INTO enum_exists;
    
    IF NOT enum_exists THEN
        -- Create enum if it doesn't exist
        CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
        RAISE NOTICE 'Created payment_status enum';
    ELSE
        -- Enum exists, check if 'completed' value exists
        IF NOT EXISTS (
            SELECT 1 FROM pg_enum 
            WHERE enumlabel = 'completed' 
            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = enum_type_name)
        ) THEN
            -- Add 'completed' value if it doesn't exist
            ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'completed';
            RAISE NOTICE 'Added completed value to payment_status enum';
        END IF;
        
        -- Ensure other values exist
        IF NOT EXISTS (
            SELECT 1 FROM pg_enum 
            WHERE enumlabel = 'failed' 
            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = enum_type_name)
        ) THEN
            ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'failed';
            RAISE NOTICE 'Added failed value to payment_status enum';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM pg_enum 
            WHERE enumlabel = 'refunded' 
            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = enum_type_name)
        ) THEN
            ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunded';
            RAISE NOTICE 'Added refunded value to payment_status enum';
        END IF;
        
        RAISE NOTICE 'payment_status enum verified and updated';
    END IF;
END $$;

-- Add comment to enum type
COMMENT ON TYPE payment_status IS 'Payment status values: pending, completed, failed, refunded';

