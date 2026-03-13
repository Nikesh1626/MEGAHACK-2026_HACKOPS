import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_usage_info.dart';

final appUsageProvider =
    StateNotifierProvider<AppUsageNotifier, AsyncValue<List<AppUsageInfo>>>(
  (ref) => AppUsageNotifier(),
);

class AppUsageNotifier extends StateNotifier<AsyncValue<List<AppUsageInfo>>> {
  AppUsageNotifier() : super(const AsyncValue.loading()) {
    loadUsage();
  }

  Future<void> loadUsage() async {
    state = const AsyncValue.loading();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      state = const AsyncValue.data(_dummyUsage);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

const List<AppUsageInfo> _dummyUsage = [
  AppUsageInfo(appName: 'YouTube', durationMinutes: 110),
  AppUsageInfo(appName: 'Instagram', durationMinutes: 84),
  AppUsageInfo(appName: 'WhatsApp', durationMinutes: 68),
  AppUsageInfo(appName: 'Chrome', durationMinutes: 57),
  AppUsageInfo(appName: 'Spotify', durationMinutes: 49),
  AppUsageInfo(appName: 'X', durationMinutes: 32),
  AppUsageInfo(appName: 'Reddit', durationMinutes: 25),
];
