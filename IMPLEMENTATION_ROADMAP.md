# 🗺️ خارطة طريق تطوير نظام Pal Taxi

## 📋 نظرة عامة
هذا الملف يوضح الخطوات المطلوبة لتطبيق جميع الميزات المطلوبة في النظام التشغيلي.

---

## 🔴 المرحلة 1: البنية الأساسية (الأولوية القصوى)

### 1.1 تحديث قاعدة البيانات
- [x] ✅ Migration 010: إضافة `booking_type` و `scheduled_trip_time`
- [x] ✅ Migration 011: إضافة حقول فتح الرحلة والانطلاق التلقائي
- [x] ✅ Migration 012: إضافة `assigned_driverid` للربط بين الرحلات والسائقين

### 1.2 تحديث Models
- [x] ✅ تحديث `Reservation.js` لدعم الحقول الجديدة
- [x] ✅ تحديث `Trip.js` لدعم الحقول الجديدة
- [x] ✅ إضافة validation للحقول الجديدة

### 1.3 تحديث Constants
- [x] ✅ إضافة `BOOKING_TYPE` constants (future, instant)
- [x] ✅ تحديث `CANCELLATION_POLICY` (60 دقيقة، 25%)

---

## 🟡 المرحلة 2: نظام التوزيع التلقائي (Matching Engine)

### 2.1 بناء Matching Service
- [x] ✅ إنشاء `services/matchingService.js`
- [x] ✅ دالة `distributeFutureBookings()` - توزيع الحجوزات المسبقة
- [x] ✅ دالة `distributeInstantBookings()` - توزيع الحجوزات الفورية
- [x] ✅ دالة `assignDriverToTrip()` - ربط سائق برحلة من الطابور
- [x] ✅ دالة `getNextDriverFromQueue()` - الحصول على السائق التالي

### 2.2 قواعد التوزيع
- [x] ✅ **قاعدة 1**: Future Bookings أولاً
- [x] ✅ **قاعدة 2**: توزيع على السائق الأول من الطابور
- [x] ✅ **قاعدة 3**: الانتقال للسائق التالي عند الامتلاء
- [x] ✅ **قاعدة 4**: ترتيب Instant Bookings حسب Timestamp (الكشك والتطبيق متساويان)

### 2.3 ربط مع Driver Queue
- [x] ✅ تحديث `DriverQueue` لدعم إزالة السائق عند الانطلاق
- [x] ✅ تحديث `DriverQueue` لدعم تحريك السائقين للأمام
- [x] ✅ إضافة دالة `removeDriverFromQueue()` عند انطلاق الرحلة

---

## 🟢 المرحلة 3: نظام فتح الرحلات والانطلاق التلقائي

### 3.1 فتح الرحلات
- [x] ✅ إنشاء Background Job لفتح الرحلات (45 دقيقة قبل الانطلاق)
- [x] ✅ دالة `openScheduledTrips()` - فتح الرحلات المجدولة
- [x] ✅ تحديث `trip_opening_time` عند إنشاء الرحلة
- [x] ✅ استدعاء Matching Engine عند فتح الرحلة

### 3.2 قواعد الانطلاق
- [x] ✅ **Early Departure**: انطلاق عند الامتلاء (إذا `early_departure_allowed = true`)
- [x] ✅ **Scheduled Departure**: انطلاق عند الوقت المحدد (إذا `scheduled_departure_enforced = true`)
- [x] ✅ **Future Booking Rule**: انطلاق براكب مسبق واحد على الأقل

### 3.3 Background Jobs
- [x] ✅ إنشاء `jobs/tripOpeningJob.js` - فتح الرحلات
- [x] ✅ إنشاء `jobs/departureCheckJob.js` - فحص وقت الانطلاق
- [x] ✅ إنشاء `jobs/noShowCheckJob.js` - فحص No-Show

---

## 🔵 المرحلة 4: نظام No-Show

### 4.1 منطق No-Show
- [x] ✅ دالة `markNoShowForTrip()` - تحويل الحجوزات إلى No-Show
- [x] ✅ فحص الحجوزات عند انطلاق الرحلة
- [x] ✅ تحديث حالة الحجز إلى `no_show`
- [x] ✅ خصم كامل المبلغ (لا استرداد)

### 4.2 Background Job
- [x] ✅ إنشاء `jobs/noShowCheckJob.js`
- [x] ✅ تشغيل عند انطلاق الرحلة (مدمج مع departureService)
- [x] ✅ تحديث حالة الحجوزات غير المحضورة
- [x] ✅ Background job إضافي للفحص الدوري (كل دقيقتين)

---

## 🟣 المرحلة 5: تحديث نظام الحجوزات

