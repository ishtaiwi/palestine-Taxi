import supabase from '../config/dbcon.js';
import { v4 as uuidv4 } from 'uuid';

const ACTIVE_STATUS = 'waiting';

class DriverQueue {
  static async getActiveByLine(lineid) {
    const { data, error } = await supabase
      .from('driver_queue')
      .select(`
        queueid,
        driverid,
        lineid,
        status,
        joined_at,
        driver:driverid (
          driverid,
          licenseid,
          lineid,
          user:userid (
            userid,
            fullname,
            phone,
            email
          )
        )
      `)
      .eq('lineid', lineid)
      .eq('status', ACTIVE_STATUS)
      .order('joined_at', { ascending: true });

    if (error) throw error;
    return data || [];
  }

  static async findActiveByDriver(driverid) {
    const { data, error } = await supabase
      .from('driver_queue')
      .select(`
        queueid,
        driverid,
        lineid,
        status,
        joined_at
      `)
      .eq('driverid', driverid)
      .eq('status', ACTIVE_STATUS)
      .maybeSingle();

    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async join(driverid, lineid) {
    const { data, error } = await supabase
      .from('driver_queue')
      .insert([
        {
          queueid: uuidv4(),
          driverid,
          lineid,
          status: ACTIVE_STATUS,
        },
      ])
      .select(`
        queueid,
        driverid,
        lineid,
        status,
        joined_at,
        driver:driverid (
          driverid,
          licenseid,
          lineid,
          user:userid (
            userid,
            fullname,
            phone,
            email
          )
        )
      `)
      .single();

    if (error) throw error;
    return data;
  }

  static async leaveActiveByDriver(driverid) {
    const { data, error } = await supabase
      .from('driver_queue')
      .update({
        status: 'left',
        left_at: new Date().toISOString(),
      })
      .eq('driverid', driverid)
      .eq('status', ACTIVE_STATUS)
      .select('queueid, driverid, lineid, status, joined_at, left_at')
      .maybeSingle();

    if (error) throw error;
    return data;
  }
}

export default DriverQueue;

