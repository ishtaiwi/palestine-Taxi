import { verifyWebhook } from '../services/stripeService.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { PAYMENT_STATUS } from '../utils/constants.js';
import logger from '../utils/logger.js';


export const handleStripeWebhook = async (req, res) => {
  const signature = req.headers['stripe-signature'];

  if (!signature) {
    logger.warn('Stripe webhook called without signature header');
    return res.status(400).send('Missing Stripe-Signature header');
  }

  let event;

  try {
    
    const payload = req.body;
    event = verifyWebhook(payload, signature);
  } catch (error) {
    logger.error('Stripe webhook signature verification failed', {
      error: error.message,
    });
    return res.status(400).send(`Webhook Error: ${error.message}`);
  }

  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSucceeded(event.data.object);
        break;

      case 'payment_intent.payment_failed':
        await handlePaymentFailed(event.data.object);
        break;

      case 'payment_intent.canceled':
        await handlePaymentCanceled(event.data.object);
        break;

      default:
        logger.info(`Unhandled Stripe event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (error) {
    logger.error('Error processing Stripe webhook', {
      error: error.message,
      eventType: event.type,
    });
    res.status(500).json({ error: 'Webhook processing failed' });
  }
};

async function handlePaymentSucceeded(paymentIntent) {
  const { id: paymentIntentId, amount, metadata } = paymentIntent;
  const walletId = metadata?.walletId;
  const userId = metadata?.userId;

  logger.info('Handling Stripe payment_intent.succeeded', {
    paymentIntentId,
    walletId,
    userId,
  });

  if (!walletId) {
    logger.error('Stripe payment succeeded but walletId is missing in metadata', {
      paymentIntentId,
    });
    return;
  }

  const paymentRecord = await Payment.findByStripeIntentId(paymentIntentId);

  if (!paymentRecord) {
    logger.error('Payment record not found for Stripe payment intent', {
      paymentIntentId,
    });
    return;
  }

  if (paymentRecord.status === PAYMENT_STATUS.COMPLETED) {
    logger.warn('Payment already marked as completed, skipping', {
      paymentId: paymentRecord.paymentid,
      paymentIntentId,
    });
    return;
  }

  
  if (paymentRecord.type !== 'wallet_topup') {
    logger.info('Skipping non-wallet_topup payment in Stripe webhook', {
      paymentId: paymentRecord.paymentid,
      type: paymentRecord.type,
    });
    return;
  }

  
  const amountInMainUnit = amount / 100;

  
  const walletIdToUpdate = paymentRecord.towalletid || walletId;

  await Wallet.updateBalance(walletIdToUpdate, amountInMainUnit, 'add');

  await Payment.update(paymentRecord.paymentid, {
    status: PAYMENT_STATUS.COMPLETED,
  });

  logger.info('Wallet top-up completed via Stripe', {
    userId,
    walletId: walletIdToUpdate,
    amount: amountInMainUnit,
    paymentId: paymentRecord.paymentid,
    paymentIntentId,
  });
}

async function handlePaymentFailed(paymentIntent) {
  const { id: paymentIntentId } = paymentIntent;

  logger.info('Handling Stripe payment_intent.payment_failed', {
    paymentIntentId,
  });

  const paymentRecord = await Payment.findByStripeIntentId(paymentIntentId);

  if (!paymentRecord) {
    logger.warn('Payment record not found for failed Stripe intent', {
      paymentIntentId,
    });
    return;
  }

  await Payment.update(paymentRecord.paymentid, {
    status: PAYMENT_STATUS.FAILED,
  });
}

async function handlePaymentCanceled(paymentIntent) {
  const { id: paymentIntentId } = paymentIntent;

  logger.info('Handling Stripe payment_intent.canceled', {
    paymentIntentId,
  });

  const paymentRecord = await Payment.findByStripeIntentId(paymentIntentId);

  if (!paymentRecord) {
    logger.warn('Payment record not found for canceled Stripe intent', {
      paymentIntentId,
    });
    return;
  }

  await Payment.update(paymentRecord.paymentid, {
    status: PAYMENT_STATUS.FAILED,
  });
}


