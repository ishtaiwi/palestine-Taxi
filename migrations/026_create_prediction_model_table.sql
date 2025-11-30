-- Migration: Create prediction_model table for AI model persistence
-- Date: 2025-01-XX
-- Description: Stores serialized AI prediction model state to survive server restarts

CREATE TABLE IF NOT EXISTS public.prediction_model (
  modelid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lineid uuid NOT NULL REFERENCES public.line(lineid) ON DELETE CASCADE,
  model_data jsonb NOT NULL,
  last_trained_at timestamptz,
  training_range_start timestamptz,
  training_range_end timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT prediction_model_lineid_unique UNIQUE (lineid)
);

-- Index for fast lookups by lineid
CREATE INDEX IF NOT EXISTS idx_prediction_model_lineid ON public.prediction_model(lineid);

-- Index for finding recently trained models
CREATE INDEX IF NOT EXISTS idx_prediction_model_last_trained_at ON public.prediction_model(last_trained_at DESC);

-- Add comments
COMMENT ON TABLE public.prediction_model IS 'Stores serialized AI prediction model state for each line';
COMMENT ON COLUMN public.prediction_model.model_data IS 'JSONB containing serialized buckets (Map) and stats for the prediction model';
COMMENT ON COLUMN public.prediction_model.last_trained_at IS 'Timestamp when model was last trained';
COMMENT ON COLUMN public.prediction_model.training_range_start IS 'Start date of data used for last training';
COMMENT ON COLUMN public.prediction_model.training_range_end IS 'End date of data used for last training';

