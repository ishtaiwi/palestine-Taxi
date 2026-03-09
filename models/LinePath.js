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

        let calculatedDistance = distance_meters;
        if (!calculatedDistance) {
            if (waypoints && waypoints.length > 1) {
                calculatedDistance = this.calculatePathDistance(waypoints);
            } else if (polyline) {
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

        let calculatedDistance = distance_meters;
        if (!calculatedDistance) {
            if (waypoints) {
                const waypointsArray = Array.isArray(waypoints) ? waypoints : JSON.parse(waypoints);
                if (waypointsArray.length > 1) {
                    calculatedDistance = this.calculatePathDistance(waypointsArray);
                }
            } else if (polyline) {
                calculatedDistance = this.calculatePathDistanceFromPolyline(polyline);
            }
        }

        const updates = {
            waypoints: waypoints ? (Array.isArray(waypoints) ? waypoints : JSON.parse(waypoints)) : undefined,
            polyline: polyline !== undefined ? polyline : undefined,
            distance_meters: calculatedDistance || distance_meters || undefined,
        };

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

    static calculatePathDistance(waypoints) {
        if (!waypoints || waypoints.length < 2) return 0;

        let totalDistance = 0;
        for (let i = 0; i < waypoints.length - 1; i++) {
            const point1 = waypoints[i];
            const point2 = waypoints[i + 1];

            const lat1 = point1.lat ?? point1.latitude;
            const lng1 = point1.lng ?? point1.longitude;
            const lat2 = point2.lat ?? point2.latitude;
            const lng2 = point2.lng ?? point2.longitude;

            if (lat1 != null && lng1 != null && lat2 != null && lng2 != null) {
                const segmentDistance = this.haversineDistance(lat1, lng1, lat2, lng2);
                totalDistance += segmentDistance;
            }
        }

        return Math.round(totalDistance * 100) / 100;
    }

    static calculatePathDistanceFromPolyline(encodedPolyline) {
        if (!encodedPolyline) return 0;

        try {
            const coordinates = decodePolyline(encodedPolyline);

            if (!coordinates || coordinates.length < 2) return 0;

            const waypoints = coordinates.map(([lat, lng]) => ({ lat, lng }));
            return this.calculatePathDistance(waypoints);
        } catch (error) {
            console.error('Error calculating distance from polyline:', error);
            return 0;
        }
    }

    static haversineDistance(lat1, lng1, lat2, lng2) {
        const R = 6371000;
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

    /**
     * Get reversed waypoints for returning trips
     * @param {string} lineid - Line ID
     * @returns {Promise<Array>} - Reversed waypoint array
     */
    static async getReversedWaypoints(lineid) {
        const path = await this.findByLineId(lineid);
        if (!path || !path.waypoints) {
            return [];
        }

        const waypoints = Array.isArray(path.waypoints) ? path.waypoints : JSON.parse(path.waypoints);
        return [...waypoints].reverse();
    }

    /**
     * Get origin waypoint (first waypoint)
     * @param {string} lineid - Line ID
     * @returns {Promise<Object|null>} - First waypoint or null
     */
    static async getOriginStation(lineid) {
        const path = await this.findByLineId(lineid);
        if (!path || !path.waypoints) {
            return null;
        }

        const waypoints = Array.isArray(path.waypoints) ? path.waypoints : JSON.parse(path.waypoints);
        return waypoints.length > 0 ? waypoints[0] : null;
    }

    /**
     * Get destination waypoint (last waypoint)
     * @param {string} lineid - Line ID
     * @returns {Promise<Object|null>} - Last waypoint or null
     */
    static async getDestinationStation(lineid) {
        const path = await this.findByLineId(lineid);
        if (!path || !path.waypoints) {
            return null;
        }

        const waypoints = Array.isArray(path.waypoints) ? path.waypoints : JSON.parse(path.waypoints);
        return waypoints.length > 0 ? waypoints[waypoints.length - 1] : null;
    }
}

export default LinePath;

