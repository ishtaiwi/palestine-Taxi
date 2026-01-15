import supabase from '../config/dbcon.js';

class Rating {
  static async create(ratingData) {
    const { data, error } = await supabase
      .from('trip_rating')
      .insert([ratingData])
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async findById(ratingid) {
    const { data, error } = await supabase
      .from('trip_rating')
      .select('*, reservation(*, passenger(*, user(*))), trip(*)')
      .eq('ratingid', ratingid)
      .single();

    if (error) throw error;
    return data;
  }

  static async findByBookingId(bookingid) {
    const { data, error } = await supabase
      .from('trip_rating')
      .select('*, reservation(*, passenger(*, user(*))), trip(*)')
      .eq('bookingid', bookingid)
      .single();

    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async findByTripId(tripid) {
    const { data, error } = await supabase
      .from('trip_rating')
      .select('*, reservation(*, passenger(*, user(*)))')
      .eq('tripid', tripid)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data;
  }

  static async findByPassengerId(passengerid) {
    const { data, error } = await supabase
      .from('trip_rating')
      .select('*, reservation(*), trip(*, line(*))')
      .eq('passengerid', passengerid)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data;
  }

  static async update(ratingid, updates) {
    const { data, error } = await supabase
      .from('trip_rating')
      .update(updates)
      .eq('ratingid', ratingid)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async getAverageRating(tripid) {
    const { data, error } = await supabase
      .from('trip_rating')
      .select('rating')
      .eq('tripid', tripid);

    if (error) throw error;

    if (!data || data.length === 0) {
      return { average: 0, count: 0 };
    }

    const sum = data.reduce((acc, item) => acc + item.rating, 0);
    const average = sum / data.length;

    return {
      average: Math.round(average * 10) / 10, // Round to 1 decimal place
      count: data.length,
    };
  }

  static async getAverageRatingByDriver(driverid) {
    // Get all trips for this driver, then get all ratings for those trips
    const { data: trips, error: tripsError } = await supabase
      .from('trip')
      .select('tripid')
      .eq('assigned_driverid', driverid);

    if (tripsError) throw tripsError;

    if (!trips || trips.length === 0) {
      return { average: 0, count: 0 };
    }

    const tripIds = trips.map(t => t.tripid);

    const { data, error } = await supabase
      .from('trip_rating')
      .select('rating')
      .in('tripid', tripIds);

    if (error) throw error;

    if (!data || data.length === 0) {
      return { average: 0, count: 0 };
    }

    const sum = data.reduce((acc, item) => acc + item.rating, 0);
    const average = sum / data.length;

    return {
      average: Math.round(average * 10) / 10, // Round to 1 decimal place
      count: data.length,
    };
  }

  static async findPendingRatings(passengerid) {
    // Get all completed trips with reservations for this passenger that don't have ratings
    const { data: reservations, error: reservationsError } = await supabase
      .from('reservation')
      .select('bookingid, tripid, status, trip!inner(status, assigned_driverid)')
      .eq('passengerid', passengerid)
      .eq('trip.status', 'completed')
      .in('status', ['confirmed', 'checked_in'])
      .not('tripid', 'is', null);

    if (reservationsError) throw reservationsError;

    if (!reservations || reservations.length === 0) {
      return [];
    }

    // Get all existing ratings for these bookings
    const bookingIds = reservations.map(r => r.bookingid);
    const { data: existingRatings, error: ratingsError } = await supabase
      .from('trip_rating')
      .select('bookingid')
      .in('bookingid', bookingIds);

    if (ratingsError) throw ratingsError;

    const ratedBookingIds = new Set((existingRatings || []).map(r => r.bookingid));

    // Filter out reservations that already have ratings
    const pending = reservations.filter(r => !ratedBookingIds.has(r.bookingid));

    return pending;
  }

  static async delete(ratingid) {
    const { error } = await supabase
      .from('trip_rating')
      .delete()
      .eq('ratingid', ratingid);

    if (error) throw error;
    return true;
  }

  static async deleteByPassengerId(passengerid) {
    const { error } = await supabase
      .from('trip_rating')
      .delete()
      .eq('passengerid', passengerid);

    if (error) throw error;
    return true;
  }
}

export default Rating;

