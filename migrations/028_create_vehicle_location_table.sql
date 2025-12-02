-- Create vehicle_location table for real-time GPS tracking
CREATE TABLE IF NOT EXISTS vehicle_location (
    locationid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicleid UUID NOT NULL REFERENCES vehicle(vehicleid) ON DELETE CASCADE,
    driverid UUID NOT NULL REFERENCES driver(driverid) ON DELETE CASCADE,
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    heading NUMERIC(5, 2), -- Compass direction in degrees (0-360)
    speed NUMERIC(6, 2), -- Speed in m/s
    accuracy NUMERIC(6, 2), -- GPS accuracy in meters
    current_stationid UUID REFERENCES base_station(stationid) ON DELETE SET NULL,
    is_at_station BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_vehicle_location_vehicleid ON vehicle_location(vehicleid);
CREATE INDEX IF NOT EXISTS idx_vehicle_location_driverid ON vehicle_location(driverid);
CREATE INDEX IF NOT EXISTS idx_vehicle_location_updated_at ON vehicle_location(updated_at);
CREATE INDEX IF NOT EXISTS idx_vehicle_location_station ON vehicle_location(current_stationid, is_at_station);

-- Unique constraint: one active location per vehicle
CREATE UNIQUE INDEX IF NOT EXISTS idx_vehicle_location_unique_vehicle ON vehicle_location(vehicleid);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_vehicle_location_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_vehicle_location_updated_at
    BEFORE UPDATE ON vehicle_location
    FOR EACH ROW
    EXECUTE FUNCTION update_vehicle_location_updated_at();

-- Enable Supabase Realtime on this table
-- Note: This needs to be enabled in Supabase dashboard under Database > Replication
-- ALTER PUBLICATION supabase_realtime ADD TABLE vehicle_location;

