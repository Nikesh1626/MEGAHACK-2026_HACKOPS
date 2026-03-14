import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../LocationAccessScreen/location_access_screen.dart';
import '../../../core/constants/firestore_schema.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/auth_storage_service.dart';

enum AuthState {
  initial,
  signup,
  login,
  emailVerification,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthState _authState = AuthState.initial;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isSigningUp = false;
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  Timer? _verificationPollTimer;
  bool _isVerificationCheckRunning = false;

  @override
  void initState() {
    super.initState();
    _handleIncomingEmailVerificationLink();
    _completePasswordlessSignInIfNeeded();
  }

  Future<bool> _ensureVerifiedAndProceed(User user) async {
    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser == null || !refreshedUser.emailVerified) {
      return false;
    }

    final pendingSignupData = await AuthStorageService.getPendingSignupData();
    if (pendingSignupData != null) {
      final firstName = (pendingSignupData[FsFields.firstName] ?? '').toString();
      final lastName = (pendingSignupData[FsFields.lastName] ?? '').toString();
      final phone = (pendingSignupData[FsFields.phone] ?? '').toString();
      final email =
          (pendingSignupData[FsFields.email] ?? refreshedUser.email ?? '')
              .toString();
      final age = int.tryParse((pendingSignupData[FsFields.age] ?? '').toString()) ?? 0;

      if (firstName.isNotEmpty && email.isNotEmpty && age > 0) {
        try {
          await AuthService.upsertUserProfile(
            uid: refreshedUser.uid,
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            age: age,
            email: email,
          );
          await refreshedUser.updateDisplayName('$firstName $lastName'.trim());
        } catch (_) {
        }
      }
      await AuthStorageService.clearPendingSignupData();
    }

    await AuthStorageService.setLoggedIn(
      value: true,
      email: refreshedUser.email ?? _emailController.text.trim(),
    );

