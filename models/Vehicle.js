import supabase from '../config/dbcon.js';

class Vehicle {
  static async create(vehicleData) {
    // Clean up the data - ensure all fields are properly formatted
    const cleanData = { ...vehicleData };
    
    console.log('[Vehicle.create] 📥 Received vehicle data:', {
      vehicleid: cleanData.vehicleid,
      driverid: cleanData.driverid,
      lineid: cleanData.lineid,
      seatnum: cleanData.seatnum,
      seatnumType: typeof cleanData.seatnum,
      seatlayout: cleanData.seatlayout,
      seatlayoutType: typeof cleanData.seatlayout,
      plateno: cleanData.plateno,
      platenoType: typeof cleanData.plateno,
      status: cleanData.status,
      broken_seats: cleanData.broken_seats,
    });
    
    // Remove null/undefined values that might cause issues (but keep null for plateno if needed)
    Object.keys(cleanData).forEach(key => {
      if (cleanData[key] === undefined) {
        delete cleanData[key];
      }
    });
    
    // Ensure plateno is either a valid string or null (not empty string)
    if (cleanData.plateno === '' || cleanData.plateno === undefined) {
      // Set to null explicitly - column is now nullable after migration
      cleanData.plateno = null;
    }
    
    // Ensure seatnum is a number
    if (typeof cleanData.seatnum !== 'number') {
      cleanData.seatnum = parseInt(cleanData.seatnum, 10) || 5;
    }
    
    // Ensure seatlayout is a string
    if (typeof cleanData.seatlayout !== 'string') {
      cleanData.seatlayout = String(cleanData.seatlayout || '4+1');
    }
    
    // Ensure status is a string
    if (typeof cleanData.status !== 'string') {
      cleanData.status = String(cleanData.status || 'active');
    }
    
    // Handle broken_seats - only include if it's a valid array
    if (Array.isArray(cleanData.broken_seats)) {
      if (cleanData.broken_seats.length === 0) {
        // Empty array - try to include it, but we'll handle error if column doesn't exist
      }
    } else if (cleanData.broken_seats !== undefined) {
      // Not an array - remove it
      delete cleanData.broken_seats;
    }
    
    console.log('[Vehicle.create] 🧹 Cleaned vehicle data:', cleanData);
    
    const { data, error } = await supabase
      .from('vehicle')
      .insert([cleanData])
      .select()
      .single();
    
    if (error) {
      console.error('[Vehicle.create] ❌ Supabase error:', {
        code: error.code,
        message: error.message,
        details: error.details,
        hint: error.hint,
        cleanData: cleanData,
      });
      
      // If error is about broken_seats column, try without it
      if (error.code === '42703' || (error.message && error.message.includes('broken_seats'))) {
        console.log('[Vehicle.create] 🔄 Retrying without broken_seats column');
        const retryData = { ...cleanData };
        delete retryData.broken_seats;
        
        const { data: retryResult, error: retryError } = await supabase
          .from('vehicle')
          .insert([retryData])
          .select()
          .single();
        
        if (retryError) {
          console.error('[Vehicle.create] ❌ Retry error:', {
            code: retryError.code,
            message: retryError.message,
            details: retryError.details,
            hint: retryError.hint,
            retryData: retryData,
          });
          throw retryError;
        }
        console.log('[Vehicle.create] ✅ Vehicle created successfully (without broken_seats)');
        return retryResult;
      }
      
      throw error;
    }
    
    console.log('[Vehicle.create] ✅ Vehicle created successfully');
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

