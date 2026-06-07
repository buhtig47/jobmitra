// lib/main.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';
import 'utils/i18n.dart';

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

  // 1. Offline cache. Hive init can fail on a corrupted file (rare, but a
  // single bad write during an OOM kill can leave the box unreadable). Swallow
  // and continue — api_service's _safeBox() falls back to network-only mode.
  // Crashlytics isn't initialised yet at this point, so we just print.
  try {
    await Hive.initFlutter();
    await Hive.openBox('jobs_cache');
  } catch (e) {
    debugPrint('Hive init failed, running network-only: $e');
  }

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
    //
    // Bump kTopicSyncVersion whenever the org whitelist changes so existing
    // installs re-sync once. Without this gate, each cold start would issue
    // 41 FCM HTTP calls (general + 40 orgs) and block startup on slow nets.
    try {
      final fm = FirebaseMessaging.instance;
      const kTopicSyncVersion = 1;
      const orgs = [
        'ssc', 'upsc', 'rrb', 'ibps', 'sbi', 'rbi', 'nabard',
        'aiims', 'drdo', 'isro', 'ntpc', 'bhel', 'ongc',
        'upsssc', 'uppsc', 'bpsc', 'mppsc', 'rpsc', 'tnpsc', 'kpsc',
        'kvs', 'nvs', 'ctet', 'reet',
        'neet', 'jee', 'cuet', 'gate',
        'fci', 'lic', 'sebi', 'bsnl', 'npcil', 'csir', 'icmr',
        'bsf', 'crpf', 'capf', 'cds', 'nda', 'afcat',
      ];
      final prefs = await SharedPreferences.getInstance();
      final lastSynced = prefs.getInt('topic_sync_version') ?? 0;
      if (lastSynced < kTopicSyncVersion) {
        await fm.subscribeToTopic('jobmitra_announcements');
        for (final o in orgs) {
          final enabled = prefs.getBool('notif_org_$o') ?? true;
          try {
            if (enabled) {
              await fm.subscribeToTopic('announcements_org_$o');
            } else {
              await fm.unsubscribeFromTopic('announcements_org_$o');
            }
          } catch (_) {}
        }
        final generalOn = prefs.getBool('notif_general') ?? true;
        if (!generalOn) {
          try { await fm.unsubscribeFromTopic('jobmitra_announcements'); } catch (_) {}
        }
        await prefs.setInt('topic_sync_version', kTopicSyncVersion);
      }
    } catch (e, st) {
      if (!kDebugMode) FirebaseCrashlytics.instance.recordError(e, st);
    }
  } catch (e, st) {
    if (!kDebugMode) FirebaseCrashlytics.instance.recordError(e, st);
  }

  // 3. Local notifications + FCM foreground handler
  await NotificationService.init();

  // 4. AdMob
  await AdService.initialize();
  AdService().loadInterstitial();
  AdService().loadAppOpen();
  AdService().loadRewarded();

  final prefs = await SharedPreferences.getInstance();
  await _ensureInstallId(prefs);  // stable identity across reinstalls/token rotations
  await L10n.loadFromPrefs();     // pick language from prefs once at boot
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
