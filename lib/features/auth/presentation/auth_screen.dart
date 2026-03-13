import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../LocationAccessScreen/location_access_screen.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/auth_storage_service.dart';

enum AuthState {
  initial,
  signup,
  login,
  otpVerification,
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
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isSigningUp = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _otpController.dispose();
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
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Send OTP'),
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

  Widget _buildOtpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAuthHeader(
              'Verify Your Email', 'Enter the 6-digit OTP sent to\n${_emailController.text}'),
          TextFormField(
            controller: _otpController,
            decoration: const InputDecoration(labelText: 'OTP'),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.bold),
            inputFormatters: [LengthLimitingTextInputFormatter(6)],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify & Proceed'),
            ),
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
      // First, send email OTP
      final otpSent = await AuthService.sendEmailOTP(_emailController.text.trim());

      if (otpSent) {
        setState(() {
          _isLoading = false;
          _authState = AuthState.otpVerification;
        });
      } else {
        setState(() => _isLoading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send OTP. Please try again.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed: ${e.toString()}')),
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
        // Persist login state
        await AuthStorageService.setLoggedIn(value: true, email: _emailController.text.trim());
        setState(() => _isLoading = false);
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LocationAccessScreen()),
                (Route<dynamic> route) => false,
          );
        }
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

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify email OTP
      final isOtpValid = await AuthService.verifyEmailOTP(_otpController.text.trim());

      if (isOtpValid) {
        // If OTP is valid, create user in Supabase
        final response = await AuthService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          age: int.parse(_ageController.text.trim()),
        );

        if (response.user != null) {
          // Persist login state after successful sign-up
          await AuthStorageService.setLoggedIn(value: true, email: _emailController.text.trim());
          setState(() => _isLoading = false);
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LocationAccessScreen()),
                  (Route<dynamic> route) => false,
            );
          }
        } else {
          setState(() => _isLoading = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create account. Please try again.')),
            );
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid OTP. Please try again.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verification failed: ${e.toString()}')),
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
              if (_authState == AuthState.otpVerification) {
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
      case AuthState.otpVerification:
        return _buildOtpView();
      case AuthState.initial:
        return _buildInitialView();
    }
  }
}