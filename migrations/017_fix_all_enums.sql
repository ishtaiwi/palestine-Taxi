-- Migration: Fix all enum types to match code constants
-- Date: 2025-01-XX
-- Description: Ensures all enum types in database match the constants used in the code

-- =====================================================
-- 1. payment_status enum
-- =====================================================
DO $$
DECLARE
    enum_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'payment_status'
    ) INTO enum_exists;
    
    IF NOT enum_exists THEN
        CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
        RAISE NOTICE 'Created payment_status enum';
    ELSE
        -- Add missing values
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'completed' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')) THEN
            ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'completed';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'failed' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')) THEN
            ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'failed';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'refunded' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')) THEN
            ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunded';
        END IF;
        RAISE NOTICE 'payment_status enum verified';
    END IF;
END $$;

-- =====================================================
-- 2. reservation_status enum
-- =====================================================
DO $$
DECLARE
    enum_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'reservation_status'
    ) INTO enum_exists;
    
    IF NOT enum_exists THEN
        CREATE TYPE reservation_status AS ENUM ('pending', 'confirmed', 'checked_in', 'cancelled', 'no_show', 'standby');
        RAISE NOTICE 'Created reservation_status enum';
    ELSE
        -- Add missing values
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'confirmed' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reservation_status')) THEN
            ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'confirmed';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'checked_in' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reservation_status')) THEN
            ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'checked_in';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'cancelled' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reservation_status')) THEN
            ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'cancelled';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'no_show' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reservation_status')) THEN
            ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'no_show';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'standby' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reservation_status')) THEN
            ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'standby';
        END IF;
        RAISE NOTICE 'reservation_status enum verified';
    END IF;
END $$;

-- =====================================================
-- 3. driver_status enum
-- =====================================================
DO $$
DECLARE
    enum_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'driver_status'
    ) INTO enum_exists;
    
    IF NOT enum_exists THEN
        CREATE TYPE driver_status AS ENUM ('active', 'inactive', 'suspended');
        RAISE NOTICE 'Created driver_status enum';
    ELSE
        -- Add missing values
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'inactive' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'driver_status')) THEN
            ALTER TYPE driver_status ADD VALUE IF NOT EXISTS 'inactive';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'suspended' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'driver_status')) THEN
            ALTER TYPE driver_status ADD VALUE IF NOT EXISTS 'suspended';
        END IF;
        RAISE NOTICE 'driver_status enum verified';
    END IF;
END $$;

-- =====================================================
-- 4. vehicle_status enum
-- =====================================================
DO $$
DECLARE
    enum_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'vehicle_status'
    ) INTO enum_exists;
    
    IF NOT enum_exists THEN
        CREATE TYPE vehicle_status AS ENUM ('active', 'inactive', 'maintenance');
        RAISE NOTICE 'Created vehicle_status enum';
    ELSE
        -- Add missing values
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'inactive' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'vehicle_status')) THEN
            ALTER TYPE vehicle_status ADD VALUE IF NOT EXISTS 'inactive';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'maintenance' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'vehicle_status')) THEN
            ALTER TYPE vehicle_status ADD VALUE IF NOT EXISTS 'maintenance';
        END IF;
        RAISE NOTICE 'vehicle_status enum verified';
    END IF;
END $$;

-- =====================================================
-- 5. user role enum (user_role)
-- =====================================================
DO $$
DECLARE
    enum_exists boolean;
    enum_type_name text;
BEGIN
    -- Check if role enum exists with different names
    SELECT typname INTO enum_type_name
    FROM pg_type 
    WHERE typname IN ('user_role', 'role', 'user_role_enum')
    LIMIT 1;
    
    IF enum_type_name IS NULL THEN
        -- Create new enum
        CREATE TYPE user_role AS ENUM ('admin', 'driver', 'passenger');
        RAISE NOTICE 'Created user_role enum';
    ELSE
        -- Enum exists, verify values
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'admin' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = enum_type_name)) THEN
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'admin';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'driver' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = enum_type_name)) THEN
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'driver';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'passenger' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = enum_type_name)) THEN
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'passenger';
        END IF;
        RAISE NOTICE 'user_role enum verified (found as: %)', enum_type_name;
    END IF;
END $$;

-- =====================================================
-- 6. payment_method enum
-- =====================================================
DO $$
DECLARE
    enum_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'payment_method'
    ) INTO enum_exists;
    
    IF NOT enum_exists THEN
        CREATE TYPE payment_method AS ENUM ('wallet', 'cash', 'card', 'palpay', 'jawwal_pay');
        RAISE NOTICE 'Created payment_method enum';
    ELSE
        -- Add missing values
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'wallet' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')) THEN
            ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'wallet';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'cash' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')) THEN
            ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'cash';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'card' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')) THEN
            ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'card';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'palpay' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')) THEN
            ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'palpay';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'jawwal_pay' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')) THEN
            ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'jawwal_pay';
        END IF;
        RAISE NOTICE 'payment_method enum verified';
    END IF;
END $$;

-- =====================================================
-- Add comments to enum types
-- =====================================================
COMMENT ON TYPE payment_status IS 'Payment status: pending, completed, failed, refunded';
COMMENT ON TYPE reservation_status IS 'Reservation status: pending, confirmed, checked_in, cancelled, no_show, standby';
COMMENT ON TYPE driver_status IS 'Driver status: active, inactive, suspended';
COMMENT ON TYPE vehicle_status IS 'Vehicle status: active, inactive, maintenance';
COMMENT ON TYPE user_role IS 'User role: admin, driver, passenger';
COMMENT ON TYPE payment_method IS 'Payment method: wallet, cash, card, palpay, jawwal_pay';

-- =====================================================
-- Verification: Show all enum values
-- =====================================================
SELECT 
    t.typname AS enum_name,
    array_agg(e.enumlabel ORDER BY e.enumsortorder) AS enum_values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname IN ('payment_status', 'reservation_status', 'driver_status', 'vehicle_status', 'user_role', 'payment_method')
GROUP BY t.typname
ORDER BY t.typname;

