import supabase from '../config/dbcon.js';

class Driver {
  static async create(driverData) {
    const { data, error } = await supabase
      .from('driver')
      .insert([driverData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(driverid) {
    const { data, error } = await supabase
      .from('driver')
      .select('*, user(*), line(*)')
      .eq('driverid', driverid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByUserId(userid) {
    const { data, error } = await supabase
      .from('driver')
      .select('*, user(*), line(*)')
      .eq('userid', userid)
      .single();
    
    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async update(driverid, updates) {
    const { data, error } = await supabase
      .from('driver')
      .update(updates)
      .eq('driverid', driverid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase.from('driver').select('*, user(*)');
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }

  static async updateRating(driverid, newRating) {
    const { data, error } = await supabase
      .from('driver')
      .update({ rating: newRating })
      .eq('driverid', driverid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }
}

export default Driver;

