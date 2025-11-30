-- Migration: Add templateid to trip table
-- Date: 2025-01-XX
-- Description: Links trips to schedule templates to track which template created each trip

-- ============================================
-- 1. ADD templateid COLUMN TO trip TABLE
-- ============================================
ALTER TABLE IF EXISTS public.trip
  ADD COLUMN IF NOT EXISTS templateid uuid;

-- ============================================
-- 2. ADD FOREIGN KEY CONSTRAINT
-- ============================================
-- Add foreign key constraint separately to avoid issues if column already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'trip_templateid_fkey'
  ) THEN
    ALTER TABLE public.trip
      ADD CONSTRAINT trip_templateid_fkey 
      FOREIGN KEY (templateid) REFERENCES public.schedule_template(templateid);
  END IF;
END $$;

-- ============================================
-- 3. CREATE INDEX
-- ============================================
CREATE INDEX IF NOT EXISTS idx_trip_templateid 
  ON public.trip(templateid)
  WHERE templateid IS NOT NULL;

-- ============================================
-- 4. ADD COMMENT
-- ============================================
COMMENT ON COLUMN public.trip.templateid IS 'Schedule template that created this trip (NULL if created manually)';

