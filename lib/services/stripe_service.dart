import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';

class StripeService {
  static const _baseUrl = 'https://us-central1-projectpulse-7d258.cloudfunctions.net';

  /// Show the Stripe Payment Sheet in-app
  /// Returns true if payment succeeded, false if cancelled/failed
  static Future<bool> showPaymentSheet({
    required BuildContext context,
    required String projectId,
    required String invoiceId,
    required double amount,
    required String milestoneName,
    String? clientEmail,
    String? contractorName,
  }) async {
    try {
      // 1. Create PaymentIntent on server
      final response = await http.post(
        Uri.parse('$_baseUrl/createPaymentIntent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'projectId': projectId,
          'invoiceId': invoiceId,
          'amount': amount,
          'milestoneName': milestoneName,
          'clientEmail': clientEmail,
          'contractorName': contractorName,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('PaymentIntent error: ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'] as String?;
      final customerId = data['customerId'] as String?;
      final ephemeralKey = data['ephemeralKey'] as String?;
      final totalCharge = (data['totalCharge'] as num?)?.toDouble() ?? 0;
      final processingFee = (data['processingFee'] as num?)?.toDouble() ?? 0;

      if (clientSecret == null) {
        debugPrint('No client secret returned');
        return false;
      }

      final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

      // 2. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          merchantDisplayName: contractorName ?? 'ProjectPulse',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF2D3748),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12,
            ),
          ),
        ),
      );

      // 3. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // If we get here, payment succeeded (presentPaymentSheet throws on cancel/failure)
      debugPrint('✅ Payment succeeded for invoice $invoiceId');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('Payment cancelled by user');
      } else {
        debugPrint('Stripe error: ${e.error.localizedMessage}');
      }
      return false;
    } catch (e) {
      debugPrint('Payment error: $e');
      return false;
    }
  }
}
