# 🔗 دليل ربط الباك اند بالفرونت اند | Backend-Frontend Integration Guide

هذا الملف يشرح بالتفصيل كيف يتم ربط الباك اند (Node.js/Express) بالفرونت اند (Flutter) في المشروع.

---

## 📋 جدول المحتويات

1. [البنية العامة](#البنية-العامة)
2. [كيف يعمل الربط](#كيف-يعمل-الربط)
3. [مثال عملي: إدارة المستخدمين](#مثال-عملي-إدارة-المستخدمين)
4. [إضافة Endpoint جديد](#إضافة-endpoint-جديد)
5. [المصادقة (Authentication)](#المصادقة-authentication)
6. [معالجة الأخطاء](#معالجة-الأخطاء)
7. [أفضل الممارسات](#أفضل-الممارسات)

---

## 🏗️ البنية العامة

### Backend (Node.js/Express)
```
backend/
├── server.js              # نقطة البداية، يربط كل شيء
├── routes/                # تعريف المسارات (Endpoints)
│   ├── adminRoutes.js
│   ├── authRoutes.js
│   └── ...
├── controllers/           # منطق العمل (Business Logic)
│   ├── adminController.js
│   ├── authController.js
│   └── ...
├── models/                # نماذج قاعدة البيانات
│   ├── User.js
│   └── ...
└── middleware/            # Middleware للمصادقة والتفويض
    ├── auth.js
    └── authorization.js
```

### Frontend (Flutter)
```
frontend/
├── lib/
│   ├── services/
│   │   └── api_service.dart    # جميع استدعاءات API
│   ├── config/
│   │   └── app_config.dart     # إعدادات API (URL, Timeout)
│   └── pages/
│       └── admin/
│           └── admin_users_page.dart  # استخدام API
```

---

## 🔄 كيف يعمل الربط

### 1. Backend: تعريف Route
في `routes/adminRoutes.js`:
```javascript
import express from 'express';
import { getAllUsers } from '../controllers/adminController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/authorization.js';

const router = express.Router();

// تطبيق middleware على جميع المسارات
router.use(authenticate);      // التحقق من تسجيل الدخول
router.use(requireAdmin);      // التحقق من صلاحيات Admin

// تعريف Endpoint
router.get('/users', getAllUsers);

export default router;
```

### 2. Backend: تسجيل Route في Server
في `server.js`:
```javascript
import adminRoutes from './routes/adminRoutes.js';

// تسجيل المسارات
app.use('/api/admin', adminRoutes);
```

النتيجة: Endpoint متاح على `/api/admin/users`

### 3. Backend: Controller
في `controllers/adminController.js`:
```javascript
export const getAllUsers = async (req, res, next) => {
  try {
    const { role } = req.query;  // Query parameters (مثال: ?role=driver)
    const filters = role ? { role } : {};
    
    const users = await User.findAll(filters);
    res.json(users);  // إرجاع JSON
  } catch (error) {
    next(error);  // معالجة الأخطاء
  }
};
```

### 4. Frontend: تعريف API Function
في `frontend/lib/services/api_service.dart`:
```dart
class ApiService {
  // الحصول على Token المحفوظ
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // جلب جميع المستخدمين
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // إرسال Request
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/admin/users'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',  // إرسال Token
        },
      ).timeout(AppConfig.requestTimeout);

      // معالجة الاستجابة
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        
        // التحقق من نوع البيانات
        if (decoded is List) {
          return decoded
              .map((u) => Map<String, dynamic>.from(u))
              .toList();
        } else if (decoded is Map && decoded['users'] is List) {
          return (decoded['users'] as List)
              .map((u) => Map<String, dynamic>.from(u))
              .toList();
        }
        throw Exception('Unexpected response format');
      } else {
        throw Exception('Failed to load users');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }
}
```

### 5. Frontend: استخدام API في Page
في `frontend/lib/pages/admin/admin_users_page.dart`:
```dart
class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();  // جلب البيانات عند تحميل الصفحة
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // استدعاء API
      final users = await ApiService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // عرض رسالة خطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          title: Text(user['fullname'] ?? ''),
          subtitle: Text(user['email'] ?? ''),
        );
      },
    );
  }
}
```

---

## 💡 مثال عملي: إدارة المستخدمين

### الخطوة الكاملة من Backend إلى Frontend

#### 1️⃣ Backend: Route
**File:** `routes/adminRoutes.js`
```javascript
router.get('/users', getAllUsers);  // GET /api/admin/users
router.put('/users/:userid', updateUser);  // PUT /api/admin/users/:userid
router.delete('/users/:userid', deleteUser);  // DELETE /api/admin/users/:userid
```

#### 2️⃣ Backend: Controller
**File:** `controllers/adminController.js`
```javascript
// GET /api/admin/users
export const getAllUsers = async (req, res, next) => {
  try {
    const users = await User.findAll();
    res.json(users);  // إرجاع Array
  } catch (error) {
    next(error);
  }
};

// PUT /api/admin/users/:userid
export const updateUser = async (req, res, next) => {
  try {
    const { userid } = req.params;
    const updates = req.body;  // { fullname, email, phone, role }
    
    const user = await User.update(userid, updates);
    res.json({
      message: 'User updated successfully',
      user,
    });
  } catch (error) {
    next(error);
  }
};

// DELETE /api/admin/users/:userid
export const deleteUser = async (req, res, next) => {
  try {
    const { userid } = req.params;
    await User.delete(userid);
    res.json({
      message: 'User deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};
```

#### 3️⃣ Frontend: API Service
**File:** `frontend/lib/services/api_service.dart`
```dart
// GET جميع المستخدمين
static Future<List<Map<String, dynamic>>> getAllUsers() async {
  final token = await getToken();
  final response = await http.get(
    Uri.parse('${AppConfig.apiBaseUrl}/admin/users'),
    headers: {
      'Accept': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    },
  ).timeout(AppConfig.requestTimeout);

  if (response.statusCode == 200) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List) {
      return decoded.map((u) => Map<String, dynamic>.from(u)).toList();
    }
    throw Exception('Unexpected response format');
  }
  throw Exception('Failed to load users');
}

// PUT تحديث مستخدم
static Future<Map<String, dynamic>> updateUser({
  required String userid,
  String? fullname,
  String? email,
  String? phone,
  String? role,
}) async {
  final token = await getToken();
  final body = <String, dynamic>{};
  if (fullname != null) body['fullname'] = fullname;
  if (email != null) body['email'] = email;
  if (phone != null) body['phone'] = phone;
  if (role != null) body['role'] = role;

  final response = await http.put(
    Uri.parse('${AppConfig.apiBaseUrl}/admin/users/$userid'),
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    },
    body: utf8.encode(jsonEncode(body)),
  ).timeout(AppConfig.requestTimeout);

  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (response.statusCode == 200) {
    return {'success': true, ...decoded};
  }
  return {
    'success': false,
    'message': decoded['message'] ?? 'Failed to update user',
  };
}

// DELETE حذف مستخدم
static Future<Map<String, dynamic>> deleteUser(String userid) async {
  final token = await getToken();
  final response = await http.delete(
    Uri.parse('${AppConfig.apiBaseUrl}/admin/users/$userid'),
    headers: {
      'Accept': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    },
  ).timeout(AppConfig.requestTimeout);

  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  return {
    'success': response.statusCode == 200,
    'message': decoded['message'] ?? (response.statusCode == 200 ? 'User deleted' : 'Failed'),
  };
}
```

#### 4️⃣ Frontend: استخدام في Page
**File:** `frontend/lib/pages/admin/admin_users_page.dart`
```dart
// جلب البيانات
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  try {
    final users = await ApiService.getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    // عرض خطأ
  }
}

// تحديث مستخدم
Future<void> _handleEdit(Map<String, dynamic> user) async {
  // ... عرض Dialog للإدخال ...
  
  final result = await ApiService.updateUser(
    userid: user['userid'],
    fullname: nameController.text.trim(),
    email: emailController.text.trim(),
    role: selectedRole,
  );
  
  if (result['success'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
    );
    _loadData();  // إعادة جلب البيانات
  }
}

// حذف مستخدم
Future<void> _handleDelete(String userid) async {
  final confirmed = await showDialog<bool>(/* تأكيد */);
  if (confirmed != true) return;

  final result = await ApiService.deleteUser(userid);
  if (result['success'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
    );
    _loadData();  // إعادة جلب البيانات
  }
}
```

---

## ➕ إضافة Endpoint جديد

### مثال: إضافة Endpoint للحصول على إحصائيات

#### 1. Backend: Controller
**File:** `controllers/adminController.js`
```javascript
export const getDashboardStats = async (req, res, next) => {
  try {
    const trips = await Trip.findAll();
    const users = await User.findAll();
    
    const stats = {
      totalTrips: trips.length,
      totalUsers: users.length,
      // ... المزيد من الإحصائيات
    };
    
    res.json(stats);
  } catch (error) {
    next(error);
  }
};
```

#### 2. Backend: Route
**File:** `routes/adminRoutes.js`
```javascript
import { getDashboardStats } from '../controllers/adminController.js';

router.get('/dashboard/stats', getDashboardStats);
```

#### 3. Frontend: API Service
**File:** `frontend/lib/services/api_service.dart`
```dart
/// Get dashboard statistics (admin)
static Future<Map<String, dynamic>> getDashboardStats() async {
  try {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/admin/dashboard/stats'),
      headers: {
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    ).timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception('Failed to load stats');
  } catch (exception) {
    throw Exception(exception.toString());
  }
}
```

#### 4. Frontend: استخدام في Page
```dart
Map<String, dynamic>? _stats;

Future<void> _loadStats() async {
  try {
    _stats = await ApiService.getDashboardStats();
    setState(() {});
  } catch (e) {
    // معالجة الخطأ
  }
}

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Total Trips: ${_stats?['totalTrips'] ?? 0}'),
      Text('Total Users: ${_stats?['totalUsers'] ?? 0}'),
    ],
  );
}
```

---

## 🔐 المصادقة (Authentication)

### Backend: JWT Token
```javascript
// middleware/auth.js
export const authenticate = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];  // "Bearer TOKEN"
    
    if (!token) {
      return res.status(401).json({ message: 'No token provided' });
    }
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;  // إضافة معلومات المستخدم للـ request
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid token' });
  }
};
```

### Frontend: حفظ واستخدام Token
```dart
// حفظ Token بعد تسجيل الدخول
static Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', token);
}

// استخدام Token في كل Request
static Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token');
}

// إرسال Token في Header
final response = await http.get(
  Uri.parse(url),
  headers: {
    'Authorization': 'Bearer $token',
  },
);
```

---

## ⚠️ معالجة الأخطاء

### Backend: Error Handling
```javascript
export const getAllUsers = async (req, res, next) => {
  try {
    const users = await User.findAll();
    res.json(users);
  } catch (error) {
    // إرسال الخطأ إلى Error Handler
    next(error);
  }
};

// Error Handler في server.js
app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
  });
});
```

### Frontend: Error Handling
```dart
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  try {
    final users = await ApiService.getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    
    String errorMessage = 'An error occurred';
    if (e.toString().contains('Not authenticated')) {
      errorMessage = 'Please login again';
      // إعادة توجيه لصفحة تسجيل الدخول
    } else if (e.toString().contains('timeout')) {
      errorMessage = 'Connection timeout. Please try again.';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

## ✅ أفضل الممارسات

### 1. استخدام Constants للـ URLs
```dart
// frontend/lib/config/app_config.dart
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:3000/api';
  static const Duration requestTimeout = Duration(seconds: 30);
}
```

### 2. إعادة استخدام الكود
```dart
// دالة مساعدة للـ Headers
static Map<String, String> _getHeaders({bool includeAuth = true}) {
  final headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json; charset=utf-8',
  };
  
  if (includeAuth) {
    final token = await getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
  }
  
  return headers;
}
```

### 3. استخدام Loading States
```dart
bool _isLoading = true;

Future<void> _loadData() async {
  setState(() => _isLoading = true);
  try {
    // جلب البيانات
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 4. Validation في Backend
```javascript
import { body, validationResult } from 'express-validator';

export const validateUpdateUser = [
  body('email').optional().isEmail(),
  body('role').optional().isIn(['admin', 'driver', 'passenger']),
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  },
];

router.put('/users/:userid', validateUpdateUser, updateUser);
```

### 5. Type Safety في Flutter
```dart
// إنشاء Model Class
class User {
  final String userid;
  final String fullname;
  final String email;
  final String role;

  User.fromJson(Map<String, dynamic> json)
      : userid = json['userid'],
        fullname = json['fullname'],
        email = json['email'],
        role = json['role'];

  Map<String, dynamic> toJson() => {
    'userid': userid,
    'fullname': fullname,
    'email': email,
    'role': role,
  };
}

// استخدام في API
static Future<List<User>> getAllUsers() async {
  final response = await http.get(/* ... */);
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  return (decoded as List)
      .map((u) => User.fromJson(u))
      .toList();
}
```

---

## 📝 ملخص الخطوات

### لإضافة Endpoint جديد:

1. **Backend:**
   - ✅ إنشاء/تحديث Controller في `controllers/`
   - ✅ تعريف Route في `routes/`
   - ✅ تسجيل Route في `server.js` (إن لزم)

2. **Frontend:**
   - ✅ إضافة Function في `api_service.dart`
   - ✅ استخدام Function في Page/Widget
   - ✅ معالجة Loading و Errors

3. **Testing:**
   - ✅ اختبار Backend باستخدام Postman/Thunder Client
   - ✅ اختبار Frontend في التطبيق

---

## 🔗 روابط مفيدة

- [Express.js Documentation](https://expressjs.com/)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [JSON Serialization in Dart](https://dart.dev/guides/json)

---

**آخر تحديث:** 2025-01-XX

