-- Migration: Add name_ar and name_en to line table
-- Date: 2025-01-XX
-- Description: Adds separate Arabic and English name fields for lines

-- Step 1: Add name_ar and name_en columns
ALTER TABLE IF EXISTS public.line
  ADD COLUMN IF NOT EXISTS name_ar CHARACTER VARYING,
  ADD COLUMN IF NOT EXISTS name_en CHARACTER VARYING;

-- Step 2: Migrate existing data from linename to name_ar
-- Copy existing linename to name_ar (assuming existing names are in Arabic)
UPDATE public.line
SET name_ar = linename
WHERE name_ar IS NULL AND linename IS NOT NULL;

-- Step 3: Make name_ar NOT NULL after migration (ensure all rows have name_ar)
DO $$
BEGIN
  -- Check if all rows have name_ar
  IF NOT EXISTS (SELECT 1 FROM public.line WHERE name_ar IS NULL) THEN
    ALTER TABLE public.line
      ALTER COLUMN name_ar SET NOT NULL;
    RAISE NOTICE '✅ name_ar column set to NOT NULL';
  ELSE
    RAISE WARNING '⚠️ Some rows still have NULL name_ar - cannot set NOT NULL';
  END IF;
END $$;

-- Step 4: Add index for name_ar and name_en (for faster searches)
CREATE INDEX IF NOT EXISTS idx_line_name_ar ON public.line(name_ar);
CREATE INDEX IF NOT EXISTS idx_line_name_en ON public.line(name_en);

-- Step 5: Add comments
COMMENT ON COLUMN public.line.name_ar IS 'Arabic name of the line';
COMMENT ON COLUMN public.line.name_en IS 'English name of the line';
COMMENT ON COLUMN public.line.linename IS 'Deprecated: Use name_ar or name_en instead. Kept for backward compatibility.';

-- Step 6: Verification - Show current data
SELECT 
    lineid,
    linename AS old_name,
    name_ar,
    name_en,
    active
FROM public.line
LIMIT 10;

