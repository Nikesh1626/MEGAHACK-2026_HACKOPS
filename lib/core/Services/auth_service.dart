import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_otp/email_otp.dart';
import '../constants/firestore_schema.dart';

class AuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final EmailOTP _emailOTP = EmailOTP();

  // Sign up with email and password
  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required int age,
  }) async {
    final response = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await response.user?.updateDisplayName('$firstName $lastName'.trim());

    if (response.user != null) {
      try {
        await _firestore
            .collection(FsCollections.users)
            .doc(response.user!.uid)
            .set({
          FsFields.firstName: firstName,
          FsFields.lastName: lastName,
          FsFields.phone: phone,
          FsFields.age: age,
          FsFields.email: email,
          FsFields.createdAt: FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    return response;
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
  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Send passwordless sign-in link
  static Future<void> sendPasswordlessSignInLink({
    required String email,
    required String redirectUrl,
  }) async {
    final actionCodeSettings = ActionCodeSettings(
      url: redirectUrl,
      handleCodeInApp: true,
    );

    await _firebaseAuth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }

  // Check if current URL is an email sign-in link
  static bool isPasswordlessSignInLink(String emailLink) {
    return _firebaseAuth.isSignInWithEmailLink(emailLink);
  }

  // Complete passwordless email-link sign-in
  static Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    return _firebaseAuth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
  }

  static bool isEmailVerificationLink(Uri uri) {
    return uri.queryParameters['mode'] == 'verifyEmail' &&
        (uri.queryParameters['oobCode']?.isNotEmpty ?? false);
  }

  static Future<void> applyEmailVerificationCode(String code) async {
    await _firebaseAuth.applyActionCode(code);
  }

  static Future<void> upsertUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String phone,
    required int age,
    required String email,
  }) async {
    await _firestore.collection(FsCollections.users).doc(uid).set({
      FsFields.firstName: firstName,
      FsFields.lastName: lastName,
      FsFields.phone: phone,
      FsFields.age: age,
      FsFields.email: email,
      FsFields.createdAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Get current user
  static User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    return _firebaseAuth.currentUser != null;
  }

  // Listen to auth state changes
  static Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges();
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      final doc =
          await _firestore.collection(FsCollections.users).doc(user.uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (_) {}

    return {
      FsFields.firstName: (user.displayName ?? '').split(' ').first,
      FsFields.lastName: (user.displayName ?? '').split(' ').skip(1).join(' '),
      FsFields.phone: '',
      FsFields.age: null,
      FsFields.email: user.email,
    };
  }
}
