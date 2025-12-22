import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { v4 as uuidv4 } from 'uuid';
import { PAYMENT_STATUS, PAYMENT_METHOD } from '../utils/constants.js';


export const getAllPayments = async (req, res, next) => {
  try {
    const { status, method, type } = req.query;
    const filters = {};
    
    if (status) filters.status = status;
    if (method) filters.method = method;
    if (type) filters.type = type;
    
    const payments = await Payment.findAll(filters);
    res.json(payments);
  } catch (error) {
    next(error);
  }
};


export const getPaymentById = async (req, res, next) => {
  try {
    const { paymentid } = req.params;
    const payment = await Payment.findById(paymentid);
    
    if (!payment) {
      return res.status(404).json({ 
        message: req.t('payment.not_found') || 'Payment not found' 
      });
    }
    
    res.json(payment);
  } catch (error) {
    next(error);
  }
};


export const getWalletPayments = async (req, res, next) => {
  try {
    const wallets = await Wallet.findByUserId(req.user.userid);
    if (wallets.length === 0) {
      return res.json([]);
    }
    
    const walletid = wallets[0].walletid;
    const payments = await Payment.findByWalletId(walletid);
    res.json(payments);
  } catch (error) {
    next(error);
  }
};


export const createPayment = async (req, res, next) => {
  try {
    const { fromwalletid, towalletid, amount, method, type } = req.body;
    
    const paymentData = {
      paymentid: uuidv4(),
      fromwalletid: fromwalletid || null,
      towalletid: towalletid || null,
      amount,
      method,
      type: type || 'transfer',
      status: PAYMENT_STATUS.PENDING,
    };
    
    const payment = await Payment.create(paymentData);
    
    
    if (method === PAYMENT_METHOD.WALLET && fromwalletid) {
      const wallet = await Wallet.findById(fromwalletid);
      if (wallet.balance >= amount) {
        await Wallet.updateBalance(fromwalletid, amount, 'subtract');
        if (towalletid) {
          await Wallet.updateBalance(towalletid, amount, 'add');
        }
        await Payment.update(payment.paymentid, { status: PAYMENT_STATUS.COMPLETED });
      } else {
        await Payment.update(payment.paymentid, { status: PAYMENT_STATUS.FAILED });
        return res.status(400).json({ 
          message: req.t('payment.insufficient_balance') || 'Insufficient balance' 
        });
      }
    }
    
    res.status(201).json({
      message: req.t('payment.created') || 'Payment created successfully',
      payment,
    });
  } catch (error) {
    next(error);
  }
};


export const updatePaymentStatus = async (req, res, next) => {
  try {
    const { paymentid } = req.params;
    const { status } = req.body;
    
    const payment = await Payment.update(paymentid, { status });
    res.json({
      message: req.t('payment.updated') || 'Payment updated successfully',
      payment,
    });
  } catch (error) {
    next(error);
  }
};

