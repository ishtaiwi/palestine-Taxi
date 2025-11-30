# دليل ربط Backend مع Frontend

## ✅ ما تم إنجازه:

1. **إضافة Dependencies:**
   - `shared_preferences`: لحفظ token وبيانات المستخدم

2. **إنشاء API Service** (`lib/services/api_service.dart`):
   - `login()`: تسجيل الدخول
   - `register()`: إنشاء حساب جديد
   - `getProfile()`: الحصول على بيانات المستخدم
   - `requestPasswordReset()`: طلب إعادة تعيين كلمة المرور
   - حفظ وحذف token وبيانات المستخدم

3. **إنشاء Config** (`lib/config/app_config.dart`):
   - إعدادات Base URL للـ API

4. **تحديث Login Page** (`lib/loginPage.dart`):
   - ربط Login مع الـ Backend
   - ربط Register مع الـ Backend
   - ربط Forgot Password مع الـ Backend
   - معالجة الأخطاء والرسائل

## 🚀 كيفية الاستخدام:

### 1. تغيير IP Address في `lib/config/app_config.dart`:

```dart
// للـ Android Emulator:
static const String apiBaseUrl = 'http://10.0.2.2:3000/api';

// للـ iOS Simulator:
static const String apiBaseUrl = 'http://localhost:3000/api';

// للـ Device الحقيقي (استخدم IP جهازك):
static const String apiBaseUrl = 'http://192.168.1.100:3000/api';
```

### 2. تشغيل Backend:

```bash
cd ..  # من مجلد frontend
npm start
# أو
npm run dev
```

### 3. تشغيل Flutter App:

```bash
cd frontend
flutter run
```

## 📋 الميزات المتاحة:

- ✅ تسجيل الدخول (Login)
- ✅ إنشاء حساب جديد (Register)
- ✅ نسيت كلمة المرور (Forgot Password)
- ✅ حفظ Token تلقائياً
- ✅ معالجة الأخطاء والرسائل
- ✅ دعم اللغة العربية والإنجليزية

## 🔧 ملاحظات مهمة:

1. **CORS Configuration:**
   تأكد من إضافة IP Flutter app في `config/app.js` في الـ backend

2. **Android Network Security:**
   قد تحتاج لإضافة `android:usesCleartextTraffic="true"` في `AndroidManifest.xml` للـ development

3. **Token Storage:**
   Token يُحفظ تلقائياً في SharedPreferences عند Login
   يمكن استخدامه في الـ requests القادمة

## 📝 الخطوات التالية:

- [ ] إنشاء Home Page والانتقال إليها بعد Login
- [ ] إضافة Navigation routes
- [ ] استخدام Token في الـ API calls الأخرى
- [ ] إضافة Logout functionality

