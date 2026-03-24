// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Wake Render server FIRST — fire-and-forget so cold start begins immediately
  http.get(Uri.parse('$kApiBase/stats')).catchError((_) {});

  // 1. Offline cache
  await Hive.initFlutter();
  await Hive.openBox('jobs_cache');

  // 2. Firebase (needs to be before NotificationService which uses FirebaseMessaging)
  try {
    await Firebase.initializeApp();
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
  } catch (_) {}

  // 3. Local notifications + FCM foreground handler
  await NotificationService.init();

  // 4. AdMob
  await AdService.initialize();
  AdService().loadInterstitial();

  final prefs = await SharedPreferences.getInstance();
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
      theme: appTheme(),
      home: showHome
          ? HomeScreen(userId: userId!)
          : const OnboardingScreen(),
    );
  }
}