### 5.1 تحديث createReservation
- [x] ✅ إضافة `booking_type` (future/instant)
- [x] ✅ إضافة `scheduled_trip_time` للحجوزات المسبقة
- [x] ✅ استدعاء Matching Engine بعد إنشاء الحجز

### 5.2 تحديث سياسة الإلغاء
- [x] ✅ تعديل `cancelReservation()` لدعم 60 دقيقة
- [x] ✅ تعديل `calculateRefund()` لدعم 25% خصم
- [x] ✅ تحديث `CANCELLATION_POLICY` constants

### 5.3 تحديث API
- [x] ✅ تحديث `/reservations` POST لدعم الحقول الجديدة
- [x] ✅ إضافة validation للحقول الجديدة
- [ ] تحديث documentation (Swagger)

---

## 🟠 المرحلة 6: Frontend للكشك

### 6.1 ملاحظات
- ✅ **Backend جاهز** - الكشك يستخدم نفس API/Backend
- ✅ **لا حاجة لـ API منفصل** - الكشك والتطبيق متساويان

### 6.2 Frontend (Kiosk)
- [ ] إنشاء صفحة Kiosk (واجهة مبسطة للاستخدام داخل المجمع)
- [ ] QR Code Scanner للركاب
- [ ] عرض الرحلات المتاحة
- [ ] إنشاء حجز فوري
- [ ] تصميم مناسب للشاشات الكبيرة (Kiosk screens)

---

## 🔴 المرحلة 7: Frontend Improvements

### 7.1 Check-In
- [ ] QR Code Scanner في صفحة السائق
- [ ] عرض الحجوزات للرحلة
- [ ] Check-in للركاب
- [ ] Arrival Confirmation في تطبيق الراكب

### 7.2 عرض الحجوزات
- [ ] تمييز Future vs Instant Bookings
- [ ] عرض Timestamp للحجوزات الفورية

### 7.3 Driver Interface
- [ ] عرض الرحلة المخصصة
- [ ] عرض الركاب الموزعين
- [ ] بدء الرحلة (Early/Scheduled)

---

## 📊 جدول زمني مقترح

### الأسبوع 1-2: المرحلة 1 (البنية الأساسية)
- تحديث قاعدة البيانات
- تحديث Models
- تحديث Constants

### الأسبوع 3-4: المرحلة 2 (Matching Engine)
- بناء Matching Service
- تطبيق قواعد التوزيع
- ربط مع Driver Queue

### الأسبوع 5: المرحلة 3 (فتح الرحلات والانطلاق)
- Background Jobs
- قواعد الانطلاق

### الأسبوع 6: المرحلة 4 (No-Show)
- منطق No-Show
- Background Job

### الأسبوع 7: المرحلة 5 (تحديث الحجوزات)
- تحديث createReservation
- تحديث سياسة الإلغاء

### الأسبوع 8: المرحلة 6 (Frontend للكشك)
- Frontend Kiosk (واجهة مبسطة)
- تصميم مناسب للشاشات الكبيرة

### الأسبوع 9-10: المرحلة 7 (Frontend)
- Check-In
- تحسينات UI

---

## 🧪 الاختبار

### Unit Tests
- [ ] اختبار Matching Service
- [ ] اختبار قواعد التوزيع
- [ ] اختبار No-Show logic
- [ ] اختبار سياسة الإلغاء

### Integration Tests
- [ ] اختبار تدفق الحجز الكامل
- [ ] اختبار التوزيع التلقائي
- [ ] اختبار الانطلاق التلقائي

### E2E Tests
- [ ] سيناريو: حجز مسبق → توزيع → انطلاق
- [ ] سيناريو: حجز فوري → توزيع → انطلاق
- [ ] سيناريو: No-Show → خصم

---

## 📝 ملاحظات

### اعتبارات تقنية
1. **Background Jobs**: استخدم `node-cron` أو `bull` للـ jobs
2. **Database Transactions**: استخدم transactions للتوزيع لضمان الاتساق
3. **Caching**: فكر في caching للـ Driver Queue
4. **Logging**: سجل جميع عمليات التوزيع للـ debugging

### اعتبارات الأداء
1. **Indexes**: تأكد من وجود indexes على جميع الحقول المستخدمة في queries
2. **Batch Processing**: معالجة الحجوزات في batches عند الحاجة
3. **Optimistic Locking**: استخدم optimistic locking لتجنب race conditions

---

## ✅ Checklist النهائي

قبل الإطلاق، تأكد من:
- [ ] جميع الميزات المطلوبة مطبقة
- [ ] جميع الاختبارات تمر
- [ ] Documentation محدث
- [ ] Migration scripts جاهزة
- [ ] Backup strategy موجودة
- [ ] Monitoring و Logging جاهزين

