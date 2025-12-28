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
      .select('*, user!driver_userid_fkey(*), line(*)')
      .eq('driverid', driverid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByUserId(userid) {
    const { data, error } = await supabase
      .from('driver')
      .select('*, user!driver_userid_fkey(*), line(*)')
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

  static async updateByFilter(filter, updates) {
    let query = supabase.from('driver').update(updates);
    
    Object.entries(filter).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
    
    const { data, error } = await query.select();
    
    if (error) throw error;
    return data || [];
  }

  static async findAll(filters = {}) {
    let query = supabase.from('driver').select('*, user!driver_userid_fkey(*)');
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    if (filters.approval_status) {
      query = query.eq('approval_status', filters.approval_status);
    }
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }

  static async findByApprovalStatus(approvalStatus) {
    const { data, error } = await supabase
      .from('driver')
      .select('*, user!driver_userid_fkey(*), line(*)')
      .eq('approval_status', approvalStatus);
    
    if (error) throw error;
    return data || [];
  }

  static async findPendingDrivers() {
    return this.findByApprovalStatus('pending');
  }

  static async findByLicenseId(licenseid) {
    const { data, error } = await supabase
      .from('driver')
      .select('*, user!driver_userid_fkey(*), line(*)')
      .eq('licenseid', licenseid)
      .maybeSingle();
    
    if (error && error.code !== 'PGRST116') throw error;
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

  static async delete(driverid) {
    const { error } = await supabase
      .from('driver')
      .delete()
      .eq('driverid', driverid);
    
    if (error) throw error;
    return true;
  }
}

export default Driver;

