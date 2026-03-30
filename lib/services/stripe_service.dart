import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  // Cloud Function URL — will be set after deployment
  static const _baseUrl = 'https://us-central1-projectpulse-7d258.cloudfunctions.net';

  /// Create a Stripe Checkout session and open it in the browser
  static Future<bool> openCheckout({
    required String projectId,
    required String invoiceId,
    required double amount,
    required String milestoneName,
    String? clientEmail,
    String? contractorName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/createCheckoutSession'),
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['url'] as String?;
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
