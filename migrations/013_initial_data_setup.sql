-- Migration: Initial Data Setup
-- Date: 2025-01-XX
-- Description: Adds minimum required data to run the system
-- Note: This is the minimum data needed. Users, drivers, passengers, and vehicles are created automatically during registration.

-- ============================================
-- 1. LINES (الخطوط) - REQUIRED
-- ============================================
-- At least one line is required for trips to work
-- You can add more lines as needed

INSERT INTO public.line (lineid, linename, baseprice, additionalprice, estduration, distance, active)
VALUES 
  -- Line 1: Nablus - Beit Iba
  (
    gen_random_uuid(),
    'نابلس - بيت إيبا',
    5.00,  -- Base price
    0.00,  -- Additional price
    30,    -- Estimated duration (minutes)
    15.0,  -- Distance (km)
    true   -- Active
  ),
  -- Line 2: Nablus - Beit Wazan
  (
    gen_random_uuid(),
    'نابلس - بيت وزن',
    6.00,
    0.00,
    35,
    18.0,
    true
  ),
  -- Line 3: Nablus - Asira Al-Shamaliya
  (
    gen_random_uuid(),
    'نابلس - عصيرة الشمالية',
    7.00,
    0.00,
    40,
    20.0,
    true
  )
ON CONFLICT DO NOTHING;

-- ============================================
-- 2. OPTIONAL: Create Admin User (if needed)
-- ============================================
-- Uncomment and modify if you want to create an admin user manually
/*
INSERT INTO public.user (userid, fullname, email, phone, role, password)
VALUES (
  gen_random_uuid(),
  'Admin User',
  'admin@example.com',
  '0599123456',
  'ADMIN',
  '$2b$10$YourHashedPasswordHere' -- Replace with actual hashed password
)
ON CONFLICT (email) DO NOTHING;

-- Then create admin record
INSERT INTO public.admin (id, userid, permissions)
SELECT 
  gen_random_uuid(),
  u.userid,
  ARRAY['all']::text[]
FROM public.user u
WHERE u.email = 'admin@example.com' AND u.role = 'ADMIN'
ON CONFLICT DO NOTHING;
*/

-- ============================================
-- NOTES:
-- ============================================
-- ✅ Lines are REQUIRED - at least one line must exist
-- ✅ Users, Drivers, Passengers are created automatically during registration
-- ✅ Vehicles are created automatically when a driver registers
-- ✅ Wallets are created automatically when a user registers
-- ✅ Trips should be created via API or Admin interface
-- ✅ Reservations are created when passengers book trips
-- ✅ Driver Queue entries are created when drivers join the queue

-- ============================================
-- MINIMUM DATA TO START:
-- ============================================
-- 1. ✅ At least ONE line (added above)
-- 2. ✅ Users will be created via registration
-- 3. ✅ Trips can be created via API after lines exist
-- 4. ✅ Everything else is created automatically

-- ============================================
-- TO TEST THE SYSTEM:
-- ============================================
-- 1. Register a passenger → User + Passenger + Wallet created automatically
-- 2. Register a driver → User + Driver + Vehicle + Wallet created automatically
-- 3. Create a trip (via API or Admin) → Trip created
-- 4. Book a trip → Reservation created
-- 5. Join driver queue → Driver Queue entry created

