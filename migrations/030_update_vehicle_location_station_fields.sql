-- Migration to update vehicle_location table: rename nearest_stationid to current_stationid
-- and is_at_base_station to is_at_station

-- Rename column from nearest_stationid to current_stationid
ALTER TABLE vehicle_location 
  RENAME COLUMN nearest_stationid TO current_stationid;

-- Rename column from is_at_base_station to is_at_station
ALTER TABLE vehicle_location 
  RENAME COLUMN is_at_base_station TO is_at_station;

-- Update index name
DROP INDEX IF EXISTS idx_vehicle_location_station;
CREATE INDEX IF NOT EXISTS idx_vehicle_location_station ON vehicle_location(current_stationid, is_at_station);

