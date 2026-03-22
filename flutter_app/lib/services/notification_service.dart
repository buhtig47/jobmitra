// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'deadline_channel',
      'Deadline Alerts',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

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

    const androidDetails = AndroidNotificationDetails(
      'deadline_channel',
      'Deadline Alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      42,
      '⏰ JobMitra - Deadline Alert!',
      body,
      notificationDetails,
    );

    // Mark as shown for today
    await prefs.setString('last_deadline_notif_date', today);
  }
}
