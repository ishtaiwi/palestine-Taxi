import supabase from '../config/dbcon.js';
import { v4 as uuidv4 } from 'uuid';
import BaseStation from './BaseStation.js';
import Vehicle from './Vehicle.js';

class VehicleLocation {
    static async upsert(vehicleid, driverid, locationData) {
        const { latitude, longitude, heading, speed, accuracy } = locationData;

        const vehicle = await Vehicle.findById(vehicleid);
        const vehicleLineid = vehicle?.lineid || null;

        const allStations = await BaseStation.findAll({ is_active: true });

        let currentStationid = null;
        let isAtStation = false;

        for (const station of allStations) {
            const distance = BaseStation.calculateDistance(
                latitude,
                longitude,
                station.latitude,
                station.longitude
            );

            const isWithinGeofence = distance <= station.geofence_radius_meters;

            if (isWithinGeofence) {
                const isMainStation = station.lineid === null;
                const isVehicleLineStation = station.lineid === vehicleLineid;

                if (isMainStation || isVehicleLineStation) {
                    currentStationid = station.stationid;
                    isAtStation = true;
                    break;
                }
            }
        }

        const location = {
            vehicleid,
            driverid,
            latitude,
            longitude,
            heading: heading || null,
            speed: speed || null,
            accuracy: accuracy || null,
            current_stationid: currentStationid,
            is_at_station: isAtStation,
        };

        const { data, error } = await supabase
            .from('vehicle_location')
            .upsert(location, {
                onConflict: 'vehicleid',
                ignoreDuplicates: false,
            })
            .select()
            .single();

        if (error) throw error;
        return data;
    }

    static async findByVehicleId(vehicleid) {
        const { data, error } = await supabase
            .from('vehicle_location')
            .select('*')
            .eq('vehicleid', vehicleid)
            .single();

        if (error && error.code !== 'PGRST116') throw error;
        return data;
    }

    static async findByDriverId(driverid) {
        const { data, error } = await supabase
            .from('vehicle_location')
            .select('*')
            .eq('driverid', driverid)
            .single();

        if (error && error.code !== 'PGRST116') throw error;
        return data;
    }

    static async findAllActive(maxAgeMinutes = 2) {
        const cutoffTime = new Date();
        cutoffTime.setMinutes(cutoffTime.getMinutes() - maxAgeMinutes);

        const { data, error } = await supabase
            .from('vehicle_location')
            .select(`
        *,
        vehicle:vehicleid (
          vehicleid,
          plateno,
          seatnum,
          lineid,
          line:lineid (
            lineid,
            linename
          )
        ),
        driver:driverid (
          driverid,
          user:userid (
            userid,
            fullname,
            phone
          )
        )
      `)
            .gte('updated_at', cutoffTime.toISOString())
            .order('updated_at', { ascending: false });

        if (error) throw error;
        return data || [];
    }

    static async findDriversAtBaseStation(stationid = null) {
        let query = supabase
            .from('vehicle_location')
            .select(`
        *,
        vehicle:vehicleid (
          vehicleid,
          plateno,
          seatnum,
          lineid
        ),
        driver:driverid (
          driverid,
          user:userid (
            userid,
            fullname,
            phone
          )
        ),
        station:current_stationid (
          stationid,
          name,
          latitude,
          longitude,
          lineid
        )
      `)
            .eq('is_at_station', true);

        if (stationid) {
            query = query.eq('current_stationid', stationid);
        }

        const { data, error } = await query;
        if (error) throw error;
        return data || [];
    }

    static async deleteByVehicleId(vehicleid) {
        const { error } = await supabase
            .from('vehicle_location')
            .delete()
            .eq('vehicleid', vehicleid);

        if (error) throw error;
        return true;
    }
}

export default VehicleLocation;

