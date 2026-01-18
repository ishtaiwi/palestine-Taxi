import supabase from '../config/dbcon.js';

class User {
  static async create(userData) {
    const { data, error } = await supabase
      .from('user')
      .insert([userData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(userid, includePassword = false) {
    const { data, error } = await supabase
      .from('user')
      .select('*')
      .eq('userid', userid)
      .single();
    
    if (error) throw error;
    
    
    if (!includePassword && data && data.password) {
      delete data.password;
    }
    
    return data;
  }

  static async findByEmail(email) {
    const { data, error } = await supabase
      .from('user')
      .select('*')
      .eq('email', email)
      .single();
    
    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async findByPhone(phone) {
    const { data, error } = await supabase
      .from('user')
      .select('*')
      .eq('phone', phone)
      .single();
    
    if (error && error.code !== 'PGRST116') throw error;
    if (data && data.password) {
      delete data.password;
    }
    return data;
  }

  static async update(userid, updates) {
    const { data, error } = await supabase
      .from('user')
      .update(updates)
      .eq('userid', userid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async delete(userid) {
    const { error } = await supabase
      .from('user')
      .delete()
      .eq('userid', userid);
    
    if (error) throw error;
    return true;
  }

  static async findAll(filters = {}) {
    let query = supabase.from('user').select('*');
    
    if (filters.role) {
      query = query.eq('role', filters.role);
    }
    
    const { data, error } = await query;
    if (error) throw error;
    
    
    if (data && Array.isArray(data)) {
      data.forEach(user => {
        if (user.password) delete user.password;
      });
    }
    
    return data;
  }
}

export default User;

