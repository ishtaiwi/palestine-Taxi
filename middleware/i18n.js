
const translations = {
  en: {
    auth: {
      email_exists: 'Email already exists',
      invalid_credentials: 'Invalid credentials',
      register_success: 'Registration successful',
      login_success: 'Login successful',
      profile_updated: 'Profile updated successfully',
      no_token: 'No token provided',
      invalid_token: 'Invalid token',
      token_expired: 'Token expired',
      admin_required: 'Admin access required',
      driver_required: 'Driver access required',
      passenger_required: 'Passenger access required',
      role_required: 'Insufficient permissions',
      permission_required: 'Permission required',
    },
    line: {
      not_found: 'Line not found',
      created: 'Line created successfully',
      updated: 'Line updated successfully',
      deleted: 'Line deleted successfully',
    },
    trip: {
      not_found: 'Trip not found',
      created: 'Trip created successfully',
      updated: 'Trip updated successfully',
      deleted: 'Trip has been deleted successfully',
      started: 'Trip started successfully',
      ended: 'Trip ended successfully',
    },
    reservation: {
      not_found: 'Reservation not found',
      created: 'Reservation created successfully',
      updated: 'Reservation updated successfully',
      cancelled: 'Reservation cancelled successfully',
      checked_in: 'Passenger checked in successfully',
      no_seats: 'No available seats',
      seat_taken: 'Seat already taken',
      no_drivers_available: 'Sorry, there are no drivers available at the moment. Please try again later.',
    },
    vehicle: {
      not_found: 'Vehicle not found',
      created: 'Vehicle created successfully',
      updated: 'Vehicle updated successfully',
      assigned: 'Vehicle assigned to line successfully',
    },
    payment: {
      not_found: 'Payment not found',
      created: 'Payment created successfully',
      updated: 'Payment updated successfully',
      insufficient_balance: 'Insufficient balance',
    },
    wallet: {
      not_found: 'Wallet not found',
      created: 'Wallet created successfully',
      balance_added: 'Balance added successfully',
      invalid_amount: 'Invalid amount',
    },
    user: {
      not_found: 'User not found',
      created: 'User has been created successfully',
      updated: 'User has been updated successfully',
      deleted: 'User has been deleted successfully',
    },
    admin: {
      permissions_updated: 'Permissions have been updated successfully',
    },
    driver: {
      not_found: 'Driver not found',
      invalid_role: 'This user is not a driver',
      approved: 'Driver has been approved successfully',
      rejected: 'Driver has been rejected successfully',
      rejection_reason_required: 'Rejection reason is required',
      line_missing: 'Driver does not have an assigned line',
      queue_exists: 'Driver already in queue',
      queue_joined: 'Driver added to queue',
      queue_left: 'Driver left the queue',
      queue_not_found: 'Driver queue entry not found',
      invalid_direction: 'Invalid direction. Must be "going" or "returning"',
      trip_forbidden: 'Driver not authorized for this trip',
    },
    recommendation: {
      payload_required: 'Recommendation payload is required',
      applied: 'Recommendation has been applied successfully',
    },
    prediction: {
      retrained: 'Prediction model retraining has been started',
    },
    validation: {
      errors: 'Validation errors',
    },
  },
  ar: {
    auth: {
      email_exists: 'البريد الإلكتروني موجود بالفعل',
      invalid_credentials: 'بيانات الدخول غير صحيحة',
      register_success: 'تم التسجيل بنجاح',
      login_success: 'تم تسجيل الدخول بنجاح',
      profile_updated: 'تم تحديث الملف الشخصي بنجاح',
      no_token: 'لم يتم توفير رمز الوصول',
      invalid_token: 'رمز الوصول غير صحيح',
      token_expired: 'انتهت صلاحية رمز الوصول',
      admin_required: 'يتطلب صلاحيات المدير',
      driver_required: 'يتطلب صلاحيات السائق',
      passenger_required: 'يتطلب صلاحيات الراكب',
      role_required: 'صلاحيات غير كافية',
      permission_required: 'يتطلب صلاحية',
    },
    line: {
      not_found: 'الخط غير موجود',
      created: 'تم إنشاء الخط بنجاح',
      updated: 'تم تحديث الخط بنجاح',
      deleted: 'تم حذف الخط بنجاح',
    },
    trip: {
      not_found: 'الرحلة غير موجودة',
      created: 'تم إنشاء الرحلة بنجاح',
      updated: 'تم تحديث الرحلة بنجاح',
      deleted: 'تم حذف الرحلة بنجاح',
      started: 'تم بدء الرحلة بنجاح',
      ended: 'تم إنهاء الرحلة بنجاح',
    },
    reservation: {
      not_found: 'الحجز غير موجود',
      created: 'تم إنشاء الحجز بنجاح',
      updated: 'تم تحديث الحجز بنجاح',
      cancelled: 'تم إلغاء الحجز بنجاح',
      checked_in: 'تم تسجيل وصول الراكب بنجاح',
      no_seats: 'لا توجد مقاعد متاحة',
      seat_taken: 'المقعد محجوز بالفعل',
      no_drivers_available: 'عذراً، لا يوجد سائقون متاحون في الوقت الحالي. يرجى المحاولة مرة أخرى لاحقاً.',
    },
    vehicle: {
      not_found: 'المركبة غير موجودة',
      created: 'تم إنشاء المركبة بنجاح',
      updated: 'تم تحديث المركبة بنجاح',
      assigned: 'تم تعيين المركبة للخط بنجاح',
    },
    payment: {
      not_found: 'الدفعة غير موجودة',
      created: 'تم إنشاء الدفعة بنجاح',
      updated: 'تم تحديث الدفعة بنجاح',
      insufficient_balance: 'الرصيد غير كافي',
    },
    wallet: {
      not_found: 'المحفظة غير موجودة',
      created: 'تم إنشاء المحفظة بنجاح',
      balance_added: 'تم إضافة الرصيد بنجاح',
      invalid_amount: 'المبلغ غير صحيح',
    },
    user: {
      not_found: 'المستخدم غير موجود',
      created: 'تم إنشاء المستخدم بنجاح',
      updated: 'تم تحديث المستخدم بنجاح',
      deleted: 'تم حذف المستخدم بنجاح',
    },
    admin: {
      permissions_updated: 'تم تحديث الصلاحيات بنجاح',
    },
    driver: {
      not_found: 'السائق غير موجود',
      invalid_role: 'هذا المستخدم ليس سائق',
      approved: 'تم اعتماد السائق بنجاح',
      rejected: 'تم رفض السائق بنجاح',
      rejection_reason_required: 'سبب الرفض مطلوب',
      line_missing: 'لم يتم تعيين خط للسائق',
      queue_exists: 'السائق موجود بالفعل في قائمة الانتظار',
      queue_joined: 'تمت إضافة السائق إلى قائمة الانتظار',
      queue_left: 'غادر السائق قائمة الانتظار',
      queue_not_found: 'لم يتم العثور على السائق في قائمة الانتظار',
      invalid_direction: 'اتجاه غير صحيح. يجب أن يكون "ذهاب" أو "عودة"',
      trip_forbidden: 'السائق غير مصرح له بهذه الرحلة',
    },
    recommendation: {
      payload_required: 'حقل التوصية مطلوب',
      applied: 'تم تطبيق التوصية بنجاح',
    },
    prediction: {
      retrained: 'تم بدء إعادة تدريب نموذج التنبؤ',
    },
    validation: {
      errors: 'أخطاء التحقق',
    },
  },
};

export const i18n = (req, res, next) => {
  const lang = req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 
               req.query.lang || 
               'ar';
  
  req.language = lang === 'ar' ? 'ar' : 'en';
  req.t = (key) => {
    const keys = key.split('.');
    let translation = translations[req.language];
    
    for (const k of keys) {
      translation = translation?.[k];
    }
    
    return translation || key;
  };
  
  next();
};

