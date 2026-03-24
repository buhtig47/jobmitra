// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';
import '../main.dart' show navigatorKey;

// Top-level handler — must be outside the class (FCM requirement)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by the OS on Android.
  // No action needed here unless you want custom handling.
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const _deadlineChannelId   = 'deadline_channel';
  static const _newJobsChannelId    = 'new_jobs_channel';

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _deadlineChannelId,
      'Deadline Alerts',
      description: 'Saved job deadline reminders',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _newJobsChannelId,
      'New Jobs',
      description: 'Alerts for newly scraped government jobs',
      importance: Importance.high,
    ));

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Foreground FCM → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final n = msg.notification;
      if (n == null) return;
      _showLocalNotification(
        id: msg.hashCode,
        title: n.title ?? 'JobMitra',
        body: n.body ?? '',
        channelId: _newJobsChannelId,
        channelName: 'New Jobs',
        payload: msg.data['screen'] ?? 'home',
      );
    });

    // Handle notification tap when app opened from background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  static void _onNotificationTap(NotificationResponse response) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  static Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  // ── Deadline Alerts (called when saved jobs load) ────────
  static Future<void> checkDeadlines(List<Job> savedJobs) async {
    // Only show once per day — prevent spam on every tab switch
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastShown = prefs.getString('last_deadline_notif_date') ?? '';
    if (lastShown == today) return;

    final urgent = savedJobs
        .where((j) => j.daysLeft >= 0 && j.daysLeft <= 3)
        .toList();
    if (urgent.isEmpty) return;

    final String body;
    if (urgent.length == 1) {
      final job = urgent.first;
      final dayText = job.daysLeft == 0 ? 'aaj' : '${job.daysLeft} din mein';
      body = '${job.cleanTitle} ki last date $dayText hai!';
    } else {
      body = '${urgent.length} saved jobs ki last date karib aa gayi!';
    }

    await _showLocalNotification(
      id: 42,
      title: '⏰ JobMitra - Deadline Alert!',
      body: body,
      channelId: _deadlineChannelId,
      channelName: 'Deadline Alerts',
      payload: 'saved',
    );

    await prefs.setString('last_deadline_notif_date', today);
  }
}
