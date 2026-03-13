import 'package:flutter/material.dart';
import 'features/LocationAccessScreen/location_access_screen.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/geofencing_service.dart';
import 'core/services/auth_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Render UI first; run async bootstrapping from within the app.
  runApp(const MyApp());
}

Future<bool> _bootstrapApp() async {
  var supabaseReady = false;

  try {
    await Supabase.initialize(
      url: 'https://wzgcwhrgaqczcdagxblm.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6Z2N3aHJnYXFjemNkYWd4YmxtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5NDgxMDksImV4cCI6MjA3NDUyNDEwOX0.W0fxJKifTEknhp4aWWAf0HQTH2nnfBpn__8Gf8Tf-xY',
    ).timeout(const Duration(seconds: 15));
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  final geofencingService = GeofencingService();
  try {
    await geofencingService
        .initializeNotifications()
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Notification initialization failed: $e');
  }

  try {
    await geofencingService
        .resumeGeofenceMonitoring()
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Geofence restore failed: $e');
  }

  final persistedLogin = await AuthStorageService.isLoggedIn();
  final hasSession =
      supabaseReady && Supabase.instance.client.auth.currentSession != null;
  return persistedLogin && hasSession;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<bool> _startLoggedInFuture;

  @override
  void initState() {
    super.initState();
    _startLoggedInFuture = _bootstrapApp();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Well Queue',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Colors.black54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _startLoggedInFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StartupScreen();
          }

          return snapshot.data == true
              ? const LocationAccessScreen()
              : const AuthScreen();
        },
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}