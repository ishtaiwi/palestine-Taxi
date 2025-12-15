import 'dart:convert';

import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';

class StripeService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  
  
  
  
  static Future<Map<String, dynamic>> topUpWalletWithCard({
    required double amount,
    String currency = 'ils',
  }) async {
    await initialize();

    final token = await ApiService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated',
      };
    }

    
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/wallets/stripe-topup');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $token',
          },
          body: utf8.encode(
            jsonEncode({
              'amount': amount,
              'currency': currency,
            }),
          ),
        )
        .timeout(AppConfig.requestTimeout);

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode != 200 || decoded['success'] != true) {
      return {
        'success': false,
        'message': decoded['message']?.toString() ??
            'Failed to create Stripe payment',
      };
    }

    final clientSecret = decoded['clientSecret']?.toString();
    if (clientSecret == null) {
      return {
        'success': false,
        'message': 'Missing client secret from server',
      };
    }

    
    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
    } on StripeException catch (e) {
      return {
        'success': false,
        'message': e.error.message ?? 'Payment cancelled',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }

    
    return {
      'success': true,
      'message': 'Payment successful',
    };
  }
}


