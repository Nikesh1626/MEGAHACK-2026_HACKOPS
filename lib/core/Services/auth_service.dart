import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:email_otp/email_otp.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final EmailOTP _emailOTP = EmailOTP();

  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required int age,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'age': age,
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Send email OTP for verification
  static Future<bool> sendEmailOTP(String email) async {
    try {
      await _emailOTP.setConfig(
        appEmail: "contact@wellqueue.com", // Your app's email
        appName: "WellQueue",
        userEmail: email,
        otpLength: 6,
        otpType: OTPType.digitsOnly,
      );
      
      bool result = await _emailOTP.sendOTP();
      return result;
    } catch (e) {
      return false;
    }
  }

  // Verify email OTP
  static Future<bool> verifyEmailOTP(String otp) async {
    try {
      bool result = await _emailOTP.verifyOTP(otp: otp);
      return result;
    } catch (e) {
      return false;
    }
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Get current user
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    return _supabase.auth.currentUser != null;
  }

  // Listen to auth state changes
  static Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
