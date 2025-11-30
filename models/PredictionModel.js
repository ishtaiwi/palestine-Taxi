import supabase from '../config/dbcon.js';

class PredictionModel {
  static async findByLineId(lineid) {
    const { data, error } = await supabase
      .from('prediction_model')
      .select('*')
      .eq('lineid', lineid)
      .single();

    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async findAll() {
    const { data, error } = await supabase
      .from('prediction_model')
      .select('*')
      .order('last_trained_at', { ascending: false });

    if (error) throw error;
    return data;
  }

  static async create(modelData) {
    const { data, error } = await supabase
      .from('prediction_model')
      .insert([{
        ...modelData,
        updated_at: new Date().toISOString(),
      }])
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async update(lineid, modelData) {
    const { data, error } = await supabase
      .from('prediction_model')
      .update({
        ...modelData,
        updated_at: new Date().toISOString(),
      })
      .eq('lineid', lineid)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async upsert(lineid, modelData) {
    const existing = await this.findByLineId(lineid);
    
    if (existing) {
      return await this.update(lineid, modelData);
    } else {
      return await this.create({
        lineid,
        ...modelData,
      });
    }
  }

  static async delete(lineid) {
    const { error } = await supabase
      .from('prediction_model')
      .delete()
      .eq('lineid', lineid);

    if (error) throw error;
    return true;
  }

  static async deleteAll() {
    const { error } = await supabase
      .from('prediction_model')
      .delete()
      .neq('modelid', '00000000-0000-0000-0000-000000000000'); // Delete all

    if (error) throw error;
    return true;
  }
}

export default PredictionModel;

