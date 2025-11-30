-- Migration: Daily Schedule Templates
-- Date: 2025-01-XX
-- Description: Adds table for daily trip schedules (templates)

-- ============================================
-- 1. CREATE schedule_template TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.schedule_template (
  templateid uuid NOT NULL DEFAULT gen_random_uuid(),
  lineid uuid NOT NULL,
  start_hour integer NOT NULL CHECK (start_hour >= 0 AND start_hour <= 23),
  end_hour integer NOT NULL CHECK (end_hour >= 0 AND end_hour <= 23),
  interval_minutes integer NOT NULL DEFAULT 60 CHECK (interval_minutes > 0),
  active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT schedule_template_pkey PRIMARY KEY (templateid),
  CONSTRAINT schedule_template_lineid_fkey FOREIGN KEY (lineid) REFERENCES public.line(lineid),
  CONSTRAINT schedule_template_hours_check CHECK (end_hour >= start_hour)
);

-- ============================================
-- 2. CREATE INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_schedule_template_lineid ON public.schedule_template(lineid);
CREATE INDEX IF NOT EXISTS idx_schedule_template_active ON public.schedule_template(active);

-- ============================================
-- 3. ADD COMMENTS
-- ============================================
COMMENT ON TABLE public.schedule_template IS 'Daily trip schedule templates - defines when trips should be created automatically';
COMMENT ON COLUMN public.schedule_template.templateid IS 'Unique identifier for the schedule template';
COMMENT ON COLUMN public.schedule_template.lineid IS 'Line this schedule applies to';
COMMENT ON COLUMN public.schedule_template.start_hour IS 'Starting hour (0-23) for daily trips';
COMMENT ON COLUMN public.schedule_template.end_hour IS 'Ending hour (0-23) for daily trips';
COMMENT ON COLUMN public.schedule_template.interval_minutes IS 'Interval between trips in minutes (e.g., 60 for hourly)';
COMMENT ON COLUMN public.schedule_template.active IS 'Whether this schedule is active';

-- ============================================
-- 4. EXAMPLE: Add schedule for Nablus - Beit Iba
-- ============================================
-- This will create trips every hour from 7 AM to 7 PM
-- Uncomment and run after adding lines via migration 013
/*
INSERT INTO public.schedule_template (lineid, start_hour, end_hour, interval_minutes, active)
SELECT 
  lineid,
  7,   -- Start at 7 AM
  19,  -- End at 7 PM (19:00)
  60,  -- Every 60 minutes (hourly)
  true -- Active
FROM public.line
WHERE linename = 'نابلس - بيت إيبا'
LIMIT 1
ON CONFLICT DO NOTHING;
*/

