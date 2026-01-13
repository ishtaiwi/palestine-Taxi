import supabase from '../config/dbcon.js';

class Notification {
  static async create(notificationData) {
    const { data, error } = await supabase
      .from('notifications')
      .insert([notificationData])
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async findById(notificationid) {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('notificationid', notificationid)
      .single();

    if (error) throw error;
    return data;
  }

  static async findByUserId(userid, filters = {}) {
    let query = supabase
      .from('notifications')
      .select('*')
      .eq('userid', userid);

    if (filters.read !== undefined) {
      query = query.eq('read', filters.read);
    }

    if (filters.type) {
      query = query.eq('type', filters.type);
    }

    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }

  static async getUnreadCount(userid) {
    const { count, error } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('userid', userid)
      .eq('read', false);

    if (error) throw error;
    return count || 0;
  }

  static async markAsRead(notificationid) {
    const { data, error } = await supabase
      .from('notifications')
      .update({
        read: true,
        read_at: new Date().toISOString(),
      })
      .eq('notificationid', notificationid)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async markAllAsRead(userid) {
    const { data, error } = await supabase
      .from('notifications')
      .update({
        read: true,
        read_at: new Date().toISOString(),
      })
      .eq('userid', userid)
      .eq('read', false)
      .select();

    if (error) throw error;
    return data || [];
  }

  static async update(notificationid, updates) {
    const { data, error } = await supabase
      .from('notifications')
      .update(updates)
      .eq('notificationid', notificationid)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async delete(notificationid) {
    const { error } = await supabase
      .from('notifications')
      .delete()
      .eq('notificationid', notificationid);

    if (error) throw error;
    return true;
  }

  static async findAll(filters = {}) {
    let query = supabase.from('notifications').select('*');

    if (filters.userid) {
      query = query.eq('userid', filters.userid);
    }

    if (filters.read !== undefined) {
      query = query.eq('read', filters.read);
    }

    if (filters.type) {
      query = query.eq('type', filters.type);
    }

    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) throw error;
    return data || [];
  }
}

export default Notification;
