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
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user!driver_userid_fkey(*)))), payment(*)')
      .eq('bookingid', bookingid)
      .single();

    if (error) throw error;
    return data;
  }

  static async findByPassengerId(passengerid, filters = {}) {
    let query = supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user!driver_userid_fkey(*)))), payment(*)')
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
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user!driver_userid_fkey(*)))), payment(*)');

    if (filters.status) {
      query = query.eq('status', filters.status);
    }

    if (filters.tripid) {
      query = query.eq('tripid', filters.tripid);
    }

    if (filters.booking_type) {
      query = query.eq('booking_type', filters.booking_type);
    }

    const { data, error } = await query.order('bookedat', { ascending: false });
    if (error) throw error;
    return data;
  }

  static async findByBookingType(bookingType, filters = {}) {
    let query = supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user!driver_userid_fkey(*)))), payment(*)')
      .eq('booking_type', bookingType);

    if (filters.status) {
      query = query.eq('status', filters.status);
    }

    if (filters.scheduled_trip_time) {
      query = query.eq('scheduled_trip_time', filters.scheduled_trip_time);
    }

    const { data, error } = await query.order('bookedat', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async findFutureBookingsForTrip(scheduledTripTime, filters = {}) {
    let query = supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), trip(*, line(*), vehicle(*, driver(*, user!driver_userid_fkey(*)))), payment(*)')
      .eq('booking_type', 'future')
      .eq('scheduled_trip_time', scheduledTripTime)
      .in('status', ['confirmed', 'pending']);

    if (filters.tripid) {
      query = query.eq('tripid', filters.tripid);
    }

    const { data, error } = await query.order('bookedat', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async findInstantBookingsForTrip(tripid, filters = {}) {
    let query = supabase
      .from('reservation')
      .select('*, passenger(*, user(*)), payment(*)')
      .eq('tripid', tripid)
      .eq('booking_type', 'instant')
      .in('status', ['confirmed', 'pending']);

    const { data, error } = await query.order('bookedat', { ascending: true });
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

  static async getHistoricalBookingsByTimeRange(startDate, endDate, filters = {}) {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new Error('Invalid date range supplied to getHistoricalBookingsByTimeRange');
    }

    if (end <= start) {
      throw new Error('endDate must be later than startDate');
    }

    let query = supabase
      .from('reservation')
      .select('bookingid, booking_type, status, bookedat, scheduled_trip_time, trip(tripid, deptime, lineid, line(lineid, linename))')
      .gte('bookedat', start.toISOString())
      .lte('bookedat', end.toISOString());

    if (filters.booking_type) {
      query = query.eq('booking_type', filters.booking_type);
    }

    if (filters.status) {
      query = query.eq('status', filters.status);
    }

    const { data, error } = await query;
    if (error) throw error;

    let rows = data || [];
    if (filters.lineid) {
      rows = rows.filter((reservation) => resolveLineId(reservation) === filters.lineid);
    }

    const buckets = {};
    for (const reservation of rows) {
      const lineid = resolveLineId(reservation);
      const eventDate = resolveEventDate(reservation);

      if (!eventDate || !lineid) {
        continue;
      }

      const dayOfWeek = eventDate.getUTCDay();
      const hour = eventDate.getUTCHours();
      const key = `${lineid}|${dayOfWeek}|${hour}`;

      if (!buckets[key]) {
        buckets[key] = {
          lineid,
          dayOfWeek,
          hour,
          totalBookings: 0,
          statusBreakdown: {},
          samples: [],
        };
      }

      buckets[key].totalBookings += 1;
      buckets[key].statusBreakdown[reservation.status] = (buckets[key].statusBreakdown[reservation.status] || 0) + 1;
      buckets[key].samples.push({
        bookingid: reservation.bookingid,
        booking_type: reservation.booking_type,
        status: reservation.status,
        bookedat: reservation.bookedat,
        scheduled_trip_time: reservation.scheduled_trip_time,
        tripid: reservation.trip?.tripid ?? null,
      });
    }

    return Object.values(buckets);
  }

  static async streamNewBookingsSince(sinceDate, filters = {}) {
    const since = new Date(sinceDate);

    if (Number.isNaN(since.getTime())) {
      throw new Error('Invalid date supplied to streamNewBookingsSince');
    }

    let query = supabase
      .from('reservation')
      .select('bookingid, booking_type, status, bookedat, scheduled_trip_time, trip(tripid, deptime, lineid, line(lineid, linename))')
      .gt('bookedat', since.toISOString())
      .order('bookedat', { ascending: true });

    if (filters.booking_type) {
      query = query.eq('booking_type', filters.booking_type);
    }

    if (filters.status) {
      query = query.eq('status', filters.status);
    }

    const { data, error } = await query;
    if (error) throw error;

    let rows = data || [];
    if (filters.lineid) {
      rows = rows.filter((reservation) => resolveLineId(reservation) === filters.lineid);
    }

    return rows.map((reservation) => ({
      bookingid: reservation.bookingid,
      lineid: resolveLineId(reservation),
      booking_type: reservation.booking_type,
      status: reservation.status,
      bookedat: reservation.bookedat,
      scheduled_trip_time: reservation.scheduled_trip_time,
      tripid: reservation.trip?.tripid ?? null,
      eventTime: resolveEventDate(reservation)?.toISOString() ?? null,
    }));
  }

  static async deleteByPassengerId(passengerid) {
    const { error } = await supabase
      .from('reservation')
      .delete()
      .eq('passengerid', passengerid);
    
    if (error) throw error;
    return true;
  }

  static async delete(bookingid) {
    const { error } = await supabase
      .from('reservation')
      .delete()
      .eq('bookingid', bookingid);
    
    if (error) throw error;
    return true;
  }
}

export default Reservation;

function resolveLineId(reservation) {
  return reservation.lineid
    || reservation.trip?.lineid
    || reservation.trip?.line?.lineid
    || null;
}

function resolveEventDate(reservation) {
  if (reservation.trip?.deptime) {
    return new Date(reservation.trip.deptime);
  }

  if (reservation.scheduled_trip_time) {
    return new Date(reservation.scheduled_trip_time);
  }

  if (reservation.bookedat) {
    return new Date(reservation.bookedat);
  }

  return null;
}

