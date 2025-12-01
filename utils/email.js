import nodemailer from 'nodemailer';
import appConfig from '../config/app.js';
import logger from './logger.js';

let transporter = null;

const canSendEmail = () => {
  const { host, user, pass } = appConfig.email || {};
  return Boolean(host && user && pass);
};

const getTransporter = () => {
  if (transporter) return transporter;

  if (!canSendEmail()) {
    logger.warn('Email transport is not configured. Check EMAIL_* environment variables.');
    return null;
  }

  transporter = nodemailer.createTransport({
    host: appConfig.email.host,
    port: appConfig.email.port || 587,
    secure: appConfig.email.secure ?? false,
    auth: {
      user: appConfig.email.user,
      pass: appConfig.email.pass,
    },
  });

  return transporter;
};

export const sendPasswordResetEmail = async ({ to, code }) => {
  const transport = getTransporter();

  if (!transport) {
    logger.info('Password reset email not sent (email not configured).', {
      to,
      code,
    });
    return {
      sent: false,
      reason: 'not_configured',
    };
  }

  const mailOptions = {
    from: appConfig.email.from,
    to,
    subject: `${appConfig.appName || 'Service Taxi'} - Verification Code`,
    text: `Your password reset verification code is: ${code}\n\nThis code will expire in 60 minutes.\n\nIf you did not request this, please ignore this email.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #F57C00;">رمز التحقق لإعادة تعيين كلمة المرور</h2>
        <p>مرحباً،</p>
        <p>رمز التحقق الخاص بك لإعادة تعيين كلمة المرور هو:</p>
        <div style="background-color: #f5f5f5; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 20px 0; border-radius: 8px; color: #F57C00;">
          ${code}
        </div>
        <p>هذا الرمز صالح لمدة 60 دقيقة.</p>
        <p>إذا لم تطلب إعادة التعيين، تجاهل هذه الرسالة.</p>
        <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;" />
        <h2 style="color: #F57C00;">Password Reset Verification Code</h2>
        <p>Hello,</p>
        <p>Your password reset verification code is:</p>
        <div style="background-color: #f5f5f5; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 20px 0; border-radius: 8px; color: #F57C00;">
          ${code}
        </div>
        <p>This code will expire in 60 minutes.</p>
        <p>If you did not request this, please ignore this email.</p>
      </div>
    `,
  };

  try {
    const info = await transport.sendMail(mailOptions);
    logger.info('Password reset email sent', { to, messageId: info.messageId });
    return { sent: true };
  } catch (error) {
    logger.error('Failed to send password reset email', { to, error: error.message });
    return { sent: false, reason: 'send_failed', error: error.message };
  }
};

