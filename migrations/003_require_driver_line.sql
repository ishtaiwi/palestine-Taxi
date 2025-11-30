-- Ensure each driver references a valid line
ALTER TABLE driver
ADD COLUMN IF NOT EXISTS lineid uuid;

ALTER TABLE driver
DROP CONSTRAINT IF EXISTS driver_lineid_fkey;

ALTER TABLE driver
ADD CONSTRAINT driver_lineid_fkey
FOREIGN KEY (lineid) REFERENCES line(lineid)
ON UPDATE CASCADE
ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_driver_lineid ON driver(lineid);

