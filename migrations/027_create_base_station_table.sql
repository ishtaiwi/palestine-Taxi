-- Create base_station table for multiple base stations
-- Each base station can be linked to a specific line (optional)
CREATE TABLE IF NOT EXISTS base_station (
    stationid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    geofence_radius_meters INTEGER DEFAULT 100,
    lineid UUID REFERENCES line(lineid) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for filtering by line
CREATE INDEX IF NOT EXISTS idx_base_station_lineid ON base_station(lineid);

-- Index for active stations
CREATE INDEX IF NOT EXISTS idx_base_station_active ON base_station(is_active);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_base_station_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_base_station_updated_at
    BEFORE UPDATE ON base_station
    FOR EACH ROW
    EXECUTE FUNCTION update_base_station_updated_at();

