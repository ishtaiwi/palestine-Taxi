import Wallet from '../models/Wallet.js';
import { v4 as uuidv4 } from 'uuid';


export const getUserWallets = async (req, res, next) => {
  try {
    const userid = req.user.userid;
    const { type } = req.query;
    
    const wallets = await Wallet.findByUserId(userid, type);
    res.json(wallets);
  } catch (error) {
    next(error);
  }
};


export const getWalletById = async (req, res, next) => {
  try {
    const { walletid } = req.params;
    const wallet = await Wallet.findById(walletid);
    
    if (!wallet) {
      return res.status(404).json({ 
        message: req.t('wallet.not_found') || 'Wallet not found' 
      });
    }
    
    res.json(wallet);
  } catch (error) {
    next(error);
  }
};


export const createWallet = async (req, res, next) => {
  try {
    const { type } = req.body;
    const userid = req.user.userid;
    
    const walletData = {
      walletid: uuidv4(),
      userid,
      type: type || 'main',
      balance: 0,
    };
    
    const wallet = await Wallet.create(walletData);
    res.status(201).json({
      message: req.t('wallet.created') || 'Wallet created successfully',
      wallet,
    });
  } catch (error) {
    next(error);
  }
};


export const addBalance = async (req, res, next) => {
  try {
    const { walletid } = req.params;
    const { amount } = req.body;
    
    if (amount <= 0) {
      return res.status(400).json({ 
        message: req.t('wallet.invalid_amount') || 'Invalid amount' 
      });
    }
    
    const wallet = await Wallet.updateBalance(walletid, amount, 'add');
    res.json({
      message: req.t('wallet.balance_added') || 'Balance added successfully',
      wallet,
    });
  } catch (error) {
    next(error);
  }
};

