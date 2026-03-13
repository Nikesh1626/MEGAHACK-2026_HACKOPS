import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/dashboard/screens/dashboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: MegaHackApp()));
}

class MegaHackApp extends StatelessWidget {
  const MegaHackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mega Hack Detox',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const DashboardScreen(),
    );
  }
}
