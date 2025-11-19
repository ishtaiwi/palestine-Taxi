import supabase from '../config/dbcon.js';

class Admin {
  static async create(adminData) {
    const { data, error } = await supabase
      .from('admin')
      .insert([adminData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(id) {
    const { data, error } = await supabase
      .from('admin')
      .select('*, user(*)')
      .eq('id', id)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByUserId(userid) {
    const { data, error } = await supabase
      .from('admin')
      .select('*, user(*)')
      .eq('userid', userid)
      .single();
    
    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async update(id, updates) {
    const { data, error } = await supabase
      .from('admin')
      .update(updates)
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async updatePermissions(id, permissions) {
    const { data, error } = await supabase
      .from('admin')
      .update({ permissions })
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll() {
    const { data, error } = await supabase
      .from('admin')
      .select('*, user(*)');
    
    if (error) throw error;
    return data;
  }

  static async hasPermission(userid, permission) {
    const admin = await this.findByUserId(userid);
    if (!admin) return false;
    return admin.permissions && admin.permissions.includes(permission);
  }
}

export default Admin;

