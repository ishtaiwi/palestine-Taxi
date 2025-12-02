import supabase from '../config/dbcon.js';

class Line {
  static async create(lineData) {
    const { data, error } = await supabase
      .from('line')
      .insert([lineData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(lineid) {
    const { data, error } = await supabase
      .from('line')
      .select('*')
      .eq('lineid', lineid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase.from('line').select('*');
    
    if (filters.active !== undefined) {
      query = query.eq('active', filters.active);
    }
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }

  static async update(lineid, updates) {
    const { data, error } = await supabase
      .from('line')
      .update(updates)
      .eq('lineid', lineid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async delete(lineid) {
    const { error } = await supabase
      .from('line')
      .delete()
      .eq('lineid', lineid);
    
    if (error) throw error;
    return true;
  }

  static async getActiveLines() {
    const { data, error } = await supabase
      .from('line')
      .select('*')
      .eq('active', true);
    
    if (error) throw error;
    return data;
  }
}

export default Line;

