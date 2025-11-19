import 'dart:convert' show jsonEncode, jsonDecode, utf8;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  // Helper method للحصول على token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Helper method لحفظ token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Helper method لحفظ user data
  static Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user));
  }

  // Helper method للحصول على user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  // Helper method لحذف token و user data (logout)
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  // Helper method لحفظ تفضيل اللغة
  static Future<void> saveLanguagePreference(bool isArabic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_arabic', isArabic);
  }

  // Helper method للحصول على تفضيل اللغة
  static Future<bool> getLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('language_arabic') ?? true; // Default to Arabic
  }

  // Login API
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final body = jsonEncode({
        'email': email.trim(),
        'password': password,
      });
      
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(body), // Explicitly encode as UTF-8
      ).timeout(AppConfig.requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // حفظ token و user data
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        if (data['user'] != null) {
          await saveUserData(data['user']);
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Login successful',
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      String errorMessage = 'Connection error';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Register API
  static Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String phone,
    required String password,
    String role = 'PASSENGER',
    String? licenseId,
  }) async {
    try {
      // Encode data with UTF-8 support for Arabic characters
      // Convert role to lowercase for backend validation
      final bodyMap = {
        'fullname': fullname,
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'role': role.toLowerCase(), // Backend expects lowercase
      };
      
      // Add licenseId if provided (for driver registration)
      if (licenseId != null && licenseId.isNotEmpty) {
        bodyMap['licenseid'] = licenseId.trim();
      }
      
      final body = jsonEncode(bodyMap);
      
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/register'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(body), // Explicitly encode as UTF-8
      ).timeout(AppConfig.requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Save token and user data if available (auto-login after registration)
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        if (data['user'] != null) {
          await saveUserData(data['user']);
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful',
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        // Handle error response
        String errorMessage = data['message'] ?? data['error'] ?? 'Registration failed';
        
        // Handle validation errors from express-validator
        if (data['errors'] != null) {
          if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            // errors.array() format from express-validator
            final errorsList = data['errors'] as List;
            final firstError = errorsList.first;
            if (firstError is Map && firstError['msg'] != null) {
              errorMessage = firstError['msg'].toString();
            } else {
              errorMessage = firstError.toString();
            }
          } else if (data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
            // Other error format
            final errorsMap = data['errors'] as Map;
            errorMessage = errorsMap.values.first.toString();
          }
        }
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      String errorMessage = 'Connection error';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Get Profile API (مع token)
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No token found. Please login again.',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveUserData(data);
        return {
          'success': true,
          'user': data,
        };
      } else {
        // إذا كان token غير صحيح، احذف البيانات المحفوظة
        if (response.statusCode == 401) {
          await clearAuthData();
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get profile',
        };
      }
    } catch (e) {
      String errorMessage = 'Connection error';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Request Password Reset API
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset/request'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'email': email.trim(),
        }),
      ).timeout(AppConfig.requestTimeout);

      final data = jsonDecode(response.body);

      return {
        'success': data['emailSent'] == true || data['message'] != null,
        'message': data['message'] ?? 'Verification code sent to your email',
        'debugCode': data['debugCode'], // For development only
      };
    } catch (e) {
      String errorMessage = 'Connection error';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Verify Reset Code API
  static Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final body = jsonEncode({
        'email': email.trim(),
        'code': code.trim(),
      });

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset/verify'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(body),
      ).timeout(AppConfig.requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['verified'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Code verified successfully',
          'verified': true,
        };
      } else {
        String errorMessage =
            data['message'] ?? data['error'] ?? 'Invalid verification code';

        // Handle validation errors
        if (data['errors'] != null) {
          if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            final errorsList = data['errors'] as List;
            final firstError = errorsList.first;
            if (firstError is Map && firstError['msg'] != null) {
              errorMessage = firstError['msg'].toString();
            }
          }
        }

        return {
          'success': false,
          'message': errorMessage,
          'verified': false,
        };
      }
    } catch (e) {
      String errorMessage = 'Connection error';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
        'verified': false,
      };
    }
  }

  // Reset Password API (using email and code)
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final body = jsonEncode({
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      });

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset/confirm'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(body),
      ).timeout(AppConfig.requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successful',
        };
      } else {
        String errorMessage = data['message'] ?? data['error'] ?? 'Password reset failed';

        // Handle validation errors
        if (data['errors'] != null) {
          if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            final errorsList = data['errors'] as List;
            final firstError = errorsList.first;
            if (firstError is Map && firstError['msg'] != null) {
              errorMessage = firstError['msg'].toString();
            }
          }
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      String errorMessage = 'Connection error';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }
}

