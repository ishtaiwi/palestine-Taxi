import supabase from '../config/dbcon.js';

class Wallet {
  static async create(walletData) {
    const { data, error } = await supabase
      .from('wallet')
      .insert([walletData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(walletid) {
    const { data, error } = await supabase
      .from('wallet')
      .select('*, user(*)')
      .eq('walletid', walletid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByUserId(userid, type = null) {
    let query = supabase
      .from('wallet')
      .select('*, user(*)')
      .eq('userid', userid);
    
    if (type) {
      query = query.eq('type', type);
    }
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }

  static async updateBalance(walletid, amount, operation = 'add') {
    const wallet = await this.findById(walletid);
    const newBalance = operation === 'add' 
      ? (wallet.balance || 0) + amount 
      : (wallet.balance || 0) - amount;
    
    const { data, error } = await supabase
      .from('wallet')
      .update({ balance: newBalance })
      .eq('walletid', walletid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async update(walletid, updates) {
    const { data, error } = await supabase
      .from('wallet')
      .update(updates)
      .eq('walletid', walletid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async deleteByUserId(userid) {
    const { error } = await supabase
      .from('wallet')
      .delete()
      .eq('userid', userid);
    
    if (error) throw error;
    return true;
  }
}

export default Wallet;

