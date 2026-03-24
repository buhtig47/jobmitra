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

  // Initialize Hive offline cache
  await Hive.initFlutter();
  await Hive.openBox('jobs_cache');

  // Initialize local notifications
  await NotificationService.init();

  // Initialize AdMob
  await AdService.initialize();
  AdService().loadInterstitial(); // preload first interstitial

  // Initialize Firebase (requires google-services.json — skip gracefully if missing)
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
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();

  // Wake up Render server (fire-and-forget — prevents 50s cold start delay)
  http.get(Uri.parse('$kApiBase/stats')).catchError((_) {});

  // Check if onboarding done
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
