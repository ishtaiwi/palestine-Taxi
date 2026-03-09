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

  /**
   * Get main station for a line
   * @param {string} lineid - Line ID
   * @returns {Promise<Object|null>} - Base station object or null
   */
  static async getMainStation(lineid) {
    const line = await this.findById(lineid);
    if (!line || !line.main_stationid) {
      return null;
    }

    const BaseStation = (await import('./BaseStation.js')).default;
    return await BaseStation.findById(line.main_stationid);
  }

  /**
   * Get return station for a line
   * @param {string} lineid - Line ID
   * @returns {Promise<Object|null>} - Base station object or null
   */
  static async getReturnStation(lineid) {
    const line = await this.findById(lineid);
    if (!line || !line.return_stationid) {
      return null;
    }

    const BaseStation = (await import('./BaseStation.js')).default;
    return await BaseStation.findById(line.return_stationid);
  }

  /**
   * Get station for a specific direction
   * @param {string} lineid - Line ID
   * @param {string} direction - 'going' or 'returning'
   * @returns {Promise<Object|null>} - Base station object or null
   */
  static async getStationForDirection(lineid, direction) {
    if (direction === 'going') {
      return await this.getMainStation(lineid);
    } else if (direction === 'returning') {
      return await this.getReturnStation(lineid);
    }
    return null;
  }
}

export default Line;

