import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  static const _keyIsLoggedIn = 'is_logged_in';
  static const _keyUserEmail = 'user_email';

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

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserEmail);
  }
}
