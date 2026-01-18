import supabase from '../config/dbcon.js';

class PredictionModel {
    /**
     * Build a composite key for line + direction
     * @param {string} lineid - Line ID
     * @param {string} direction - Direction ('going' or 'return')
     * @returns {string} Composite key
     */
    static buildModelKey(lineid, direction = 'going') {
        return `${lineid}_${direction}`;
    }

    /**
     * Parse a composite key back to lineid and direction
     * @param {string} modelKey - Composite key
     * @returns {{lineid: string, direction: string}}
     */
    static parseModelKey(modelKey) {
        const parts = modelKey.split('_');
        const direction = parts.pop(); // Last part is direction
        const lineid = parts.join('_'); // Rest is lineid (in case lineid contains underscores)
        return { lineid, direction };
    }

    static async findByLineId(lineid) {
        const { data, error } = await supabase
            .from('prediction_model')
            .select('*')
            .eq('lineid', lineid)
            .single();

        if (error && error.code !== 'PGRST116') throw error;
        return data;
    }

    /**
     * Find model by line ID and direction
     * @param {string} lineid - Line ID
     * @param {string} direction - Direction ('going' or 'return')
     */
    static async findByLineAndDirection(lineid, direction = 'going') {
        const modelKey = this.buildModelKey(lineid, direction);
        return this.findByLineId(modelKey);
    }

    /**
     * Find all models for a specific line (both directions)
     * @param {string} lineid - Line ID
     */
    static async findAllByLine(lineid) {
        const { data, error } = await supabase
            .from('prediction_model')
            .select('*')
            .like('lineid', `${lineid}_%`)
            .order('last_trained_at', { ascending: false });

        if (error) throw error;
        return data || [];
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

    /**
     * Upsert model by line ID (supports direction in the lineid field)
     */
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

    /**
     * Upsert model by line ID and direction
     * @param {string} lineid - Line ID
     * @param {string} direction - Direction ('going' or 'return')
     * @param {Object} modelData - Model data
     */
    static async upsertByLineAndDirection(lineid, direction, modelData) {
        const modelKey = this.buildModelKey(lineid, direction);
        return this.upsert(modelKey, modelData);
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

