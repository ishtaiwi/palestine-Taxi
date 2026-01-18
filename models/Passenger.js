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
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }

  static async delete(passengerid) {
    const { error } = await supabase
      .from('passenger')
      .delete()
      .eq('passengerid', passengerid);
    
    if (error) throw error;
    return true;
  }

  static async findOrCreateByPhone(phone, userid) {
    // First try to find existing passenger for this user
    let passenger = await this.findByUserId(userid);
    
    if (passenger) {
      return passenger;
    }

    // Create new passenger record
    const { v4: uuidv4 } = await import('uuid');
    const passengerData = {
      passengerid: uuidv4(),
      userid: userid,
    };

    passenger = await this.create(passengerData);
    return passenger;
  }
}

export default Passenger;

