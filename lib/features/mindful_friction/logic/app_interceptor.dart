// App Interceptor service for mindful friction feature.
// Detects distracting apps and returns an appropriate InterventionType.

/// The type of intervention to trigger when a distracting app is opened.
enum InterventionType { none, breathe, sentimentCheck }

/// A predictor function that can be swapped out for an on-device model later.
/// It receives the current DateTime, the package name being checked and the
/// baseline intervention decided from simple rules. It returns an (possibly
/// elevated) InterventionType.
typedef InterventionPredictor =
    Future<InterventionType> Function(
      DateTime now,
      String packageName,
      InterventionType baseline,
    );

/// Service that determines whether an app needs a mindful intervention.
///
/// Usage:
/// final svc = AppInterceptorService();
/// final intervention = await svc.checkIfAppNeedsIntervention('com.instagram.android');
class AppInterceptorService {
  /// Predefined set of distracting Android package names.
  /// Keep as a set for O(1) lookups and easy future modification.
  final Set<String> distractingPackages = {
    'com.instagram.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.snapchat.android',
    'com.facebook.katana',
    'com.twitter.android',
    'com.reddit.frontpage',
    'com.netflix.mediaclient',
    'com.youtube.android',
  };

  final InterventionPredictor _predictor;

  /// Create the service. You can inject a custom predictor (e.g. on-device TFLite
  /// model) to replace the default mock predictor.
  AppInterceptorService({InterventionPredictor? predictor})
    : _predictor = predictor ?? _defaultPredictor;

  /// Checks if the given [packageName] requires an intervention.
  /// Returns an [InterventionType]. This method is asynchronous to allow
  /// predictors that perform I/O or model inference.
  Future<InterventionType> checkIfAppNeedsIntervention(
    String packageName,
  ) async {
    final normalized = packageName.trim().toLowerCase();

    // Baseline rule: if app is in the distracting list -> breathe, else none.
    final baseline = distractingPackages.contains(normalized)
        ? InterventionType.breathe
        : InterventionType.none;

    // Allow predictor to elevate or override the baseline.
    final now = DateTime.now();
    final predicted = await _predictor(now, normalized, baseline);
    return predicted;
  }

  /// Default mock predictor. Current behavior:
  /// - If baseline is none, returns none.
  /// - If baseline is breathe and current time is between 10 PM and 2 AM,
  ///   elevates to sentimentCheck (higher priority intervention).
  /// - Otherwise returns baseline.
  static Future<InterventionType> _defaultPredictor(
    DateTime now,
    String packageName,
    InterventionType baseline,
  ) async {
    if (baseline == InterventionType.none) return InterventionType.none;

    final hour = now.hour; // 0-23

    // Time window: 22:00 (10 PM) - 01:59 (2 AM exclusive of 2:00 exactly is fine to include)
    // We treat hours >=22 OR <2 as the vulnerable window.
    final isVulnerableWindow = (hour >= 22) || (hour < 2);

    if (isVulnerableWindow) {
      return InterventionType.sentimentCheck;
    }

    return baseline;
  }

  /// Utility: allow runtime inspection of whether a package is considered distracting.
  bool isDistractingPackage(String packageName) =>
      distractingPackages.contains(packageName.trim().toLowerCase());
}
