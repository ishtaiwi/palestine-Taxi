import supabase from '../config/dbcon.js';

class Reservation {
  static async create(reservationData) {
    const { data, error } = await supabase
      .from('reservation')
      .insert([reservationData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(bookingid) {
    const { data, error } = await supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user(*)))), payment(*)')
      .eq('bookingid', bookingid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByPassengerId(passengerid, filters = {}) {
    let query = supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user(*)))), payment(*)')
      .eq('passengerid', passengerid);
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    const { data, error } = await query.order('bookedat', { ascending: false });
    if (error) throw error;
    return data;
  }

  static async findByTripId(tripid) {
    const { data, error } = await supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), payment(*)')
      .eq('tripid', tripid)
      .order('bookedat', { ascending: true });
    
    if (error) throw error;
    return data;
  }

  static async update(bookingid, updates) {
    const { data, error } = await supabase
      .from('reservation')
      .update(updates)
      .eq('bookingid', bookingid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user(*)))), payment(*)');
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    if (filters.tripid) {
      query = query.eq('tripid', filters.tripid);
    }
    
    const { data, error } = await query.order('bookedat', { ascending: false });
    if (error) throw error;
    return data;
  }

  static async getBySeatLocation(tripid, seatlocation) {
    const { data, error } = await supabase
      .from('reservation')
      .select('*')
      .eq('tripid', tripid)
      .eq('seatlocation', seatlocation)
      .in('status', ['confirmed', 'checked_in']);
    
    if (error) throw error;
    return data;
  }
}

export default Reservation;

