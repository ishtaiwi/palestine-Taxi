import supabase from '../config/dbcon.js';
import { v4 as uuidv4 } from 'uuid';


const ACTIVE_STATUS = 'waiting';

class DriverQueue {
  static async getActiveByLine(lineid, direction = null) {
    let query = supabase
      .from('driver_queue')
      .select(`
        queueid,
        driverid,
        lineid,
        status,
        joined_at,
        direction,
        stationid,
        driver (
          driverid,
          licenseid,
          lineid,
          user!driver_userid_fkey (
            userid,
            fullname,
            phone,
            email
          )
        )
      `)
      .eq('lineid', lineid)
      .eq('status', ACTIVE_STATUS);

    if (direction) {
      query = query.eq('direction', direction);
    }

    const { data, error } = await query.order('joined_at', { ascending: true });

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
        joined_at,
        direction,
        stationid
      `)
      .eq('driverid', driverid)
      .eq('status', ACTIVE_STATUS)
      .maybeSingle();

    if (error && error.code !== 'PGRST116') throw error;
    return data;
  }

  static async join(driverid, lineid, direction = 'going', stationid = null) {
    // First, remove driver from any existing queue
    await this.leaveAllQueues(driverid);

    const queueData = {
      queueid: uuidv4(),
      driverid,
      lineid,
      status: ACTIVE_STATUS,
      direction,
    };

    if (stationid) {
      queueData.stationid = stationid;
    }

    const { data, error } = await supabase
      .from('driver_queue')
      .insert([queueData])
      .select(`
        queueid,
        driverid,
        lineid,
        status,
        joined_at,
        direction,
        stationid,
        driver (
          driverid,
          licenseid,
          lineid,
          user!driver_userid_fkey (
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

  /**
   * Leave all queues for a driver
   * @param {string} driverid - Driver ID
   * @returns {Promise<boolean>} - Success status
   */
  static async leaveAllQueues(driverid) {
    const { error } = await supabase
      .from('driver_queue')
      .update({
        status: 'left',
        left_at: new Date().toISOString(),
      })
      .eq('driverid', driverid)
      .eq('status', ACTIVE_STATUS);

    if (error) throw error;
    return true;
  }

  /**
   * Get active queue by line and direction
   * @param {string} lineid - Line ID
   * @param {string} direction - 'going' or 'returning'
   * @returns {Promise<Array>} - Array of queue entries
   */
  static async getActiveByLineAndDirection(lineid, direction) {
    return await this.getActiveByLine(lineid, direction);
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


  static async removeDriverFromQueue(driverid) {
    return await this.leaveActiveByDriver(driverid);
  }


  static async deleteByDriverId(driverid) {
    const { error } = await supabase
      .from('driver_queue')
      .delete()
      .eq('driverid', driverid);

    if (error) throw error;
    return true;
  }


  static async getQueuePosition(driverid) {
    const queueEntry = await this.findActiveByDriver(driverid);
    if (!queueEntry) {
      return null;
    }

    const queue = await this.getActiveByLine(queueEntry.lineid, queueEntry.direction);
    const position = queue.findIndex(entry => entry.driverid === driverid);

    return position >= 0 ? position + 1 : null;
  }

  /**
   * Check if there are any drivers available in the queue for a specific line
   * @param {string} lineid - The line ID to check
   * @returns {Promise<boolean>} - True if at least one driver is available
   */
  static async hasAvailableDrivers(lineid, direction = null) {
    const queue = await this.getActiveByLine(lineid, direction);
    return queue && queue.length > 0;
  }

  /**
   * Get the count of available drivers in the queue for a specific line
   * @param {string} lineid - The line ID to check
   * @returns {Promise<number>} - Number of drivers in queue
   */
  static async getQueueCount(lineid, direction = null) {
    const queue = await this.getActiveByLine(lineid, direction);
    return queue ? queue.length : 0;
  }

  /**
   * Check if instant booking is allowed for a line
   * Instant booking is allowed only if there are drivers available in the queue
   * @param {string} lineid - The line ID to check
   * @returns {Promise<{allowed: boolean, driversAvailable: number, message?: string}>}
   */
  static async canAcceptInstantBooking(lineid, direction = null) {
    const queue = await this.getActiveByLine(lineid, direction);
    const driversAvailable = queue ? queue.length : 0;

    if (driversAvailable === 0) {
      return {
        allowed: false,
        driversAvailable: 0,
        message: 'No drivers available in queue. Please try again later or book a scheduled trip.',
      };
    }

    return {
      allowed: true,
      driversAvailable,
    };
  }
}

export default DriverQueue;

