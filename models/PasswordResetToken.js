import supabase from '../config/dbcon.js';

class PasswordResetToken {
  static async create({ userid, token, expiresAt }) {
    const { data, error } = await supabase
      .from('password_reset_token')
      .insert([{
        userid,
        token,
        expires_at: expiresAt,
      }])
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  static async invalidateAllForUser(userid) {
    const { error } = await supabase
      .from('password_reset_token')
      .update({ used: true })
      .eq('userid', userid)
      .eq('used', false);

    if (error) throw error;
    return true;
  }

  static async findValid(token) {
    const now = new Date().toISOString();
    const { data, error } = await supabase
      .from('password_reset_token')
      .select('*')
      .eq('token', token)
      .eq('used', false)
      .gte('expires_at', now)
      .single();

    if (error) return null;
    return data;
  }

  static async markUsed(id) {
    const { data, error } = await supabase
      .from('password_reset_token')
      .update({ used: true })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    return data;
  }
}

export default PasswordResetToken;

