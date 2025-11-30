import QRCode from 'qrcode';

export const generateQRCode = async (data) => {
  try {
    const qrCodeDataURL = await QRCode.toDataURL(data, {
      errorCorrectionLevel: 'H',
      type: 'image/png',
      quality: 0.92,
      margin: 1,
      color: {
        dark: '#000000',
        light: '#FFFFFF',
      },
    });
    
    return qrCodeDataURL;
  } catch (error) {
    throw new Error('Failed to generate QR code');
  }
};

export const generateQRCodeBuffer = async (data) => {
  try {
    const buffer = await QRCode.toBuffer(data, {
      errorCorrectionLevel: 'H',
      type: 'image/png',
      quality: 0.92,
      margin: 1,
    });
    
    return buffer;
  } catch (error) {
    throw new Error('Failed to generate QR code');
  }
};

