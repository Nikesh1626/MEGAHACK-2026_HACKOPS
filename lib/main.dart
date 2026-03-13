import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/geofencing_service.dart';
import 'core/services/auth_storage_service.dart';
import 'core/services/auth_service.dart';
import 'features/LocationAccessScreen/location_access_screen.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize geofencing service and notifications
  final geofencingService = GeofencingService();
  await geofencingService.initializeNotifications();
  
  // Resume geofencing if it was active before app restart
  await geofencingService.resumeGeofenceMonitoring();
  
  // Determine initial route based on persisted login and current session
  final persistedLogin = await AuthStorageService.isLoggedIn();
  final hasSession = AuthService.isAuthenticated();
  var isEmailVerified = false;

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await currentUser.reload();
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  }

  runApp(MyApp(
    startLoggedIn: persistedLogin && hasSession && isEmailVerified,
  ));
}

class MyApp extends StatelessWidget {
  final bool startLoggedIn;
  const MyApp({super.key, this.startLoggedIn = false});
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
      home: startLoggedIn ? const LocationAccessScreen() : const AuthScreen(),
    );
  }
}
