-- Migration: Fix available seats calculation (exclude driver seat only)
-- Date: 2025-01-XX
-- Description: 
--   1. Updates availableseats to exclude driver seat only (4 for 4+1, 7 for 7+1)
--   2. Broken seats are NOT subtracted - handled in UI only
--   3. Recalculates all trips based on actual reservations
--   4. Ensures schema compatibility

-- ============================================
-- 1. CREATE FUNCTION TO CALCULATE PASSENGER SEATS
-- ============================================
CREATE OR REPLACE FUNCTION calculate_passenger_seats(
    total_seats INTEGER,
    broken_seats INTEGER DEFAULT 0
) RETURNS INTEGER AS $$
BEGIN
    -- Total passenger seats = total seats - 1 (driver seat)
    -- Note: broken seats are NOT subtracted - they are handled separately in the UI
    RETURN GREATEST(0, total_seats - 1);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 2. RECALCULATE AVAILABLE SEATS FOR ALL TRIPS
-- ============================================
-- Updates availableseats based on actual reservations, not totalbookings
DO $$
DECLARE
    trip_record RECORD;
    actual_reservations_count INTEGER;
    passenger_seats INTEGER;
BEGIN
    FOR trip_record IN 
        SELECT 
            t.tripid,
            t.availableseats,
            t.totalbookings,
            v.seatnum,
            COALESCE(array_length(v.broken_seats, 1), 0) as broken_count
        FROM trip t
        INNER JOIN vehicle v ON t.vehicleid = v.vehicleid
    LOOP
        -- Calculate total passenger seats capacity (excluding driver only)
        -- Note: broken seats are not subtracted - they are handled separately in the UI
        passenger_seats := calculate_passenger_seats(trip_record.seatnum, 0);
        
        -- Get actual number of confirmed/checked_in reservations for this trip
        SELECT COUNT(*) INTO actual_reservations_count
        FROM reservation r
        WHERE r.tripid = trip_record.tripid
        AND r.status IN ('confirmed', 'checked_in');
        
        -- Calculate correct available seats
        -- availableseats = passenger_seats - actual_reservations
        UPDATE trip
        SET availableseats = GREATEST(
            passenger_seats - COALESCE(actual_reservations_count, 0),
            0
        )
        WHERE tripid = trip_record.tripid;
        
        -- Log the update for debugging
        RAISE NOTICE 'Trip %: seatnum=%, broken_seats=% (not subtracted), passenger_capacity=%, actual_reservations=%, availableseats=% (was %)', 
            trip_record.tripid, 
            trip_record.seatnum,
            trip_record.broken_count,
            passenger_seats,
            COALESCE(actual_reservations_count, 0),
            GREATEST(passenger_seats - COALESCE(actual_reservations_count, 0), 0),
            trip_record.availableseats;
    END LOOP;
    
    RAISE NOTICE '✅ All trips recalculated successfully';
END $$;

-- ============================================
-- 3. VERIFICATION QUERY
-- ============================================
-- Show sample of updated trips
SELECT 
    t.tripid,
    v.seatnum AS vehicle_total_seats,
    v.seatlayout,
    COALESCE(array_length(v.broken_seats, 1), 0) AS broken_seats_count,
    (v.seatnum - 1) AS expected_passenger_seats,
    t.availableseats AS current_available_seats,
    (SELECT COUNT(*) FROM reservation r WHERE r.tripid = t.tripid AND r.status IN ('confirmed', 'checked_in')) AS actual_reservations,
    t.totalbookings,
    CASE 
        WHEN v.seatnum = 5 THEN 'Should be 4 (if no reservations)'
        WHEN v.seatnum = 8 THEN 'Should be 7 (if no reservations)'
        ELSE 'Check calculation'
    END AS expected_value
FROM trip t
INNER JOIN vehicle v ON t.vehicleid = v.vehicleid
ORDER BY t.deptime DESC
LIMIT 20;

-- ============================================
-- 4. ENSURE SCHEMA COMPATIBILITY
-- ============================================

-- 4.1. Ensure line.name_ar is NOT NULL
DO $$
BEGIN
  -- Check if name_ar exists and is nullable
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'line' 
    AND column_name = 'name_ar'
    AND is_nullable = 'YES'
  ) THEN
    -- Ensure all rows have name_ar (copy from linename if null)
    UPDATE public.line
    SET name_ar = linename
    WHERE name_ar IS NULL AND linename IS NOT NULL;
    
    -- Now set NOT NULL if all rows have values
    IF NOT EXISTS (SELECT 1 FROM public.line WHERE name_ar IS NULL) THEN
      ALTER TABLE public.line
        ALTER COLUMN name_ar SET NOT NULL;
      RAISE NOTICE '✅ name_ar column set to NOT NULL';
    ELSE
      RAISE WARNING '⚠️ Some rows still have NULL name_ar - cannot set NOT NULL';
    END IF;
  ELSE
    RAISE NOTICE '✅ name_ar column already NOT NULL or does not exist';
  END IF;
