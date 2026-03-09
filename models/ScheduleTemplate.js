import supabase from '../config/dbcon.js';

class ScheduleTemplate {
  static async create(templateData) {
    const { data, error } = await supabase
      .from('schedule_template')
      .insert([templateData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(templateid) {
    const { data, error } = await supabase
      .from('schedule_template')
      .select('*, line(*)')
      .eq('templateid', templateid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase
      .from('schedule_template')
      .select('*, line(*)');
    
    if (filters.lineid) {
      query = query.eq('lineid', filters.lineid);
    }
    
    if (filters.active !== undefined) {
      query = query.eq('active', filters.active);
    }
    
    if (filters.direction) {
      query = query.eq('direction', filters.direction);
    }
    
    const { data, error } = await query.order('start_hour', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async findByLineId(lineid, direction = null) {
    let query = supabase
      .from('schedule_template')
      .select('*, line(*)')
      .eq('lineid', lineid)
      .eq('active', true);
    
    if (direction) {
      query = query.eq('direction', direction);
    }
    
    const { data, error } = await query.order('start_hour', { ascending: true });
    if (error) throw error;
    return data;
  }

  static async existsForLine(lineid, direction = null) {
    let query = supabase
      .from('schedule_template')
      .select('templateid')
      .eq('lineid', lineid);
    
    if (direction) {
      query = query.eq('direction', direction);
    }
    
    const { data, error } = await query.limit(1).single();
    
    if (error && error.code !== 'PGRST116') throw error; // PGRST116 is "not found" which is fine
    return data !== null;
  }

  static async getActiveTemplates() {
    const { data, error } = await supabase
      .from('schedule_template')
      .select('*, line(*)')
      .eq('active', true)
      .order('start_hour', { ascending: true });
    
    if (error) throw error;
    return data;
  }

  static async update(templateid, updates) {
    const updateData = {
      ...updates,
      updated_at: new Date().toISOString(),
    };
    
    const { data, error } = await supabase
      .from('schedule_template')
      .update(updateData)
      .eq('templateid', templateid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async delete(templateid) {
    const { error } = await supabase
      .from('schedule_template')
      .delete()
      .eq('templateid', templateid);
    
    if (error) throw error;
    return true;
  }
}

export default ScheduleTemplate;

