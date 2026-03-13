import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthStorageService {
  static const _keyIsLoggedIn = 'is_logged_in';
  static const _keyUserEmail = 'user_email';
  static const _keyPendingSignInEmail = 'pending_sign_in_email';
  static const _keyPendingSignupData = 'pending_signup_data';

  static Future<void> setLoggedIn({required bool value, String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, value);
    if (email != null) {
      await prefs.setString(_keyUserEmail, email);
    } else {
      await prefs.remove(_keyUserEmail);
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  static Future<void> setPendingSignInEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingSignInEmail, email);
  }

  static Future<String?> getPendingSignInEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPendingSignInEmail);
  }

  static Future<void> clearPendingSignInEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingSignInEmail);
  }

  static Future<void> setPendingSignupData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingSignupData, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getPendingSignupData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingSignupData);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
    }

    return null;
  }

  static Future<void> clearPendingSignupData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingSignupData);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyPendingSignInEmail);
    await prefs.remove(_keyPendingSignupData);
  }
}
