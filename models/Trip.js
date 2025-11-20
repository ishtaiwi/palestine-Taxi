import supabase from '../config/dbcon.js';

class Trip {
  static async create(tripData) {
    const { data, error } = await supabase
      .from('trip')
      .insert([tripData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(tripid) {
    const { data, error } = await supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .eq('tripid', tripid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))');
    
    if (filters.lineid) {
      query = query.eq('lineid', filters.lineid);
    }
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    if (filters.date) {
      query = query.gte('deptime', filters.date);
    }
    
    const { data, error } = await query.order('deptime', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async findUpcoming(filters = {}) {
    const now = new Date().toISOString();
    let query = supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .gte('deptime', now);
    
    if (filters.lineid) {
      query = query.eq('lineid', filters.lineid);
    }
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    const { data, error } = await query.order('deptime', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async findUpcomingByVehicle(vehicleid) {
    const now = new Date().toISOString();
    const { data, error } = await supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .eq('vehicleid', vehicleid)
      .in('status', ['scheduled', 'in_progress'])
      .gte('deptime', now)
      .order('deptime', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (error && error.code !== 'PGRST116') throw error;
    return data || null;
  }

  static async findByVehicleIds(vehicleIds = [], filters = {}) {
    if (!vehicleIds || vehicleIds.length === 0) {
      return [];
    }

    let query = supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .in('vehicleid', vehicleIds);

    if (filters.status) {
      query = query.eq('status', filters.status);
    }

    if (filters.fromNow) {
      query = query.gte('deptime', new Date().toISOString());
    }

    const { data, error } = await query.order('deptime', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async update(tripid, updates) {
    const { data, error } = await supabase
      .from('trip')
      .update(updates)
      .eq('tripid', tripid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async updateAvailableSeats(tripid, seats) {
    const { data, error } = await supabase
      .from('trip')
      .update({ availableseats: seats })
      .eq('tripid', tripid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async incrementBookings(tripid) {
    const { data, error } = await supabase.rpc('increment_trip_bookings', {
      trip_id: tripid
    });
    
    if (error) {
      
      const trip = await this.findById(tripid);
      return await this.update(tripid, { totalbookings: (trip.totalbookings || 0) + 1 });
    }
    
    return data;
  }
}

export default Trip;

