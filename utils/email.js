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

export const sendDriverApprovalEmail = async ({ to, driverName }) => {
  const transport = getTransporter();

  if (!transport) {
    logger.info('Driver approval email not sent (email not configured).', {
      to,
      driverName,
    });
    return {
      sent: false,
      reason: 'not_configured',
    };
  }

  const mailOptions = {
    from: appConfig.email.from,
    to,
    subject: `${appConfig.appName || 'Service Taxi'} - Driver Account Approved`,
    text: `Dear ${driverName},\n\nYour driver account has been approved! You can now log in and start using the service.\n\nThank you for joining us!\n\nBest regards,\n${appConfig.appName || 'Service Taxi'} Team`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #ffffff;">
        <div style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
          <h1 style="color: #ffffff; margin: 0; font-size: 28px;">✅ تم الموافقة على حسابك</h1>
          <h1 style="color: #ffffff; margin: 10px 0 0 0; font-size: 28px;">Account Approved</h1>
        </div>
        
        <div style="padding: 30px; background-color: #f9f9f9; border-radius: 0 0 10px 10px;">
          <div style="margin-bottom: 30px;">
            <h2 style="color: #4CAF50; margin-bottom: 15px; font-size: 20px;">مرحباً ${driverName || 'السائق الكريم'},</h2>
            <p style="color: #333; line-height: 1.6; font-size: 16px;">
              نود إعلامك بأن حسابك كسائق قد تمت الموافقة عليه بنجاح! يمكنك الآن تسجيل الدخول والبدء في استخدام الخدمة.
            </p>
            <p style="color: #333; line-height: 1.6; font-size: 16px; margin-top: 15px;">
              نشكرك على انضمامك إلينا ونتطلع للعمل معك!
            </p>
          </div>
          
          <hr style="margin: 30px 0; border: none; border-top: 2px solid #e0e0e0;" />
          
          <div>
            <h2 style="color: #4CAF50; margin-bottom: 15px; font-size: 20px;">Hello ${driverName || 'Driver'},</h2>
            <p style="color: #333; line-height: 1.6; font-size: 16px;">
              We are pleased to inform you that your driver account has been approved! You can now log in and start using the service.
            </p>
            <p style="color: #333; line-height: 1.6; font-size: 16px; margin-top: 15px;">
              Thank you for joining us and we look forward to working with you!
            </p>
          </div>
          
          <div style="margin-top: 30px; padding: 20px; background-color: #e8f5e9; border-radius: 8px; border-left: 4px solid #4CAF50;">
            <p style="color: #2e7d32; margin: 0; font-size: 14px; font-weight: bold;">
              📱 يمكنك الآن تسجيل الدخول إلى التطبيق والبدء في العمل
            </p>
            <p style="color: #2e7d32; margin: 10px 0 0 0; font-size: 14px; font-weight: bold;">
              📱 You can now log in to the app and start working
            </p>
          </div>
        </div>
        
        <div style="text-align: center; padding: 20px; color: #666; font-size: 12px;">
          <p style="margin: 0;">${appConfig.appName || 'Service Taxi'} Team</p>
          <p style="margin: 5px 0 0 0;">This is an automated message, please do not reply.</p>
        </div>
      </div>
    `,
  };

  try {
    const info = await transport.sendMail(mailOptions);
    logger.info('Driver approval email sent', { to, driverName, messageId: info.messageId });
    return { sent: true };
  } catch (error) {
    logger.error('Failed to send driver approval email', { to, driverName, error: error.message });
    return { sent: false, reason: 'send_failed', error: error.message };
  }
};

export const sendDriverRejectionEmail = async ({ to, driverName, rejectionReason }) => {
  const transport = getTransporter();

  if (!transport) {
    logger.info('Driver rejection email not sent (email not configured).', {
      to,
      driverName,
    });
    return {
      sent: false,
      reason: 'not_configured',
    };
  }

  const mailOptions = {
    from: appConfig.email.from,
    to,
    subject: `${appConfig.appName || 'Service Taxi'} - Driver Account Status Update`,
    text: `Dear ${driverName},\n\nWe regret to inform you that your driver account application has been reviewed and unfortunately, we cannot approve it at this time.\n\nReason: ${rejectionReason || 'Not specified'}\n\nIf you have any questions or would like to appeal this decision, please contact our support team.\n\nBest regards,\n${appConfig.appName || 'Service Taxi'} Team`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #ffffff;">
        <div style="background: linear-gradient(135deg, #f44336 0%, #d32f2f 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
          <h1 style="color: #ffffff; margin: 0; font-size: 28px;">⚠️ تحديث حالة حسابك</h1>
          <h1 style="color: #ffffff; margin: 10px 0 0 0; font-size: 28px;">Account Status Update</h1>
        </div>
        
        <div style="padding: 30px; background-color: #f9f9f9; border-radius: 0 0 10px 10px;">
          <div style="margin-bottom: 30px;">
            <h2 style="color: #d32f2f; margin-bottom: 15px; font-size: 20px;">مرحباً ${driverName || 'السائق الكريم'},</h2>
            <p style="color: #333; line-height: 1.6; font-size: 16px;">
              نأسف لإبلاغك بأن طلب تسجيل حسابك كسائق قد تمت مراجعته، ولسوء الحظ لا يمكننا الموافقة عليه في الوقت الحالي.
            </p>
            ${rejectionReason ? `
            <div style="margin-top: 20px; padding: 15px; background-color: #ffebee; border-radius: 8px; border-left: 4px solid #f44336;">
              <p style="color: #c62828; margin: 0 0 10px 0; font-weight: bold; font-size: 14px;">السبب:</p>
              <p style="color: #333; margin: 0; line-height: 1.6; font-size: 14px;">${rejectionReason}</p>
            </div>
            ` : ''}
            <p style="color: #333; line-height: 1.6; font-size: 16px; margin-top: 20px;">
              إذا كان لديك أي أسئلة أو ترغب في الاعتراض على هذا القرار، يرجى الاتصال بفريق الدعم.
            </p>
          </div>
          
          <hr style="margin: 30px 0; border: none; border-top: 2px solid #e0e0e0;" />
          
          <div>
            <h2 style="color: #d32f2f; margin-bottom: 15px; font-size: 20px;">Hello ${driverName || 'Driver'},</h2>
            <p style="color: #333; line-height: 1.6; font-size: 16px;">
              We regret to inform you that your driver account application has been reviewed and unfortunately, we cannot approve it at this time.
            </p>
            ${rejectionReason ? `
            <div style="margin-top: 20px; padding: 15px; background-color: #ffebee; border-radius: 8px; border-left: 4px solid #f44336;">
              <p style="color: #c62828; margin: 0 0 10px 0; font-weight: bold; font-size: 14px;">Reason:</p>
              <p style="color: #333; margin: 0; line-height: 1.6; font-size: 14px;">${rejectionReason}</p>
            </div>
            ` : ''}
            <p style="color: #333; line-height: 1.6; font-size: 16px; margin-top: 20px;">
              If you have any questions or would like to appeal this decision, please contact our support team.
            </p>
          </div>
          
          <div style="margin-top: 30px; padding: 20px; background-color: #fff3e0; border-radius: 8px; border-left: 4px solid #ff9800;">
            <p style="color: #e65100; margin: 0; font-size: 14px; font-weight: bold;">
              💬 نحن هنا لمساعدتك - لا تتردد في التواصل معنا
            </p>
            <p style="color: #e65100; margin: 10px 0 0 0; font-size: 14px; font-weight: bold;">
              💬 We're here to help - feel free to reach out to us
            </p>
          </div>
        </div>
        
        <div style="text-align: center; padding: 20px; color: #666; font-size: 12px;">
          <p style="margin: 0;">${appConfig.appName || 'Service Taxi'} Team</p>
          <p style="margin: 5px 0 0 0;">This is an automated message, please do not reply.</p>
        </div>
      </div>
    `,
  };

  try {
    const info = await transport.sendMail(mailOptions);
    logger.info('Driver rejection email sent', { to, driverName, messageId: info.messageId });
    return { sent: true };
  } catch (error) {
    logger.error('Failed to send driver rejection email', { to, driverName, error: error.message });
    return { sent: false, reason: 'send_failed', error: error.message };
  }
};

