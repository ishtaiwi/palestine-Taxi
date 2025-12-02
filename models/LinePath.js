import supabase from '../config/dbcon.js';
import { v4 as uuidv4 } from 'uuid';
import { decodePolyline } from '../services/polylineService.js';

class LinePath {
    static async findByLineId(lineid) {
        const { data, error } = await supabase
            .from('line_path')
            .select('*')
            .eq('lineid', lineid)
            .single();

        if (error && error.code !== 'PGRST116') throw error;
        return data;
    }

    static async create(lineid, pathData) {
        const { waypoints, polyline, distance_meters } = pathData;

        // Calculate total path distance if not provided
        let calculatedDistance = distance_meters;
        if (!calculatedDistance) {
            if (waypoints && waypoints.length > 1) {
                // Calculate from waypoints (sum of all segments)
                calculatedDistance = this.calculatePathDistance(waypoints);
            } else if (polyline) {
                // Calculate from polyline if waypoints not available
                calculatedDistance = this.calculatePathDistanceFromPolyline(polyline);
            }
        }

        const path = {
            pathid: uuidv4(),
            lineid,
            waypoints: Array.isArray(waypoints) ? waypoints : JSON.parse(waypoints),
            polyline: polyline || null,
            distance_meters: calculatedDistance || null,
        };

        const { data, error } = await supabase
            .from('line_path')
            .insert([path])
            .select()
            .single();

        if (error) throw error;
        return data;
    }

    static async update(lineid, pathData) {
        const { waypoints, polyline, distance_meters } = pathData;

        // Calculate total path distance if not provided
        let calculatedDistance = distance_meters;
        if (!calculatedDistance) {
            if (waypoints) {
                const waypointsArray = Array.isArray(waypoints) ? waypoints : JSON.parse(waypoints);
                if (waypointsArray.length > 1) {
                    // Calculate from waypoints (sum of all segments)
                    calculatedDistance = this.calculatePathDistance(waypointsArray);
                }
            } else if (polyline) {
                // Calculate from polyline if waypoints not available
                calculatedDistance = this.calculatePathDistanceFromPolyline(polyline);
            }
        }

        const updates = {
            waypoints: waypoints ? (Array.isArray(waypoints) ? waypoints : JSON.parse(waypoints)) : undefined,
            polyline: polyline !== undefined ? polyline : undefined,
            distance_meters: calculatedDistance || distance_meters || undefined,
        };

        // Remove undefined values
        Object.keys(updates).forEach(key => updates[key] === undefined && delete updates[key]);

        const { data, error } = await supabase
            .from('line_path')
            .update(updates)
            .eq('lineid', lineid)
            .select()
            .single();

        if (error) throw error;
        return data;
    }

    static async upsert(lineid, pathData) {
        const existing = await this.findByLineId(lineid);
        if (existing) {
            return await this.update(lineid, pathData);
        } else {
            return await this.create(lineid, pathData);
        }
    }

    static async delete(lineid) {
        const { error } = await supabase
            .from('line_path')
            .delete()
            .eq('lineid', lineid);

        if (error) throw error;
        return true;
    }

    /**
     * Calculate total path distance by summing distances between consecutive waypoints
     * This gives the total length of the path, not just the straight-line distance
     * @param {Array} waypoints - Array of waypoint objects with lat/lng or latitude/longitude
     * @returns {number} Total path distance in meters
     */
    static calculatePathDistance(waypoints) {
        // Calculate total distance along path by summing all segments between waypoints
        if (!waypoints || waypoints.length < 2) return 0;

        let totalDistance = 0;
        for (let i = 0; i < waypoints.length - 1; i++) {
            const point1 = waypoints[i];
            const point2 = waypoints[i + 1];

            // Support both lat/lng and latitude/longitude formats
            const lat1 = point1.lat ?? point1.latitude;
            const lng1 = point1.lng ?? point1.longitude;
            const lat2 = point2.lat ?? point2.latitude;
            const lng2 = point2.lng ?? point2.longitude;

            if (lat1 != null && lng1 != null && lat2 != null && lng2 != null) {
                // Calculate distance between this pair of consecutive waypoints
                const segmentDistance = this.haversineDistance(lat1, lng1, lat2, lng2);
                totalDistance += segmentDistance;
            }
        }

        // Round to 2 decimal places for precision
        return Math.round(totalDistance * 100) / 100;
    }

    /**
     * Calculate path distance from encoded polyline
     * Decodes the polyline and calculates total distance by summing all segments
     * @param {string} encodedPolyline - Encoded polyline string
     * @returns {number} Total path distance in meters
     */
    static calculatePathDistanceFromPolyline(encodedPolyline) {
        if (!encodedPolyline) return 0;

        try {
            const coordinates = decodePolyline(encodedPolyline);

            if (!coordinates || coordinates.length < 2) return 0;

            // Convert decoded coordinates to waypoints format
            const waypoints = coordinates.map(([lat, lng]) => ({ lat, lng }));
            // Calculate total distance by summing all segments
            return this.calculatePathDistance(waypoints);
        } catch (error) {
            console.error('Error calculating distance from polyline:', error);
            return 0;
        }
    }

    static haversineDistance(lat1, lng1, lat2, lng2) {
        // Haversine formula to calculate distance between two points in meters
        const R = 6371000; // Earth's radius in meters
        const dLat = this.toRadians(lat2 - lat1);
        const dLng = this.toRadians(lng2 - lng1);

        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);

        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c; // Distance in meters
    }

    static toRadians(degrees) {
        return degrees * (Math.PI / 180);
    }
}

export default LinePath;

