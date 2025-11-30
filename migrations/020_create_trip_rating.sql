-- Migration: Create trip rating table
-- Date: 2025-01-XX
-- Description: Allows passengers to rate their completed trips

-- ============================================
-- 1. CREATE rating TABLE
-- ============================================
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

-- ============================================
-- 2. CREATE INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_trip_rating_bookingid 
    ON public.trip_rating(bookingid);

CREATE INDEX IF NOT EXISTS idx_trip_rating_tripid 
    ON public.trip_rating(tripid);

CREATE INDEX IF NOT EXISTS idx_trip_rating_passengerid 
    ON public.trip_rating(passengerid);

CREATE INDEX IF NOT EXISTS idx_trip_rating_created_at 
    ON public.trip_rating(created_at DESC);

-- ============================================
-- 3. ADD COMMENTS
-- ============================================
COMMENT ON TABLE public.trip_rating IS 'Passenger ratings for completed trips';
COMMENT ON COLUMN public.trip_rating.ratingid IS 'Unique identifier for the rating';
COMMENT ON COLUMN public.trip_rating.bookingid IS 'Reservation ID that this rating is for';
COMMENT ON COLUMN public.trip_rating.passengerid IS 'Passenger who submitted the rating';
COMMENT ON COLUMN public.trip_rating.tripid IS 'Trip that was rated';
COMMENT ON COLUMN public.trip_rating.rating IS 'Rating value from 1 to 5 stars';
COMMENT ON COLUMN public.trip_rating.comment IS 'Optional comment/feedback text';
COMMENT ON COLUMN public.trip_rating.created_at IS 'Timestamp when rating was submitted';

-- ============================================
-- 4. VERIFICATION
-- ============================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'trip_rating'
    ) THEN
        RAISE NOTICE '✅ trip_rating table created successfully';
    ELSE
        RAISE WARNING '⚠️ trip_rating table creation may have failed';
    END IF;
END $$;

