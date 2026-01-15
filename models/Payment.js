import supabase from '../config/dbcon.js';

class Payment {
  static async create(paymentData) {
    const { data, error } = await supabase
      .from('payment')
      .insert([paymentData])
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findById(paymentid) {
    const { data, error } = await supabase
      .from('payment')
      .select('*, fromwallet:wallet!payment_fromwalletid_fkey(*), towallet:wallet!payment_towalletid_fkey(*)')
      .eq('paymentid', paymentid)
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findByWalletId(walletid) {
    const { data, error } = await supabase
      .from('payment')
      .select('*')
      .or(`fromwalletid.eq.${walletid},towalletid.eq.${walletid}`)
      .order('time', { ascending: false });
    
    if (error) throw error;
    return data;
  }

  static async findByTripid(tripid) {
    const { data, error } = await supabase
      .from('payment')
      .select('*')
      .eq('tripid', tripid)
      .order('time', { ascending: false });
    
    if (error) throw error;
    return data;
  }

  static async update(paymentid, updates) {
    const { data, error } = await supabase
      .from('payment')
      .update(updates)
      .eq('paymentid', paymentid)
      .select()
      .single();
    
    if (error) throw error;
    return data;
  }

  static async findAll(filters = {}) {
    let query = supabase.from('payment').select('*');
    
    if (filters.status) {
      query = query.eq('status', filters.status);
    }
    
    if (filters.method) {
      query = query.eq('method', filters.method);
    }
    
    if (filters.type) {
      query = query.eq('type', filters.type);
    }
    
    const { data, error } = await query.order('time', { ascending: false });
    if (error) throw error;
    return data;
  }

  static async findByStripeIntentId(stripePaymentIntentId) {
    const { data, error } = await supabase
      .from('payment')
      .select('*')
      .eq('stripe_payment_intent_id', stripePaymentIntentId)
      .maybeSingle();

    if (error && error.code !== 'PGRST116') {
      
      throw error;
    }

    return data || null;
  }

  static async deleteByWalletId(walletid) {
    const { error } = await supabase
      .from('payment')
      .delete()
      .or(`fromwalletid.eq.${walletid},towalletid.eq.${walletid}`);
    
    if (error) throw error;
    return true;
  }

  static async deleteByWalletIds(walletIds) {
    if (!walletIds || walletIds.length === 0) {
      return true;
    }
    
    const conditions = walletIds.map(id => `fromwalletid.eq.${id},towalletid.eq.${id}`).join(',');
    
    const { error } = await supabase
      .from('payment')
      .delete()
      .or(conditions);
    
    if (error) throw error;
    return true;
  }
}

export default Payment;

