import supabase from '../config/dbcon.js';

class UserFcmToken {
  static async create(tokenData) {
    const { data, error } = await supabase
      .from('user_fcm_tokens')
      .insert([tokenData])
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async findById(tokenid) {
    const { data, error } = await supabase
      .from('user_fcm_tokens')
      .select('*')
      .eq('tokenid', tokenid)
      .single();

    if (error) throw error;
    return data;
  }

  static async findByUserId(userid, activeOnly = true) {
    let query = supabase
      .from('user_fcm_tokens')
      .select('*')
      .eq('userid', userid);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    const { data, error } = await query.order('last_used_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  static async findByToken(fcmToken) {
    const { data, error } = await supabase
      .from('user_fcm_tokens')
      .select('*')
      .eq('fcm_token', fcmToken)
      .single();

    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async updateLastUsed(tokenid) {
    const { data, error } = await supabase
      .from('user_fcm_tokens')
      .update({
        last_used_at: new Date().toISOString(),
      })
      .eq('tokenid', tokenid)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async update(tokenid, updates) {
    const { data, error } = await supabase
      .from('user_fcm_tokens')
      .update(updates)
      .eq('tokenid', tokenid)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async deactivate(tokenid) {
    const { data, error } = await supabase
      .from('user_fcm_tokens')
      .update({
        is_active: false,
      })
      .eq('tokenid', tokenid)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async deactivateAllForUser(userid) {
    const { data, error } = await supabase
      .from('user_fcm_tokens')
      .update({
        is_active: false,
      })
      .eq('userid', userid)
      .eq('is_active', true)
      .select();

    if (error) throw error;
    return data || [];
  }

  static async delete(tokenid) {
    const { error } = await supabase
      .from('user_fcm_tokens')
      .delete()
      .eq('tokenid', tokenid);

    if (error) throw error;
    return true;
  }

  static async upsert(tokenData) {
    // Try to find existing token
    const existing = await this.findByToken(tokenData.fcm_token);
    
    if (existing) {
      // Update existing token
      return await this.update(existing.tokenid, {
        userid: tokenData.userid,
        device_type: tokenData.device_type,
        device_id: tokenData.device_id,
        last_used_at: new Date().toISOString(),
        is_active: true,
      });
    } else {
      // Create new token
      return await this.create(tokenData);
    }
  }
}

export default UserFcmToken;
