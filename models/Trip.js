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
      .select('*, line(*), vehicle(*, driver(*, user(*))), schedule_template(*)')
      .eq('tripid', tripid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*))), schedule_template(*)');
    
    if (filters.lineid) {
      query = query.eq('lineid', filters.lineid);
    }
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    if (filters.date) {
      // Filter by date: get trips on the specified date only
      // Parse the date string (could be YYYY-MM-DD or full ISO string)
      const dateStr = filters.date;
      let startDate, endDate;
      
      // If date is in YYYY-MM-DD format, convert to date range
      if (dateStr.match(/^\d{4}-\d{2}-\d{2}$/)) {
        // Start of the day (00:00:00)
        startDate = new Date(dateStr + 'T00:00:00.000Z');
        // End of the day (23:59:59.999)
        endDate = new Date(dateStr + 'T23:59:59.999Z');
      } else {
        // If it's already a full ISO string, use it as start and calculate end
        startDate = new Date(dateStr);
        startDate = new Date(startDate);
        startDate.setHours(0, 0, 0, 0);
        endDate = new Date(startDate);
        endDate.setHours(23, 59, 59, 999);
      }
      
      query = query.gte('deptime', startDate.toISOString())
                   .lte('deptime', endDate.toISOString());
    }
    
    if (filters.templateid) {
      query = query.eq('templateid', filters.templateid);
    }
    
    const { data, error } = await query.order('deptime', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async findUpcoming(filters = {}) {
    let query = supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))');
    
    // Support date filtering for upcoming trips
    if (filters.date) {
      const dateStr = filters.date;
      let startDate, endDate;
      
      // If date is in YYYY-MM-DD format, convert to date range
      if (dateStr.match(/^\d{4}-\d{2}-\d{2}$/)) {
        // Start of the day (00:00:00)
        startDate = new Date(dateStr + 'T00:00:00.000Z');
        // End of the day (23:59:59.999)
        endDate = new Date(dateStr + 'T23:59:59.999Z');
      } else {
        // If it's already a full ISO string, use it as start and calculate end
        startDate = new Date(dateStr);
        startDate = new Date(startDate);
        startDate.setHours(0, 0, 0, 0);
        endDate = new Date(startDate);
        endDate.setHours(23, 59, 59, 999);
      }
      
      const dateStartISO = startDate.toISOString();
      const dateEndISO = endDate.toISOString();
      const now = new Date().toISOString();
      
      // Use the later of "now" or "startDate" to ensure we only show upcoming trips
      const filterStart = dateStartISO > now ? dateStartISO : now;
      
      query = query.gte('deptime', filterStart)
                   .lte('deptime', dateEndISO);
    } else {
      // No date filter - only show upcoming trips from now
      const now = new Date().toISOString();
      query = query.gte('deptime', now);
    }
    
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

  static async findOpenTrips(filters = {}) {
    const now = new Date().toISOString();
    let query = supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .lte('trip_opening_time', now)
      .eq('status', 'scheduled');
    
    if (filters.lineid) {
      query = query.eq('lineid', filters.lineid);
    }
    
    const { data, error } = await query.order('deptime', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async findTripsNeedingOpening(openingWindowMinutes = 45) {
    const now = new Date();
    const openingTime = new Date(now.getTime() + openingWindowMinutes * 60 * 1000);
    
    const { data, error } = await supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .eq('status', 'scheduled')
      .is('trip_opening_time', null)
      .lte('deptime', openingTime.toISOString())
      .order('deptime', { ascending: true });
    
    if (error) throw error;
    return data;
  }

  static async findTripsNeedingDeparture() {
    const now = new Date().toISOString();
    const { data, error } = await supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .eq('status', 'scheduled')
      .lte('deptime', now)
      .order('deptime', { ascending: true });
    
    if (error) throw error;
    return data;
  }

  static async assignDriver(tripid, driverid) {
    return await this.update(tripid, {
      assigned_driverid: driverid,
      assignment_time: new Date().toISOString(),
    });
  }

  static async findAssignedTrips(driverid, filters = {}) {
    let query = supabase
      .from('trip')
      .select('*, line(*), vehicle(*, driver(*, user(*)))')
      .eq('assigned_driverid', driverid);
    
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

  static async getCapacityUtilizationByLineAndTime(lineid, options = {}) {
    if (!lineid) {
      throw new Error('lineid is required for getCapacityUtilizationByLineAndTime');
    }

    const { startDate, endDate, groupBy = 'hour' } = options;
    let query = supabase
      .from('trip')
      .select('tripid, lineid, deptime, totalbookings, availableseats, vehicle(seatnum), line(lineid, linename)')
      .eq('lineid', lineid);

    if (startDate) {
      const start = new Date(startDate);
      if (Number.isNaN(start.getTime())) {
        throw new Error('Invalid startDate supplied to getCapacityUtilizationByLineAndTime');
      }
      query = query.gte('deptime', start.toISOString());
    }

    if (endDate) {
      const end = new Date(endDate);
      if (Number.isNaN(end.getTime())) {
        throw new Error('Invalid endDate supplied to getCapacityUtilizationByLineAndTime');
      }
      query = query.lte('deptime', end.toISOString());
    }

    const { data, error } = await query.order('deptime', { ascending: true });
    if (error) throw error;

    const buckets = {};
    for (const trip of data || []) {
      const bucketKey = buildUtilizationBucketKey(trip.deptime, groupBy);
      if (!bucketKey) {
        continue;
      }

      const capacity = Math.max((trip.vehicle?.seatnum ?? 0) - 1, 0);
      const seatsRemaining = trip.availableseats ?? Math.max(capacity - (trip.totalbookings ?? 0), 0);
      const bookedSeats = Math.max(capacity - seatsRemaining, 0);
      const utilization = capacity > 0 ? bookedSeats / capacity : 0;

      if (!buckets[bucketKey]) {
        buckets[bucketKey] = {
          lineid: trip.lineid,
          line: trip.line,
          bucket: bucketKey,
          bucketLabel: buildUtilizationBucketLabel(trip.deptime, groupBy),
          totalCapacity: 0,
          totalBooked: 0,
          totalTrips: 0,
          avgUtilization: 0,
          samples: [],
        };
      }

      buckets[bucketKey].totalCapacity += capacity;
      buckets[bucketKey].totalBooked += bookedSeats;
      buckets[bucketKey].totalTrips += 1;
      buckets[bucketKey].samples.push({
        tripid: trip.tripid,
        deptime: trip.deptime,
        capacity,
        bookedSeats,
        utilization,
      });
    }

    return Object.values(buckets).map((bucket) => ({
      ...bucket,
      avgUtilization: bucket.totalCapacity > 0 ? bucket.totalBooked / bucket.totalCapacity : 0,
    }));
  }
}

export default Trip;

function buildUtilizationBucketKey(deptime, groupBy) {
  if (!deptime) return null;
  const date = new Date(deptime);
  if (Number.isNaN(date.getTime())) return null;

  switch (groupBy) {
    case 'day':
      return `${date.getUTCFullYear()}-${date.getUTCMonth()}-${date.getUTCDate()}`;
    case 'hour':
      return `${date.toISOString().slice(0, 13)}:00`;
    case 'date':
      return date.toISOString().slice(0, 10);
    default:
      return `${date.toISOString().slice(0, 13)}:00`;
  }
}

function buildUtilizationBucketLabel(deptime, groupBy) {
  const key = buildUtilizationBucketKey(deptime, groupBy);
  if (!key) return 'Unknown';
  switch (groupBy) {
    case 'day':
      return `Day ${key}`;
    case 'date':
      return key;
    case 'hour':
    default:
      return key;
  }
}

