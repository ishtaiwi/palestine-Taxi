import supabase from '../config/dbcon.js';

class Vehicle {
  static async create(vehicleData) {
    const { data, error } = await supabase
      .from('vehicle')
      .insert([vehicleData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(vehicleid) {
    const { data, error } = await supabase
      .from('vehicle')
      .select('*, driver(*, user(*)), line(*)')
      .eq('vehicleid', vehicleid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByDriverId(driverid) {
    const { data, error } = await supabase
      .from('vehicle')
      .select('*, driver(*, user(*)), line(*)')
      .eq('driverid', driverid);
    
    if (error) throw error;
    return data;
  }

  static async findByLineId(lineid) {
    const { data, error } = await supabase
      .from('vehicle')
      .select('*, driver(*, user(*)), line(*)')
      .eq('lineid', lineid);
    
    if (error) throw error;
    return data;
  }

  static async update(vehicleid, updates) {
    const { data, error } = await supabase
      .from('vehicle')
      .update(updates)
      .eq('vehicleid', vehicleid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase.from('vehicle').select('*, driver(*, user(*)), line(*)');
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    if (filters.lineid) {
      query = query.eq('lineid', filters.lineid);
    }
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }
}

export default Vehicle;

