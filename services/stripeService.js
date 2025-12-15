import Stripe from 'stripe';
import dotenv from 'dotenv';
import logger from '../utils/logger.js';

dotenv.config();

const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

if (!stripeSecretKey) {
  logger.warn(
    'Stripe secret key (STRIPE_SECRET_KEY) is not configured. Stripe operations will fail.',
  );
}

const stripe = stripeSecretKey ? new Stripe(stripeSecretKey) : null;


export const createPaymentIntent = async (amount, currency = 'ils', userId, walletId) => {
  if (!stripe) {
    throw new Error('Stripe is not configured. Please set STRIPE_SECRET_KEY in environment.');
  }

  if (!amount || amount <= 0) {
    throw new Error('Amount must be greater than 0');
  }

  try {
    
    const amountInMinorUnits = Math.round(amount * 100);

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInMinorUnits,
      currency: currency.toLowerCase(),
      metadata: {
        userId: userId || '',
        walletId: walletId || '',
        type: 'wallet_topup',
      },
      description: `Wallet top-up for user ${userId || 'unknown'}`,
      automatic_payment_methods: {
        enabled: true,
      },
    });

    return paymentIntent;
  } catch (error) {
    logger.error('Stripe createPaymentIntent failed', {
      message: error.message,
      code: error.code,
      type: error.type,
    });
    throw new Error(`Stripe payment intent creation failed: ${error.message}`);
  }
};


export const getPaymentIntent = async (paymentIntentId) => {
  if (!stripe) {
    throw new Error('Stripe is not configured. Please set STRIPE_SECRET_KEY in environment.');
  }

  if (!paymentIntentId) {
    throw new Error('paymentIntentId is required');
  }

  try {
    return await stripe.paymentIntents.retrieve(paymentIntentId);
  } catch (error) {
    logger.error('Stripe getPaymentIntent failed', {
      message: error.message,
      code: error.code,
      type: error.type,
      paymentIntentId,
    });
    throw new Error(`Failed to retrieve payment intent: ${error.message}`);
  }
};


export const verifyWebhook = (payload, signature) => {
  if (!stripe) {
    throw new Error('Stripe is not configured. Please set STRIPE_SECRET_KEY in environment.');
  }

  if (!stripeWebhookSecret) {
    throw new Error(
      'Stripe webhook secret (STRIPE_WEBHOOK_SECRET) is not configured. Cannot verify webhooks.',
    );
  }

  try {
    const event = stripe.webhooks.constructEvent(
      payload,
      signature,
      stripeWebhookSecret,
    );
    return event;
  } catch (error) {
    logger.error('Stripe webhook verification failed', {
      message: error.message,
      type: error.type,
    });
    throw new Error(`Webhook signature verification failed: ${error.message}`);
  }
};

export default stripe;


