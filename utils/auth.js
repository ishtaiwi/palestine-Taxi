import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import appConfig from '../config/app.js';

export const generateToken = (payload) => {
  return jwt.sign(payload, appConfig.jwt.secret, {
    expiresIn: appConfig.jwt.expiresIn,
  });
};

export const verifyToken = (token) => {
  return jwt.verify(token, appConfig.jwt.secret);
};

export const hashPassword = async (password) => {
  const salt = await bcrypt.genSalt(10);
  return await bcrypt.hash(password, salt);
};

export const comparePassword = async (password, hashedPassword) => {
  return await bcrypt.compare(password, hashedPassword);
};

