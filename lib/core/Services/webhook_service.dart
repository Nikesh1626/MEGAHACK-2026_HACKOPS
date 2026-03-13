import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class WebhookService {
  static const String _webhookUrl = 'https://muhacks.app.n8n.cloud/webhook/cb7d7971-c81f-4472-8520-d8c64e37263d';

  /// Sends user data to the webhook when call button is clicked
  static Future<bool> sendUserDataToWebhook() async {
    try {
      // Get current user from Supabase
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user == null) {
        if (kDebugMode) {
          print('No user logged in');
        }
        return false;
      }

      // Extract user data from metadata
      final userName = '${user.userMetadata?['first_name'] ?? ''} ${user.userMetadata?['last_name'] ?? ''}'.trim();
      final phoneNumber = user.userMetadata?['phone'] ?? '';
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
