import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY
);

// POST /api/location/update - Update driver's current location
export const updateDriverLocation = async (req, res) => {
    try {
        // Get driverId from authenticated user (based on your auth pattern)
        const driverId = req.user.driverid; // Adjust based on your auth middleware
        const { vehicleId, latitude, longitude, heading, speed, isOnline } = req.body;

        // Validate required fields
        if (!driverId || latitude === undefined || longitude === undefined) {
            return res.status(400).json({
                error: 'Missing required fields: latitude, longitude'
            });
        }

        // Validate coordinate ranges
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            return res.status(400).json({
                error: 'Invalid coordinates'
            });
        }

        // Insert or update location
        const { data, error } = await supabase
            .from('vehicle_locations')
            .upsert({
                driverid: driverId,
                vehicleid: vehicleId,
                latitude,
                longitude,
                heading: heading || null,
                speed: speed || null,
                is_online: isOnline !== undefined ? isOnline : true,
                timestamp: new Date().toISOString()
            })
            .select()
            .single();

        if (error) {
            console.error('Location update error:', error);
            return res.status(500).json({ error: 'Failed to update location' });
        }

        res.json({
            success: true,
            message: 'Location updated successfully',
            location: data
        });

    } catch (error) {
        console.error('Location update exception:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
};

// GET /api/location/driver/my-location - Get driver's last location
export const getDriverLocation = async (req, res) => {
    try {
        const driverId = req.user.driverid;

        const { data, error } = await supabase
            .from('vehicle_locations')
            .select('*')
            .eq('driverid', driverId)
            .order('timestamp', { ascending: false })
            .limit(1)
            .single();

        if (error) {
            return res.status(500).json({ error: 'Failed to fetch location' });
        }

        res.json({ location: data });
    } catch (error) {
        console.error('Get location error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
};

// GET /api/location/admin/vehicles - Get all vehicle locations for admin
export const getAllVehicleLocations = async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('vehicle_locations')
            .select(`
        *,
        driver:driverid (driverid, user:userid (fullname, phone)),
        vehicle:vehicleid (vehicleid, plateno, seatnum)
      `)
            .eq('is_online', true)
            .order('timestamp', { ascending: false });

        if (error) {
            console.error('Get all locations error:', error);
            return res.status(500).json({ error: 'Failed to fetch vehicle locations' });
        }

        res.json({ vehicles: data });
    } catch (error) {
        console.error('Get all locations exception:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
};