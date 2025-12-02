-- Create line_path table for storing route paths with waypoints and polyline
CREATE TABLE IF NOT EXISTS line_path (
    pathid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lineid UUID NOT NULL UNIQUE REFERENCES line(lineid) ON DELETE CASCADE,
    waypoints JSONB NOT NULL, -- Array of {lat, lng, name?} objects
    polyline TEXT, -- Encoded polyline string for efficient storage
    distance_meters NUMERIC(10, 2), -- Total route distance calculated from waypoints
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for line lookup
CREATE INDEX IF NOT EXISTS idx_line_path_lineid ON line_path(lineid);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_line_path_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_line_path_updated_at
    BEFORE UPDATE ON line_path
    FOR EACH ROW
    EXECUTE FUNCTION update_line_path_updated_at();

