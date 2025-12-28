import supabase from '../config/dbcon.js';
import { v4 as uuidv4 } from 'uuid';

class BaseStation {
  static async findAll(filters = {}) {
    let query = supabase.from('base_station').select('*');
    
    if (filters.is_active !== undefined) {
      query = query.eq('is_active', filters.is_active);
    }
    
    if (filters.lineid) {
      query = query.eq('lineid', filters.lineid);
    }
    
    const { data, error } = await query.order('name', { ascending: true });
    if (error) throw error;
    return data || [];
  }

  static async findById(stationid) {
    const { data, error } = await supabase
      .from('base_station')
      .select('*')
      .eq('stationid', stationid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async create(stationData) {
    const station = {
      stationid: stationData.stationid || uuidv4(),
      name: stationData.name,
      latitude: stationData.latitude,
      longitude: stationData.longitude,
      geofence_radius_meters: stationData.geofence_radius_meters || 100,
      lineid: stationData.lineid || null,
      is_active: stationData.is_active !== undefined ? stationData.is_active : true,
    };

    const { data, error } = await supabase
      .from('base_station')
      .insert([station])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async update(stationid, updates) {
    const { data, error } = await supabase
      .from('base_station')
      .update(updates)
      .eq('stationid', stationid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async delete(stationid) {
    const { error } = await supabase
      .from('base_station')
      .delete()
      .eq('stationid', stationid);
    
    if (error) throw error;
    return true;
  }

  static async findNearestStation(latitude, longitude) {
    const stations = await this.findAll({ is_active: true });
    
    if (stations.length === 0) return null;
    
    let nearest = null;
    let minDistance = Infinity;
    
    for (const station of stations) {
      const distance = this.calculateDistance(
        latitude,
        longitude,
        station.latitude,
        station.longitude
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearest = station;
      }
    }
    
    return nearest;
  }

  static calculateDistance(lat1, lng1, lat2, lng2) {
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
}

export default BaseStation;