END $$;

-- 4.2. Ensure line.name_en is nullable
DO $$
BEGIN
  -- Check if name_en exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'line' 
    AND column_name = 'name_en'
  ) THEN
    -- Add name_en if it doesn't exist
    ALTER TABLE public.line
      ADD COLUMN IF NOT EXISTS name_en CHARACTER VARYING;
    RAISE NOTICE '✅ Added name_en column';
  END IF;
  
  -- Ensure it's nullable
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'line' 
    AND column_name = 'name_en'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.line
      ALTER COLUMN name_en DROP NOT NULL;
    RAISE NOTICE '✅ name_en column set to nullable';
  ELSE
    RAISE NOTICE '✅ name_en column is already nullable';
  END IF;
END $$;

-- 4.3. Ensure reservation.tripid is nullable
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'reservation' 
    AND column_name = 'tripid'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.reservation
      ALTER COLUMN tripid DROP NOT NULL;
    RAISE NOTICE '✅ tripid column set to nullable';
  ELSE
    RAISE NOTICE '✅ tripid column is already nullable';
  END IF;
END $$;

-- 4.4. Ensure trip_rating table exists
CREATE TABLE IF NOT EXISTS public.trip_rating (
    ratingid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bookingid UUID NOT NULL,
    passengerid UUID NOT NULL,
    tripid UUID NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Foreign keys
    CONSTRAINT trip_rating_bookingid_fkey 
        FOREIGN KEY (bookingid) REFERENCES public.reservation(bookingid) ON DELETE CASCADE,
    CONSTRAINT trip_rating_passengerid_fkey 
        FOREIGN KEY (passengerid) REFERENCES public.user(userid) ON DELETE CASCADE,
    CONSTRAINT trip_rating_tripid_fkey 
        FOREIGN KEY (tripid) REFERENCES public.trip(tripid) ON DELETE CASCADE,
    
    -- Ensure one rating per booking
    CONSTRAINT trip_rating_bookingid_unique UNIQUE (bookingid)
);

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_trip_rating_bookingid 
    ON public.trip_rating(bookingid);
CREATE INDEX IF NOT EXISTS idx_trip_rating_tripid 
    ON public.trip_rating(tripid);
CREATE INDEX IF NOT EXISTS idx_trip_rating_passengerid 
    ON public.trip_rating(passengerid);
CREATE INDEX IF NOT EXISTS idx_trip_rating_created_at 
    ON public.trip_rating(created_at DESC);

-- Create indexes for line names if they don't exist
CREATE INDEX IF NOT EXISTS idx_line_name_ar ON public.line(name_ar);
CREATE INDEX IF NOT EXISTS idx_line_name_en ON public.line(name_en);

-- ============================================
-- 5. ADD COMMENTS
-- ============================================
COMMENT ON FUNCTION calculate_passenger_seats IS 
'Calculates available passenger seats (total seats - 1 driver seat). Broken seats are handled separately in the UI.';

COMMENT ON COLUMN trip.availableseats IS 
'Available passenger seats (excluding driver seat). For 4+1 vehicle: max 4, for 7+1 vehicle: max 7. Broken seats are NOT subtracted.';

COMMENT ON COLUMN public.line.name_ar IS 'Arabic name of the line';
COMMENT ON COLUMN public.line.name_en IS 'English name of the line';
COMMENT ON COLUMN reservation.tripid IS 'Trip ID - NULL for future bookings (assigned when trip opens), required for instant bookings';

COMMENT ON TABLE public.trip_rating IS 'Passenger ratings for completed trips';

-- ============================================
-- 6. FINAL VERIFICATION
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Migration Complete - Verification';
  RAISE NOTICE '============================================';
  
  -- Check line table
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'line' 
    AND column_name = 'name_ar'
    AND is_nullable = 'NO'
  ) THEN
    RAISE NOTICE '✅ line.name_ar is NOT NULL';
  ELSE
    RAISE WARNING '⚠️ line.name_ar is nullable';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'line' 
    AND column_name = 'name_en'
  ) THEN
    RAISE NOTICE '✅ line.name_en exists';
  ELSE
    RAISE WARNING '⚠️ line.name_en does not exist';
  END IF;
  
  -- Check reservation table
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'reservation' 
    AND column_name = 'tripid'
    AND is_nullable = 'YES'
  ) THEN
    RAISE NOTICE '✅ reservation.tripid is nullable';
  ELSE
    RAISE WARNING '⚠️ reservation.tripid is NOT NULL';
  END IF;
  
  -- Check trip_rating table
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'trip_rating'
  ) THEN
    RAISE NOTICE '✅ trip_rating table exists';
  ELSE
    RAISE WARNING '⚠️ trip_rating table does not exist';
  END IF;
  
  RAISE NOTICE '============================================';
END $$;

