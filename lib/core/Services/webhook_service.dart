import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class WebhookService {
  static const String _webhookUrl = 'https://muhacks.app.n8n.cloud/webhook/cb7d7971-c81f-4472-8520-d8c64e37263d';

  /// Sends user data to the webhook when call button is clicked
  static Future<bool> sendUserDataToWebhook() async {
    try {
      final user = AuthService.getCurrentUser();
      final profile = await AuthService.getCurrentUserProfile();
      
      if (user == null) {
        if (kDebugMode) {
          print('No user logged in');
        }
        return false;
      }

      final firstName = profile?['first_name']?.toString() ?? '';
      final lastName = profile?['last_name']?.toString() ?? '';
      final userName = '$firstName $lastName'.trim();
      final phoneNumber = profile?['phone']?.toString() ?? '';
      final email = user.email ?? '';

      // Build query parameters for GET request
      final queryParams = {
        'name': userName,
        'mobile_number': phoneNumber,
        'email': email,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'call_button_clicked'
      };

      // Create URI with query parameters
      final uri = Uri.parse(_webhookUrl).replace(queryParameters: queryParams);

      // Send GET request to webhook
      final response = await http.get(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
          print('Webhook sent successfully: ${response.body}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Webhook failed with status: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending webhook: $e');
      }
      return false;
    }
  }
}
