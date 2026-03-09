import supabase from '../config/dbcon.js';
import logger from '../utils/logger.js';

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
    // Get payments with trip information using Supabase foreign key join
    const { data: payments, error } = await supabase
      .from('payment')
      .select(`
        *,
        trip:tripid(
          deptime,
          assigned_driverid,
          vehicle:vehicleid(
            driver:driverid(
              user!driver_userid_fkey(
                fullname
              )
            )
          )
        )
      `)
      .or(`fromwalletid.eq.${walletid},towalletid.eq.${walletid}`)
      .order('time', { ascending: false });

    if (error) {
      logger.error(`[Payment] Error fetching payments for wallet ${walletid}:`, error);
      throw error;
    }
    if (!payments || payments.length === 0) return [];

    // Enrich payments with reservation, passenger, and driver information
    const enrichedPayments = await Promise.all(
      payments.map(async (payment) => {
        const enriched = { ...payment };
        
        // Extract trip time and date from trip if available
        if (payment.trip && payment.trip.deptime) {
          try {
            const deptime = new Date(payment.trip.deptime);
            enriched.trip_time = deptime.toTimeString().slice(0, 5); // HH:MM format
            enriched.trip_date = deptime.toISOString().split('T')[0]; // YYYY-MM-DD format
            enriched.trip_datetime = deptime.toISOString(); // Full datetime for formatting
          } catch (dateError) {
            logger.warn(`[Payment] Error parsing trip deptime for payment ${payment.paymentid}:`, dateError);
          }
        }

        // Get driver name for payments (type='reservation') - money goes to driver
        if (payment.type === 'reservation' && payment.trip) {
          try {
            // Try to get driver from vehicle first
            if (payment.trip.vehicle?.driver?.user?.fullname) {
              enriched.driver_name = payment.trip.vehicle.driver.user.fullname;
            } else if (payment.trip.assigned_driverid) {
              // Fallback: get driver directly if assigned_driverid exists
              const { data: driver, error: driverError } = await supabase
                .from('driver')
                .select(`
                  userid,
                  user:userid!driver_userid_fkey(
                    fullname
                  )
                `)
                .eq('driverid', payment.trip.assigned_driverid)
                .single();

              if (!driverError && driver?.user?.fullname) {
                enriched.driver_name = driver.user.fullname;
              }
            }
          } catch (driverError) {
            logger.warn(`[Payment] Error fetching driver for payment ${payment.paymentid}:`, driverError);
          }
        }

        // Get driver name for refunds - refund comes from driver's wallet
        if (payment.type === 'refund' && payment.fromwalletid) {
          try {
            // Get driver from the fromwalletid (driver's wallet)
            // First get the wallet to find the userid
            const { data: driverWallet, error: walletError } = await supabase
              .from('wallet')
              .select('userid')
              .eq('walletid', payment.fromwalletid)
              .single();

            if (!walletError && driverWallet?.userid) {
              // Now get the driver associated with this user
              const { data: driver, error: driverError } = await supabase
                .from('driver')
                .select(`
                  userid,
                  user:userid!driver_userid_fkey(
                    fullname
                  )
                `)
                .eq('userid', driverWallet.userid)
                .maybeSingle();

              if (!driverError && driver?.user?.fullname) {
                enriched.driver_name = driver.user.fullname;
              } else if (!driverError && driverWallet.userid) {
                // Fallback: if no driver found, get user name directly
                const { data: user, error: userError } = await supabase
                  .from('user')
                  .select('fullname')
                  .eq('userid', driverWallet.userid)
                  .single();

                if (!userError && user?.fullname) {
                  enriched.driver_name = user.fullname;
                }
              }
            }
          } catch (refundDriverError) {
            logger.warn(`[Payment] Error fetching driver for refund payment ${payment.paymentid}:`, refundDriverError);
          }
        }

        // Get trip information for refunds to show which trip was cancelled
        // Also try to get driver from trip if not found from wallet
        if (payment.type === 'refund' && payment.tripid) {
          try {
            // Trip info is already included in the initial query, but ensure we have it
            if (payment.trip && payment.trip.deptime) {
              // Trip info already extracted above
              enriched.cancelled_trip_id = payment.tripid;
              
              // If we don't have driver_name yet, try to get it from the trip
              if (!enriched.driver_name && payment.trip.vehicle?.driver?.user?.fullname) {
                enriched.driver_name = payment.trip.vehicle.driver.user.fullname;
              } else if (!enriched.driver_name && payment.trip.assigned_driverid) {
                // Fallback: get driver directly if assigned_driverid exists
                const { data: driver, error: driverError } = await supabase
                  .from('driver')
                  .select(`
                    userid,
                    user:userid!driver_userid_fkey(
                      fullname
                    )
                  `)
                  .eq('driverid', payment.trip.assigned_driverid)
                  .single();

                if (!driverError && driver?.user?.fullname) {
                  enriched.driver_name = driver.user.fullname;
                }
              }
            }
          } catch (tripError) {
            logger.warn(`[Payment] Error fetching trip for refund payment ${payment.paymentid}:`, tripError);
          }
        }

        // Get passenger name from reservation (for trip payments and refunds)
        if (payment.paymentid) {
          try {
            const { data: reservations, error: reservationError } = await supabase
              .from('reservation')
              .select(`
                passengerid,
                bookingid,
                passenger:passengerid(
                  userid,
                  user:userid(
                    fullname
                  )
                )
              `)
              .eq('paymentid', payment.paymentid)
              .limit(1);

            if (reservationError) {
              logger.warn(`[Payment] Error fetching reservation for payment ${payment.paymentid}:`, reservationError);
            } else if (reservations && reservations.length > 0 && reservations[0].passenger) {
              enriched.passenger_name = reservations[0].passenger.user?.fullname || null;
              enriched.bookingid = reservations[0].bookingid || null;
            }
          } catch (reservationError) {
            // Silently fail if reservation lookup fails
            logger.warn(`[Payment] Error fetching reservation for payment ${payment.paymentid}:`, reservationError);
          }
        }

        // For refunds, also try to get passenger name from the destination wallet (towalletid)
        // if we didn't get it from reservation (some refunds might not have a reservation)
        if (!enriched.passenger_name && payment.type === 'refund' && payment.towalletid) {
          try {
            const { data: wallet, error: walletError } = await supabase
              .from('wallet')
              .select(`
                userid,
                user:userid(
                  fullname
                )
              `)
              .eq('walletid', payment.towalletid)
              .single();

            if (!walletError && wallet && wallet.user) {
              enriched.passenger_name = wallet.user.fullname || null;
            }
          } catch (walletError) {
            // Silently fail if wallet lookup fails
            logger.warn(`[Payment] Error fetching wallet user for refund payment ${payment.paymentid}:`, walletError);
          }
        }

        // Clean up the nested trip object
        if (enriched.trip) {
          delete enriched.trip;
        }

        return enriched;
      })
    );

    return enrichedPayments;
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

  static async findByTripId(tripid) {
    const { data, error } = await supabase
      .from('payment')
      .select('*')
      .eq('tripid', tripid);

    if (error) throw error;
    return data || [];
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

