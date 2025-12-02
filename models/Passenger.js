import supabase from '../config/dbcon.js';

class Passenger {
  static async create(passengerData) {
    const { data, error } = await supabase
      .from('passenger')
      .insert([passengerData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(passengerid) {
    const { data, error } = await supabase
      .from('passenger')
      .select('*, user(*)')
      .eq('passengerid', passengerid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByUserId(userid) {
    const { data, error } = await supabase
      .from('passenger')
      .select('*, user(*)')
      .eq('userid', userid)
      .single();
    
    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async update(passengerid, updates) {
    const { data, error } = await supabase
      .from('passenger')
      .update(updates)
      .eq('passengerid', passengerid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase.from('passenger').select('*, user(*)');
    
    // Type filter removed - field no longer exists in database
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }
}

export default Passenger;

