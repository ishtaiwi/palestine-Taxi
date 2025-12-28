import 'dart:convert' show jsonEncode, jsonDecode, utf8;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  static Future<Map<String, dynamic>> uploadProfileImage(
      String imagePath) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/profile/avatar');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final file = await http.MultipartFile.fromPath('avatar', imagePath);
      request.files.add(file);

      final streamedResponse =
          await request.send().timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map) {
        if (decoded['user'] != null && decoded['user'] is Map) {
          await saveUserData(Map<String, dynamic>.from(decoded['user'] as Map));
        }

        return {
          'success': true,
          'message': decoded['message'] ?? 'Avatar uploaded successfully',
          'avatarUrl': decoded['avatarUrl'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] != null
            ? decoded['message']
            : 'Failed to upload avatar',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<void> saveLanguagePreference(bool isArabic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_arabic', isArabic);
  }

  static Future<bool> getLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('language_arabic') ?? true;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final requestBody = jsonEncode({
        'email': email.trim(),
        'password': password,
      });

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
            body: utf8.encode(requestBody),
          )
          .timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final isSuccess = responseData['success'] == true ||
            responseData['success'] == 'true';

        if (isSuccess) {
          if (responseData['token'] != null) {
            await saveToken(responseData['token']);
          }
          if (responseData['user'] != null) {
            await saveUserData(responseData['user']);
          }
          return {
            'success': true,
            'message': responseData['message'] ?? 'Login successful',
            'token': responseData['token'],
            'user': responseData['user'],
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Login failed',
            'approvalStatus': responseData['approvalStatus'],
          };
        }
      } else {
        // Handle 403 (Forbidden) for non-approved drivers
        return {
          'success': false,
          'message': responseData['message'] ?? 'Login failed',
          'approvalStatus': responseData['approvalStatus'],
        };
      }
    } catch (exception) {
      String errorMessage = 'Connection error';
      if (exception.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (exception.toString().contains('SocketException')) {
        errorMessage =
            'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${exception.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String phone,
    required String password,
    String role = 'PASSENGER',
    String? licenseId,
    String? lineId,
    String? vehiclePlate,
    String? vehicleSeatLayout,
  }) async {
    try {
      final requestBody = {
        'fullname': fullname,
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'role': role.toLowerCase(),
      };

      if (licenseId != null && licenseId.isNotEmpty) {
        requestBody['licenseid'] = licenseId.trim();
      }

      if (lineId != null && lineId.isNotEmpty) {
        requestBody['lineid'] = lineId.trim();
      }

      if (vehiclePlate != null && vehiclePlate.isNotEmpty) {
        requestBody['vehiclePlate'] = vehiclePlate.trim();
      }

      if (vehicleSeatLayout != null && vehicleSeatLayout.isNotEmpty) {
        requestBody['vehicleSeatLayout'] = vehicleSeatLayout.trim();
      }

      print('[ApiService.register] 📤 Sending registration data:');
      print('  - fullname: ${requestBody['fullname']}');
      print('  - email: ${requestBody['email']}');
      print('  - phone: ${requestBody['phone']}');
      print('  - role: ${requestBody['role']}');
      print('  - licenseid: ${requestBody['licenseid'] ?? 'null'}');
      print('  - lineid: ${requestBody['lineid'] ?? 'null'}');
      print('  - vehiclePlate: ${requestBody['vehiclePlate'] ?? 'null'}');
      print(
          '  - vehicleSeatLayout: ${requestBody['vehicleSeatLayout'] ?? 'null'}');
      print('  - All keys: ${requestBody.keys.toList()}');

      final requestBodyJson = jsonEncode(requestBody);

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/auth/register'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
            body: utf8.encode(requestBodyJson),
          )
          .timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(response.body);

      print('[ApiService.register] 📥 Received response:');
      print('  - Status: ${response.statusCode}');
      print('  - Has success: ${responseData['success']}');
      print('  - Has token: ${responseData['token'] != null}');
      print('  - Has user: ${responseData['user'] != null}');
      print('  - Has vehicle: ${responseData['vehicle'] != null}');
      if (responseData['vehicle'] != null) {
        print('  - Vehicle data: ${responseData['vehicle']}');
      }

      final isSuccess = response.statusCode == 201 ||
          response.statusCode == 200 ||
          responseData['success'] == true ||
          responseData['success'] == 'true';

      if (isSuccess && responseData['token'] != null) {
        try {
          if (responseData['token'] != null) {
            await saveToken(responseData['token']);
          }
          if (responseData['user'] != null) {
            await saveUserData(responseData['user']);
          }

          print('[ApiService.register] ✅ Registration successful');
          print('  - User saved: ${responseData['user'] != null}');
          print('  - Token saved: ${responseData['token'] != null}');
          print('  - Approval Status: ${responseData['approvalStatus'] ?? 'N/A'}');

          return {
            'success': true,
            'message': responseData['message'] ?? 'Registration successful',
            'token': responseData['token'],
            'user': responseData['user'],
            'vehicle': responseData['vehicle'],
            'approvalStatus': responseData['approvalStatus'],
          };
        } catch (saveError) {
          print('[ApiService.register] ⚠️ Error saving data: $saveError');

          return {
            'success': true,
            'message': responseData['message'] ?? 'Registration successful',
            'token': responseData['token'],
            'user': responseData['user'],
            'vehicle': responseData['vehicle'],
            'approvalStatus': responseData['approvalStatus'],
          };
        }
      } else {
        String errorMessage = responseData['message'] ??
            responseData['error'] ??
            'Registration failed';

        if (responseData['errors'] != null) {
          if (responseData['errors'] is List &&
              (responseData['errors'] as List).isNotEmpty) {
            final validationErrors = responseData['errors'] as List;
            final firstValidationError = validationErrors.first;
            if (firstValidationError is Map &&
                firstValidationError['msg'] != null) {
              errorMessage = firstValidationError['msg'].toString();
            } else {
              errorMessage = firstValidationError.toString();
            }
          } else if (responseData['errors'] is Map &&
              (responseData['errors'] as Map).isNotEmpty) {
            final errorsMap = responseData['errors'] as Map;
            errorMessage = errorsMap.values.first.toString();
          }
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (exception) {
      String errorMessage = 'Connection error';
      if (exception.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (exception.toString().contains('SocketException')) {
        errorMessage =
            'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${exception.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<List<Map<String, dynamic>>> fetchActiveLines() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/lines/active'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((line) => Map<String, dynamic>.from(line))
              .toList();
        }
        throw Exception('Unexpected response format');
      } else {
        final decoded = jsonDecode(response.body);
        throw Exception(
          decoded is Map && decoded['message'] is String
              ? decoded['message']
              : 'Failed to load lines',
        );
      }
    } catch (exception) {
      throw Exception(
        exception.toString().contains('TimeoutException')
            ? 'Connection timeout. Please check your internet connection.'
            : exception.toString(),
      );
    }
  }

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

      final userData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveUserData(userData);
        return {
          'success': true,
          'user': userData,
        };
      } else {
        if (response.statusCode == 401) {
          await clearAuthData();
        }
        return {
          'success': false,
          'message': userData['message'] ?? 'Failed to get profile',
        };
      }
    } catch (exception) {
      String errorMessage = 'Connection error';
      if (exception.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (exception.toString().contains('SocketException')) {
        errorMessage =
            'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${exception.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final requestBody = jsonEncode({
        'email': email.trim(),
      });

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset/request'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
            body: requestBody,
          )
          .timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(response.body);

      return {
        'success': responseData['emailSent'] == true ||
            responseData['message'] != null,
        'message':
            responseData['message'] ?? 'Verification code sent to your email',
        'debugCode': responseData['debugCode'],
      };
    } catch (exception) {
      String errorMessage = 'Connection error';
      if (exception.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (exception.toString().contains('SocketException')) {
        errorMessage =
            'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${exception.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final requestBody = jsonEncode({
        'email': email.trim(),
        'code': code.trim(),
      });

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset/verify'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
            body: utf8.encode(requestBody),
          )
          .timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['verified'] == true) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Code verified successfully',
          'verified': true,
        };
      } else {
        String errorMessage = responseData['message'] ??
            responseData['error'] ??
            'Invalid verification code';

        if (responseData['errors'] != null) {
          if (responseData['errors'] is List &&
              (responseData['errors'] as List).isNotEmpty) {
            final validationErrors = responseData['errors'] as List;
            final firstValidationError = validationErrors.first;
            if (firstValidationError is Map &&
                firstValidationError['msg'] != null) {
              errorMessage = firstValidationError['msg'].toString();
            }
          }
        }

        return {
          'success': false,
          'message': errorMessage,
          'verified': false,
        };
      }
    } catch (exception) {
      String errorMessage = 'Connection error';
      if (exception.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (exception.toString().contains('SocketException')) {
        errorMessage =
            'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${exception.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
        'verified': false,
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final requestBody = jsonEncode({
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      });

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset/confirm'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
            body: utf8.encode(requestBody),
          )
          .timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Password reset successful',
        };
      } else {
        String errorMessage = responseData['message'] ??
            responseData['error'] ??
            'Password reset failed';

        if (responseData['errors'] != null) {
          if (responseData['errors'] is List &&
              (responseData['errors'] as List).isNotEmpty) {
            final validationErrors = responseData['errors'] as List;
            final firstValidationError = validationErrors.first;
            if (firstValidationError is Map &&
                firstValidationError['msg'] != null) {
              errorMessage = firstValidationError['msg'].toString();
            }
          }
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (exception) {
      String errorMessage = 'Connection error';
      if (exception.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (exception.toString().contains('SocketException')) {
        errorMessage =
            'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${exception.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> fetchDriverQueue() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/drivers/queue'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...responseData,
        };
      }

      return {
        'success': false,
        'message': responseData['message'] ?? 'Failed to load queue',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> joinDriverQueue() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/drivers/queue/join'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          ...responseData,
        };
      }

      return {
        'success': false,
        'message': responseData['message'] ?? 'Failed to join queue',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> leaveDriverQueue() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/drivers/queue/leave'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...responseData,
        };
      }

      return {
        'success': false,
        'message': responseData['message'] ?? 'Failed to leave queue',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDriverTrips({
    bool upcomingOnly = true,
    String? status,
  }) async {
    final token = await getToken();
    if (token == null) {
      return [];
    }

    final queryParams = <String, String>{
      if (upcomingOnly) 'upcoming': 'true',
      if (status != null && status.isNotEmpty) 'status': status,
    };

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/drivers/trips')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    }

    return [];
  }

  static Future<Map<String, dynamic>> fetchDriverTripReservations(
      String tripId) async {
    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated',
      };
    }

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/drivers/trips/$tripId/reservations'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return {
        'success': true,
        ...decoded,
      };
    }

    return {
      'success': false,
      'message': decoded is Map && decoded['message'] is String
          ? decoded['message']
          : 'Failed to load reservations',
    };
  }

  static Future<Map<String, dynamic>> updateDriverReservationStatus({
    required String tripId,
    required String bookingId,
    required String action,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated',
      };
    }

    final response = await http.patch(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/drivers/trips/$tripId/reservations/$bookingId'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
      body: utf8.encode(jsonEncode({'action': action})),
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return {
        'success': true,
        ...decoded,
      };
    }

    return {
      'success': false,
      'message': decoded is Map && decoded['message'] is String
          ? decoded['message']
          : 'Failed to update reservation',
    };
  }

  static Future<Map<String, dynamic>> getDriverProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/drivers/profile'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load driver profile');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDriverVehicles() async {
    final token = await getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/vehicles/driver/my-vehicles'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json; charset=utf-8',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    }

    return [];
  }

  static Future<Map<String, dynamic>> createMyVehicle({
    required String plateno,
    required String seatlayout,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/vehicles/driver/my-vehicle'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'plateno': plateno.trim(),
              'seatlayout': seatlayout,
            }),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Vehicle created successfully',
          'vehicle': decoded['vehicle'],
        };
      }

      String errorMessage = 'Failed to create vehicle';
      if (decoded is Map) {
        if (decoded['message'] is String) {
          errorMessage = decoded['message'];
        } else if (decoded['error'] is String) {
          errorMessage = decoded['error'];
        }
      }

      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (exception) {
      String errorMessage = 'Connection error';
      if (exception.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet connection.';
      } else if (exception.toString().contains('SocketException')) {
        errorMessage =
            'Cannot connect to server. Please make sure the backend is running.';
      } else {
        errorMessage = 'Error: ${exception.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> fetchVehicleSeatMap(
      String vehicleId) async {
    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated',
      };
    }

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/vehicles/$vehicleId/seatmap'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json; charset=utf-8',
      },
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return {
        'success': true,
        ...decoded,
      };
    }

    return {
      'success': false,
      'message': decoded is Map && decoded['message'] is String
          ? decoded['message']
          : 'Failed to load seat map',
    };
  }

  static Future<Map<String, dynamic>> updateVehicleBrokenSeats(
    String vehicleId,
    List<String> seats,
  ) async {
    final token = await getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated',
      };
    }

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/vehicles/$vehicleId/broken-seats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json; charset=utf-8',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'seats': seats,
      }),
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return {
        'success': true,
        ...decoded,
      };
    }

    return {
      'success': false,
      'message': decoded is Map && decoded['message'] is String
          ? decoded['message']
          : 'Failed to update seat state',
    };
  }

  static Future<List<Map<String, dynamic>>> fetchUpcomingTrips({
    String? lineid,
    String? date,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (lineid != null && lineid.isNotEmpty) queryParams['lineid'] = lineid;
      if (date != null && date.isNotEmpty) queryParams['date'] = date;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/trips/upcoming').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } catch (exception) {
      throw Exception('Failed to fetch trips: ${exception.toString()}');
    }
  }

  static Future<Map<String, dynamic>> fetchTripById(String tripId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/trips/$tripId'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is Map<String, dynamic> ? decoded : {};
      }
      throw Exception('Failed to fetch trip');
    } catch (exception) {
      throw Exception('Failed to fetch trip: ${exception.toString()}');
    }
  }

  static Future<Map<String, dynamic>> createReservation({
    String? tripid,
    String? lineid,
    String? seatlocation,
    String? dropoffpoint,
    String? aging,
    String? paymentmethod,
    String? booking_type,
    String? scheduled_trip_time,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final body = <String, dynamic>{};
      if (tripid != null) body['tripid'] = tripid;
      if (lineid != null) body['lineid'] = lineid;
      if (seatlocation != null) body['seatlocation'] = seatlocation;
      if (dropoffpoint != null) body['dropoffpoint'] = dropoffpoint;
      if (aging != null) body['aging'] = aging;
      if (paymentmethod != null) body['paymentmethod'] = paymentmethod;
      if (booking_type != null) body['booking_type'] = booking_type;
      if (scheduled_trip_time != null)
        body['scheduled_trip_time'] = scheduled_trip_time;

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/reservations'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to create reservation',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPassengerReservations({
    String? status,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return [];

      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final uri =
          Uri.parse('${AppConfig.apiBaseUrl}/reservations/my-reservations')
              .replace(
                  queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } catch (exception) {
      throw Exception('Failed to fetch reservations: ${exception.toString()}');
    }
  }

  static Future<Map<String, dynamic>> cancelReservation(
      String bookingId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/reservations/$bookingId/cancel'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to cancel reservation',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchWallet() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/wallets/my-wallet'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to fetch wallet',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> addWalletBalance(double amount) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/wallets/add-balance'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode({'amount': amount})),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to add balance',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> createStripeWalletTopup(
      double amount) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/wallets/stripe-topup'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode({'amount': amount})),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map) {
        return decoded.cast<String, dynamic>();
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to create Stripe top-up',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> startTrip(String tripId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/trips/$tripId/start'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to start trip',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> endTrip(String tripId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/trips/$tripId/end'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to end trip',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> checkInReservation(String? bookingId,
      {String? qrData}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final body = <String, dynamic>{};
      if (bookingId != null) body['bookingid'] = bookingId;
      if (qrData != null) body['qrData'] = qrData;

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/reservations/check-in'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to check-in',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getReservationQRCode(
      String bookingId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/reservations/$bookingId/qrcode'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          ...decoded,
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to get QR code',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSchedules(
      {String? lineid, bool? active}) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      String url = '${AppConfig.apiBaseUrl}/schedules';
      final queryParams = <String, String>{};
      if (lineid != null) queryParams['lineid'] = lineid;
      if (active != null) queryParams['active'] = active.toString();

      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['schedules'] is List) {
          return (decoded['schedules'] as List)
              .map((s) => Map<String, dynamic>.from(s))
              .toList();
        }
        throw Exception('Unexpected response format');
      } else {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          decoded is Map && decoded['message'] is String
              ? decoded['message']
              : 'Failed to load schedules',
        );
      }
    } catch (exception) {
      throw Exception(
        exception.toString().contains('TimeoutException')
            ? 'Connection timeout. Please check your internet connection.'
            : exception.toString(),
      );
    }
  }

  static Future<Map<String, dynamic>> getScheduleById(String templateid) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/schedules/$templateid'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['schedule'] is Map) {
          return Map<String, dynamic>.from(decoded['schedule']);
        }
        throw Exception('Unexpected response format');
      } else {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          decoded is Map && decoded['message'] is String
              ? decoded['message']
              : 'Failed to load schedule',
        );
      }
    } catch (exception) {
      throw Exception(
        exception.toString().contains('TimeoutException')
            ? 'Connection timeout. Please check your internet connection.'
            : exception.toString(),
      );
    }
  }

  static Future<Map<String, dynamic>> createSchedule({
    required String lineid,
    required int startHour,
    required int endHour,
    required int intervalMinutes,
    bool active = true,
    bool? autoDepartureEnabled,
    bool? scheduledDepartureEnforced,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/schedules'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode({
              'lineid': lineid,
              'start_hour': startHour,
              'end_hour': endHour,
              'interval_minutes': intervalMinutes,
              'active': active,
              if (autoDepartureEnabled != null) 'auto_departure_enabled': autoDepartureEnabled,
              if (scheduledDepartureEnforced != null) 'scheduled_departure_enforced': scheduledDepartureEnforced,
            })),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Schedule created successfully',
          'schedule': decoded['schedule'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to create schedule',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> updateSchedule(
    String templateid, {
    String? lineid,
    int? startHour,
    int? endHour,
    int? intervalMinutes,
    bool? active,
    bool? autoDepartureEnabled,
    bool? scheduledDepartureEnforced,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final body = <String, dynamic>{};
      if (lineid != null) body['lineid'] = lineid;
      if (startHour != null) body['start_hour'] = startHour;
      if (endHour != null) body['end_hour'] = endHour;
      if (intervalMinutes != null) body['interval_minutes'] = intervalMinutes;
      if (active != null) body['active'] = active;
      if (autoDepartureEnabled != null) body['auto_departure_enabled'] = autoDepartureEnabled;
      if (scheduledDepartureEnforced != null) body['scheduled_departure_enforced'] = scheduledDepartureEnforced;

      final response = await http
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/schedules/$templateid'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Schedule updated successfully',
          'schedule': decoded['schedule'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to update schedule',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> deleteSchedule(String templateid) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/schedules/$templateid'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Schedule deleted successfully',
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to delete schedule',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> createTripsForSchedule(
    String templateid, {
    String? targetDate,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final body = <String, dynamic>{};
      if (targetDate != null) body['target_date'] = targetDate;

      final response = await http
          .post(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/schedules/$templateid/create-trips'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Trips created successfully',
          'result': decoded['result'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to create trips',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> triggerDailyTripCreation() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/schedules/daily/create-trips'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Daily trips creation completed',
          'result': decoded['result'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to create daily trips',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': exception.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> getRushHourPredictionsAdmin({
    required String lineId,
    int? daysAhead,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final queryParams = <String, String>{'lineid': lineId};
    if (daysAhead != null) queryParams['daysAhead'] = daysAhead.toString();

    final uri =
        Uri.parse('${AppConfig.apiBaseUrl}/admin/predictions/rush-hours')
            .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    ).timeout(AppConfig.requestTimeout);

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return {
      'success': response.statusCode == 200,
      'data': decoded,
      'message': decoded is Map<String, dynamic> && decoded['message'] is String
          ? decoded['message']
          : null,
    };
  }

  static Future<Map<String, dynamic>> getLineDemandAnalysisAdmin({
    String? lineId,
    int? limit,
    String? startDate,
    String? endDate,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final queryParams = <String, String>{};
    if (lineId != null && lineId.isNotEmpty) queryParams['lineid'] = lineId;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri =
        Uri.parse('${AppConfig.apiBaseUrl}/admin/predictions/line-demand')
            .replace(
                queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    ).timeout(AppConfig.requestTimeout);

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return {
      'success': response.statusCode == 200,
      'data': decoded,
      'message': decoded is Map<String, dynamic> && decoded['message'] is String
          ? decoded['message']
          : null,
    };
  }

  static Future<Map<String, dynamic>> getPredictionInsightsAdmin({
    int? limit,
    String? startDate,
    String? endDate,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/predictions/insights')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    ).timeout(AppConfig.requestTimeout);

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return {
      'success': response.statusCode == 200,
      'data': decoded,
      'message': decoded is Map<String, dynamic> && decoded['message'] is String
          ? decoded['message']
          : null,
    };
  }

  static Future<Map<String, dynamic>> triggerPredictionRetrain({
    String? lineId,
    String? startDate,
    String? endDate,
    String? bookingType,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final body = <String, dynamic>{};
    if (lineId != null) body['lineid'] = lineId;
    if (startDate != null) body['startDate'] = startDate;
    if (endDate != null) body['endDate'] = endDate;
    if (bookingType != null) body['booking_type'] = bookingType;

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/admin/predictions/retrain'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $token',
          },
          body: utf8.encode(jsonEncode(body)),
        )
        .timeout(AppConfig.requestTimeout);

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return {
      'success': response.statusCode == 200,
      'message': decoded['message'] ??
          (response.statusCode == 200 ? 'Retrain triggered' : 'Failed'),
      'summary': decoded['summary'],
    };
  }

  static Future<List<Map<String, dynamic>>> getScheduleRecommendationsAdmin({
    List<String>? lineIds,
    int? daysAhead,
    String? utilizationStartDate,
    String? utilizationEndDate,
  }) async {
    final token = await getToken();
    if (token == null) {
      return [];
    }

    final queryParams = <String, String>{};
    if (lineIds != null && lineIds.isNotEmpty)
      queryParams['lineids'] = lineIds.join(',');
    if (daysAhead != null) queryParams['daysAhead'] = daysAhead.toString();
    if (utilizationStartDate != null)
      queryParams['utilizationStartDate'] = utilizationStartDate;
    if (utilizationEndDate != null)
      queryParams['utilizationEndDate'] = utilizationEndDate;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/recommendations')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    ).timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> &&
          decoded['recommendations'] is List) {
        return (decoded['recommendations'] as List)
            .whereType<Map>()
            .map((rec) => Map<String, dynamic>.from(rec))
            .toList();
      }
    }

    return [];
  }

  static Future<Map<String, dynamic>> applyScheduleRecommendationAdmin(
    Map<String, dynamic> recommendation,
  ) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/admin/recommendations/apply'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $token',
          },
          body: utf8.encode(jsonEncode({'recommendation': recommendation})),
        )
        .timeout(AppConfig.requestTimeout);

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return {
      'success': response.statusCode == 200,
      'message': decoded['message'] ??
          (response.statusCode == 200 ? 'Recommendation applied' : 'Failed'),
      'result': decoded['result'],
    };
  }

  static Future<List<Map<String, dynamic>>> getAllLines() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/lines'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded
              .map((line) => Map<String, dynamic>.from(line))
              .toList();
        }
        throw Exception('Unexpected response format');
      } else {
        throw Exception('Failed to load lines');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> createLine({
    String? nameAr,
    String? nameEn,
    String? linename,
    required double baseprice,
    double? additionalprice,
    int? estduration,
    double? distance,
    bool active = true,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{
        'baseprice': baseprice,
        'additionalprice': additionalprice ?? 0,
        'active': active,
      };

      if (nameAr != null && nameAr.isNotEmpty) {
        body['name_ar'] = nameAr;
      }
      if (nameEn != null && nameEn.isNotEmpty) {
        body['name_en'] = nameEn;
      }

      if ((nameAr == null || nameAr.isEmpty) &&
          linename != null &&
          linename.isNotEmpty) {
        body['linename'] = linename;
      }

      if (estduration != null) body['estduration'] = estduration;
      if (distance != null) body['distance'] = distance;

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/lines'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 201,
        'message': decoded['message'] ??
            (response.statusCode == 201 ? 'Line created' : 'Failed'),
        'line': decoded['line'],
      };
    } catch (exception) {
      return {'success': false, 'message': exception.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateLine(
    String lineid, {
    String? nameAr,
    String? nameEn,
    String? linename,
    double? baseprice,
    double? additionalprice,
    int? estduration,
    double? distance,
    bool? active,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{};

      if (nameAr != null && nameAr.isNotEmpty) {
        body['name_ar'] = nameAr;
      }
      if (nameEn != null && nameEn.isNotEmpty) {
        body['name_en'] = nameEn;
      }
      if (linename != null && linename.isNotEmpty) {
        body['linename'] = linename;
      }
      if (baseprice != null) body['baseprice'] = baseprice;
      if (additionalprice != null) body['additionalprice'] = additionalprice;
      if (estduration != null) body['estduration'] = estduration;
      if (distance != null) body['distance'] = distance;
      if (active != null) body['active'] = active;

      final response = await http
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/lines/$lineid'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': decoded['message'] ??
            (response.statusCode == 200 ? 'Line updated' : 'Failed'),
        'line': decoded['line'],
      };
    } catch (exception) {
      return {'success': false, 'message': exception.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteLine(String lineid) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/lines/$lineid'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': decoded['message'] ??
            (response.statusCode == 200 ? 'Line deleted' : 'Failed'),
      };
    } catch (exception) {
      return {'success': false, 'message': exception.toString()};
    }
  }

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
      } else {
        throw Exception('Failed to load dashboard stats');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> getRevenueAnalytics({
    String? startDate,
    String? endDate,
    String? lineid,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (lineid != null) queryParams['lineid'] = lineid;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/dashboard/revenue')
          .replace(
              queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load revenue analytics');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> getRevenueTimeSeries({
    String? startDate,
    String? endDate,
    String? groupBy,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (groupBy != null) queryParams['groupBy'] = groupBy;

      final uri =
          Uri.parse('${AppConfig.apiBaseUrl}/admin/reports/revenue-timeseries')
              .replace(
                  queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load revenue time series');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> getBookingTimeSeries({
    String? startDate,
    String? endDate,
    String? groupBy,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (groupBy != null) queryParams['groupBy'] = groupBy;

      final uri =
          Uri.parse('${AppConfig.apiBaseUrl}/admin/reports/booking-timeseries')
              .replace(
                  queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load booking time series');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> getTripStatistics({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri =
          Uri.parse('${AppConfig.apiBaseUrl}/admin/reports/trip-statistics')
              .replace(
                  queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load trip statistics');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> getUserGrowth({
    String? startDate,
    String? endDate,
    String? groupBy,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (groupBy != null) queryParams['groupBy'] = groupBy;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/reports/user-growth')
          .replace(
              queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load user growth data');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> getVehicleUtilization({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri =
          Uri.parse('${AppConfig.apiBaseUrl}/admin/reports/vehicle-utilization')
              .replace(
                  queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load vehicle utilization data');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> getLinePerformance({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri =
          Uri.parse('${AppConfig.apiBaseUrl}/admin/reports/line-performance')
              .replace(
                  queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else {
        throw Exception('Failed to load line performance data');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

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

  static Future<Map<String, dynamic>> updateUser({
    required String userid,
    String? fullname,
    String? email,
    String? phone,
    String? role,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{};
      if (fullname != null) body['fullname'] = fullname;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (role != null) body['role'] = role;

      final response = await http
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/admin/users/$userid'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': decoded['message'] ??
            (response.statusCode == 200 ? 'User updated' : 'Failed'),
        'user': decoded['user'],
      };
    } catch (exception) {
      return {'success': false, 'message': exception.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteUser(String userid) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

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
        'message': decoded['message'] ??
            (response.statusCode == 200 ? 'User deleted' : 'Failed'),
      };
    } catch (exception) {
      return {'success': false, 'message': exception.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getAllVehicles() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/vehicles'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded.map((v) => Map<String, dynamic>.from(v)).toList();
        }
        throw Exception('Unexpected response format');
      } else {
        throw Exception('Failed to load vehicles');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getAllTrips(
      {String? lineid, String? status}) async {
    try {
      String url = '${AppConfig.apiBaseUrl}/trips';
      final params = <String, String>{};
      if (lineid != null) params['lineid'] = lineid;
      if (status != null) params['status'] = status;
      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded.map((t) => Map<String, dynamic>.from(t)).toList();
        }
        throw Exception('Unexpected response format');
      } else {
        throw Exception('Failed to load trips');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<List<Map<String, dynamic>>> getAllPayments({
    String? status,
    String? method,
    String? type,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      String url = '${AppConfig.apiBaseUrl}/payments';
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (method != null) params['method'] = method;
      if (type != null) params['type'] = type;
      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (decoded is List) {
          return decoded.map((p) => Map<String, dynamic>.from(p)).toList();
        } else if (decoded is Map && decoded['payments'] is List) {
          return (decoded['payments'] as List)
              .map((p) => Map<String, dynamic>.from(p))
              .toList();
        }
        throw Exception('Unexpected response format');
      } else {
        throw Exception('Failed to load payments');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> submitRating({
    required String bookingid,
    required int rating,
    String? comment,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/ratings'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode({
              'bookingid': bookingid,
              'rating': rating,
              if (comment != null && comment.isNotEmpty) 'comment': comment,
            })),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 201,
        'message': decoded['message'] ??
            (response.statusCode == 201 ? 'Rating submitted' : 'Failed'),
        'rating': decoded['rating'],
      };
    } catch (exception) {
      return {'success': false, 'message': exception.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateRating({
    required String ratingid,
    int? rating,
    String? comment,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{};
      if (rating != null) body['rating'] = rating;
      if (comment != null) body['comment'] = comment;

      final response = await http
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/ratings/$ratingid'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': decoded['message'] ??
            (response.statusCode == 200 ? 'Rating updated' : 'Failed'),
        'rating': decoded['rating'],
      };
    } catch (exception) {
      return {'success': false, 'message': exception.toString()};
    }
  }

  static Future<Map<String, dynamic>?> getRatingByBookingId(
      String bookingid) async {
    try {
      final token = await getToken();
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/ratings/booking/$bookingid'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Map<String, dynamic>.from(decoded);
      } else if (response.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to load rating');
    } catch (exception) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getTripRatings(String tripid) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/ratings/trip/$tripid'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'ratings': decoded['ratings'] ?? [],
        'average': decoded['average'] ?? 0.0,
        'count': decoded['count'] ?? 0,
      };
    } catch (exception) {
      return {'success': false, 'ratings': [], 'average': 0.0, 'count': 0};
    }
  }

  static Future<List<Map<String, dynamic>>> getMyRatings() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/ratings/my-ratings'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded.map((r) => Map<String, dynamic>.from(r)).toList();
        }
        throw Exception('Unexpected response format');
      } else {
        throw Exception('Failed to load ratings');
      }
    } catch (exception) {
      throw Exception(exception.toString());
    }
  }

  static Future<Map<String, dynamic>> updateDriverLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/locations/update'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              if (heading != null) 'heading': heading,
              if (speed != null) 'speed': speed,
              if (accuracy != null) 'accuracy': accuracy,
            }),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Location updated successfully',
          'location': decoded['location'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to update location',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getMyLocation() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/locations/driver/my-location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'location': decoded['location'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Location not found',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getAllVehicleLocations({
    int? maxAgeMinutes,
    String? lineid,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final queryParams = <String, String>{};
      if (maxAgeMinutes != null) {
        queryParams['maxAgeMinutes'] = maxAgeMinutes.toString();
      }
      if (lineid != null) {
        queryParams['lineid'] = lineid;
      }

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/locations/admin/vehicles')
          .replace(
              queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'locations': decoded['locations'] ?? [],
          'count': decoded['count'] ?? 0,
        };
      }

      return {
        'success': false,
        'message': 'Failed to load vehicle locations',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getDriversAtBaseStation({
    String? stationid,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final queryParams = <String, String>{};
      if (stationid != null) {
        queryParams['stationid'] = stationid;
      }

      final uri = Uri.parse(
              '${AppConfig.apiBaseUrl}/locations/admin/base-station/drivers')
          .replace(
              queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'drivers': decoded['drivers'] ?? [],
          'count': decoded['count'] ?? 0,
        };
      }

      return {
        'success': false,
        'message': 'Failed to load drivers at base station',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getAllBaseStations({
    bool? isActive,
    String? lineid,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final queryParams = <String, String>{};
      if (isActive != null) {
        queryParams['is_active'] = isActive.toString();
      }
      if (lineid != null) {
        queryParams['lineid'] = lineid;
      }

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/base-station')
          .replace(
              queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'stations': decoded['stations'] ?? [],
          'count': decoded['count'] ?? 0,
        };
      }

      return {
        'success': false,
        'message': 'Failed to load base stations',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getBaseStationById(
      String stationid) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/admin/base-station/$stationid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'station': decoded['station'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to load base station',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createBaseStation({
    required String name,
    required double latitude,
    required double longitude,
    int? geofenceRadiusMeters,
    String? lineid,
    bool? isActive,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/admin/base-station'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'name': name,
              'latitude': latitude,
              'longitude': longitude,
              if (geofenceRadiusMeters != null)
                'geofence_radius_meters': geofenceRadiusMeters,
              if (lineid != null) 'lineid': lineid,
              if (isActive != null) 'is_active': isActive,
            }),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Base station created successfully',
          'station': decoded['station'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to create base station',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateBaseStation({
    required String stationid,
    String? name,
    double? latitude,
    double? longitude,
    int? geofenceRadiusMeters,
    String? lineid,
    bool? isActive,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/admin/base-station/$stationid'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              if (name != null) 'name': name,
              if (latitude != null) 'latitude': latitude,
              if (longitude != null) 'longitude': longitude,
              if (geofenceRadiusMeters != null)
                'geofence_radius_meters': geofenceRadiusMeters,
              if (lineid != null) 'lineid': lineid,
              if (isActive != null) 'is_active': isActive,
            }),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Base station updated successfully',
          'station': decoded['station'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to update base station',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteBaseStation(
      String stationid) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/admin/base-station/$stationid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Base station deleted successfully',
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to delete base station',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getLinePath(String lineid) async {
    try {
      final token = await getToken();
      final headers = <String, String>{
        'Accept': 'application/json; charset=utf-8',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/lines/$lineid/path'),
            headers: headers,
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'path': decoded['path'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Path not found',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createOrUpdateLinePath({
    required String lineid,
    required List<Map<String, dynamic>> waypoints,
    String? polyline,
    double? distanceMeters,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/admin/lines/$lineid/path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'waypoints': waypoints,
              if (polyline != null) 'polyline': polyline,
              if (distanceMeters != null) 'distance_meters': distanceMeters,
            }),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Line path saved successfully',
          'path': decoded['path'],
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to save line path',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteLinePath(String lineid) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/admin/lines/$lineid/path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Line path deleted successfully',
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to delete line path',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  /// Get Supabase configuration from server
  static Future<Map<String, dynamic>> getSupabaseConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/config/supabase'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        if (decoded['success'] == true) {
          return {
            'success': true,
            'url': decoded['url'],
            'anonKey': decoded['anonKey'],
          };
        }
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to get Supabase config',
        };
      }

      return {
        'success': false,
        'message': 'Failed to get Supabase config',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  /// Get timezone configuration (Admin only)
  static Future<Map<String, dynamic>> getTimezoneConfig() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/admin/config/timezone'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'timezone_offset': decoded['timezone_offset'] ?? 2,
          'timezone_name': decoded['timezone_name'] ?? 'UTC+2',
          'description': decoded['description'] ?? 'Palestine Standard Time',
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to get timezone configuration',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }

  /// Update timezone configuration (Admin only)
  static Future<Map<String, dynamic>> updateTimezoneConfig(
      int timezoneOffset) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/admin/config/timezone'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: utf8.encode(jsonEncode({
              'timezone_offset': timezoneOffset,
            })),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'message': decoded['message'] ??
              'Timezone configuration updated successfully',
          'timezone_offset': decoded['timezone_offset'] ?? timezoneOffset,
          'timezone_name': decoded['timezone_name'] ??
              (timezoneOffset >= 0
                  ? 'UTC+$timezoneOffset'
                  : 'UTC$timezoneOffset'),
        };
      }

      return {
        'success': false,
        'message': decoded is Map && decoded['message'] is String
            ? decoded['message']
            : 'Failed to update timezone configuration',
      };
    } catch (exception) {
      return {
        'success': false,
        'message': 'Connection error: ${exception.toString()}',
      };
    }
  }
}
