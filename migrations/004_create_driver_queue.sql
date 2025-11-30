-- Migration: Create driver_queue table for driver turn management
-- Date: 2025-11-20

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS driver_queue (
  queueid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driverid uuid NOT NULL REFERENCES driver(driverid) ON DELETE CASCADE,
  lineid uuid NOT NULL REFERENCES line(lineid) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'waiting',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_driver_queue_line_status
  ON driver_queue (lineid, status, joined_at);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_driver_queue_active
  ON driver_queue (driverid)
  WHERE status = 'waiting';