    _verificationPollTimer?.cancel();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LocationAccessScreen()),
        (Route<dynamic> route) => false,
      );
    }
    return true;
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 120);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining -= 1);
      }
    });
  }

  String _formatResendTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  Future<void> _checkEmailVerificationNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
        setState(() {
          _authState = AuthState.login;
          _isSigningUp = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    var verified = false;
    try {
      verified = await _ensureVerifiedAndProceed(user);
    } catch (_) {
      verified = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!verified && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not verified yet. Please check your inbox.')),
      );
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendSecondsRemaining > 0) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await user.sendEmailVerification();
      _startResendCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resend verification email.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startVerificationPolling() {
    _verificationPollTimer?.cancel();
    _verificationPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _authState != AuthState.emailVerification) return;
      if (_isVerificationCheckRunning) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _isVerificationCheckRunning = true;
      try {
        await _ensureVerifiedAndProceed(user);
      } catch (_) {
      } finally {
        _isVerificationCheckRunning = false;
      }
    });
  }

  Future<void> _handleIncomingEmailVerificationLink() async {
    final uri = Uri.base;
    if (!AuthService.isEmailVerificationLink(uri)) return;

    final code = uri.queryParameters['oobCode'];
    if (code == null || code.isEmpty) return;

    try {
      await AuthService.applyEmailVerificationCode(code);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _ensureVerifiedAndProceed(user);
      }
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _verificationPollTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Validation Methods ---
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName';
    }
    if (value.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your age';
    }
    final age = int.tryParse(value);
    if (age == null) {
      return 'Please enter a valid number';
    }
    if (age <= 0 || age > 120) {
      return 'Please enter a realistic age';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // --- UI Building Methods ---
  Widget _buildAuthHeader(String title, String subtitle) {
    return Column(
      children: [
        const Icon(Icons.local_hospital, size: 60, color: Colors.teal),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInitialView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAuthHeader('Welcome to WellQueue', 'Your Health, Your Time'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {
              _authState = AuthState.signup;
              _isSigningUp = true;
            }),
            child: const Text('Create Account'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.teal,
              side: const BorderSide(color: Colors.teal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() {
              _authState = AuthState.login;
              _isSigningUp = false;
            }),
            child: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildAuthHeader('Create Your Account', 'Get started with just a few details'),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
              validator: (value) => _validateName(value, 'first name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
              validator: (value) => _validateName(value, 'last name'),
            ),
            const SizedBox(height: 16),
            _buildPhoneNumberField(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email Address'),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              validator: _validateAge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: _validatePassword,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitSignup,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Account'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _authState = AuthState.login;
                _isSigningUp = false;
              }),
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAuthHeader('Welcome Back!', 'Login using your email and password'),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email Address'),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: _validatePassword,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitLogin,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Login'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _submitPasswordlessSignIn,
                child: const Text('Sign in with Email Link'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _authState = AuthState.signup;
                _isSigningUp = true;
              }),
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }

  // Aesthetic Phone Number field with static +91
  Widget _buildPhoneNumberField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      // Add these lines to enforce the 10-digit limit
      inputFormatters: [
        LengthLimitingTextInputFormatter(10), // <-- Limits input to 10 characters
        FilteringTextInputFormatter.digitsOnly, // <-- Allows only digits
      ],
      decoration: const InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Mobile Number',
        prefixIcon: Padding(
          padding: EdgeInsets.all(15.0),
          child: Text(
            '+91',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      validator: _validatePhone,
    );
  }

  Widget _buildEmailVerificationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAuthHeader(
            'Verify Your Email',
            'We sent a verification link to\n${_emailController.text.trim()}',
          ),
          const SizedBox(height: 12),
          const Text(
            'Open your email and click the link. Then return here, or the app will continue automatically after verification.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _checkEmailVerificationNow,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('I Have Verified'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: (_isLoading || _resendSecondsRemaining > 0)
                ? null
                : _resendVerificationEmail,
            child: Text(
              _resendSecondsRemaining > 0
                  ? 'Resend in ${_formatResendTime(_resendSecondsRemaining)}'
                  : 'Resend Verification Email',
            ),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    await AuthService.signOut();
                    _verificationPollTimer?.cancel();
                    if (mounted) {
                      setState(() {
                        _authState = AuthState.login;
                        _isSigningUp = false;
                      });
                    }
                  },
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  // --- Logic Methods ---
  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final signupData = {
        FsFields.firstName: _firstNameController.text.trim(),
        FsFields.lastName: _lastNameController.text.trim(),
        FsFields.phone: _phoneController.text.trim(),
        FsFields.age: _ageController.text.trim(),
        FsFields.email: _emailController.text.trim(),
      };
      await AuthStorageService.setPendingSignupData(signupData);

      final response = await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: int.parse(_ageController.text.trim()),
      );

      if (response.user != null) {
        await response.user?.sendEmailVerification();
        _startResendCountdown();
        _startVerificationPolling();
        setState(() => _isLoading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created. Please verify your email to continue.')),
          );
          setState(() => _authState = AuthState.emailVerification);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message;
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered. Please login instead.';
        setState(() {
          _authState = AuthState.login;
          _isSigningUp = false;
        });
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else {
        message = e.message ?? 'Sign up failed. Please try again.';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign up failed. Please try again.')),
        );
      }
    }
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        final verified = await _ensureVerifiedAndProceed(response.user!);
        setState(() => _isLoading = false);
        if (!verified && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please verify your email before login.')),
          );
          _startResendCountdown();
          _startVerificationPolling();
          setState(() => _authState = AuthState.emailVerification);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Login failed. Please try again.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _submitPasswordlessSignIn() async {
    final email = _emailController.text.trim();
    final emailValidationError = _validateEmail(email);
    if (emailValidationError != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emailValidationError)),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentBase = Uri.base;
      final redirectUri = Uri(
        scheme: currentBase.scheme,
        host: currentBase.host,
        port: currentBase.hasPort ? currentBase.port : null,
        path: '/',
      );

      await AuthService.sendPasswordlessSignInLink(
        email: email,
        redirectUrl: redirectUri.toString(),
      );
      await AuthStorageService.setPendingSignInEmail(email);

      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in link sent to $email. Open it from your inbox.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not send sign-in link.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send sign-in link: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _completePasswordlessSignInIfNeeded() async {
    final incomingLink = Uri.base.toString();
    if (!AuthService.isPasswordlessSignInLink(incomingLink)) return;

    String? email = await AuthStorageService.getPendingSignInEmail();
    email ??= await AuthStorageService.getSavedEmail();

    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your email in login screen and request a new sign-in link.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.signInWithEmailLink(
        email: email,
        emailLink: incomingLink,
      );

      await AuthStorageService.clearPendingSignInEmail();
      await AuthStorageService.setLoggedIn(
        value: true,
        email: response.user?.email ?? email,
      );

      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LocationAccessScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Email-link sign-in failed.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email-link sign-in failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WellQueue'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: _authState != AuthState.initial
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              if (_authState == AuthState.emailVerification) {
                _verificationPollTimer?.cancel();
                _authState = _isSigningUp ? AuthState.signup : AuthState.login;
              } else {
                _authState = AuthState.initial;
              }
            });
          },
        )
            : null,
      ),
      body: Center(
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_authState) {
      case AuthState.signup:
        return _buildSignupView();
      case AuthState.login:
        return _buildLoginView();
      case AuthState.emailVerification:
        return _buildEmailVerificationView();
      case AuthState.initial:
        return _buildInitialView();
    }
  }
}