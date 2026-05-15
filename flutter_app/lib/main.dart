// lib/main.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<String> _ensureInstallId(SharedPreferences prefs) async {
  var id = prefs.getString('install_id');
  if (id != null && id.isNotEmpty) return id;
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await prefs.setString('install_id', id);
  return id;
}

void main() async {
  // Wrap entry in a Zone so async errors hit Crashlytics too.
  await runZonedGuarded<Future<void>>(_bootstrap, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Warm Cloud Run backend — fire-and-forget so cold start begins immediately
  http.get(Uri.parse('$kApiBase/stats')).then((_) {}, onError: (_) {});

  // 1. Offline cache
  await Hive.initFlutter();
  await Hive.openBox('jobs_cache');

  // 2. Firebase (needs to be before NotificationService which uses FirebaseMessaging)
  try {
    await Firebase.initializeApp();

    // Crashlytics: only collect in release builds. Debug crashes stay local.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    final fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
    if (fcmToken.isNotEmpty) {
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.setString('fcm_token', fcmToken);
    }
    // Refresh token when it changes
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.setString('fcm_token', token);
    });

    // Topic subscription — backend pushes announcement digest here.
    // Plus per-org topics so users get granular alerts (e.g. only SSC).
    try {
      final fm = FirebaseMessaging.instance;
      await fm.subscribeToTopic('jobmitra_announcements');
      // Whitelist mirrors backend ANNOUNCEMENT_ORG_TOPICS — keep in sync.
      const orgs = [
        'ssc', 'upsc', 'rrb', 'ibps', 'sbi', 'rbi', 'nabard',
        'aiims', 'drdo', 'isro', 'ntpc', 'bhel', 'ongc',
        'upsssc', 'uppsc', 'bpsc', 'mppsc', 'rpsc', 'tnpsc', 'kpsc',
        'kvs', 'nvs', 'ctet', 'reet',
        'neet', 'jee', 'cuet', 'gate',
        'fci', 'lic', 'sebi', 'bsnl', 'npcil', 'csir', 'icmr',
        'bsf', 'crpf', 'capf', 'cds', 'nda', 'afcat',
      ];
      for (final o in orgs) {
        try { await fm.subscribeToTopic('announcements_org_$o'); } catch (_) {}
      }
    } catch (_) {}
  } catch (_) {}

  // 3. Local notifications + FCM foreground handler
  await NotificationService.init();

  // 4. AdMob
  await AdService.initialize();
  AdService().loadInterstitial();

  final prefs = await SharedPreferences.getInstance();
  await _ensureInstallId(prefs);  // stable identity across reinstalls/token rotations
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final userId = prefs.getInt('user_id');

  runApp(JobMitraApp(
    showHome: onboardingDone && userId != null,
    userId: userId,
  ));
}

class JobMitraApp extends StatelessWidget {
  final bool showHome;
  final int? userId;

  const JobMitraApp({super.key, required this.showHome, this.userId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobMitra',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: appTheme(),
      home: showHome
          ? HomeScreen(userId: userId!)
          : const OnboardingScreen(),
    );
  }
}
