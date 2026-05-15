// lib/screens/notification_prefs_screen.dart
//
// Per-organisation push notification preferences. All orgs default to ON
// (auto-subscribed in main.dart). Toggling off unsubscribes from that
// FCM topic and persists the choice in SharedPreferences.
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  // Mirrors backend ANNOUNCEMENT_ORG_TOPICS + general digest.
  // Grouped for UX clarity.
  static const Map<String, List<(String, String)>> _groups = {
    'Central exams': [
      ('ssc', 'SSC — Staff Selection Commission'),
      ('upsc', 'UPSC — Civil Services & more'),
      ('rrb', 'RRB — Railway'),
      ('ibps', 'IBPS — Bank PO/Clerk'),
      ('sbi', 'SBI'),
      ('rbi', 'RBI'),
      ('nabard', 'NABARD'),
    ],
    'State PSCs': [
      ('upsssc', 'UPSSSC (UP)'),
      ('uppsc',  'UPPSC (UP)'),
      ('bpsc',   'BPSC (Bihar)'),
      ('mppsc',  'MPPSC (MP)'),
      ('rpsc',   'RPSC (Rajasthan)'),
      ('tnpsc',  'TNPSC (Tamil Nadu)'),
      ('kpsc',   'KPSC (Karnataka)'),
    ],
    'PSU / Research': [
      ('drdo',  'DRDO'),
      ('isro',  'ISRO'),
      ('ntpc',  'NTPC'),
      ('bhel',  'BHEL'),
      ('ongc',  'ONGC'),
      ('fci',   'FCI'),
      ('lic',   'LIC'),
      ('sebi',  'SEBI'),
      ('bsnl',  'BSNL'),
      ('npcil', 'NPCIL'),
      ('csir',  'CSIR'),
      ('icmr',  'ICMR'),
    ],
    'Defence': [
      ('bsf',   'BSF'),
      ('crpf',  'CRPF'),
      ('capf',  'CAPF'),
      ('cds',   'CDS'),
      ('nda',   'NDA'),
      ('afcat', 'AFCAT'),
    ],
    'Teaching / Entrance': [
      ('kvs',   'KVS'),
      ('nvs',   'NVS'),
      ('ctet',  'CTET'),
      ('reet',  'REET'),
      ('neet',  'NEET'),
      ('jee',   'JEE'),
      ('cuet',  'CUET'),
      ('gate',  'GATE'),
    ],
    'Medical': [
      ('aiims', 'AIIMS'),
    ],
  };

  final Map<String, bool> _enabled = {};
  bool _generalEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _generalEnabled = prefs.getBool('notif_general') ?? true;
    for (final group in _groups.values) {
      for (final (code, _) in group) {
        _enabled[code] = prefs.getBool('notif_org_$code') ?? true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleOrg(String code, bool value) async {
    setState(() => _enabled[code] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_org_$code', value);
    final fm = FirebaseMessaging.instance;
    try {
      if (value) {
        await fm.subscribeToTopic('announcements_org_$code');
      } else {
        await fm.unsubscribeFromTopic('announcements_org_$code');
      }
    } catch (_) {}
  }

  Future<void> _toggleGeneral(bool value) async {
    setState(() => _generalEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_general', value);
    final fm = FirebaseMessaging.instance;
    try {
      if (value) {
        await fm.subscribeToTopic('jobmitra_announcements');
      } else {
        await fm.unsubscribeFromTopic('jobmitra_announcements');
      }
    } catch (_) {}
  }

  Future<void> _bulkSet(bool value) async {
    setState(() {
      for (final k in _enabled.keys) {
        _enabled[k] = value;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    final fm = FirebaseMessaging.instance;
    for (final group in _groups.values) {
      for (final (code, _) in group) {
        await prefs.setBool('notif_org_$code', value);
        try {
          if (value) {
            await fm.subscribeToTopic('announcements_org_$code');
          } else {
            await fm.unsubscribeFromTopic('announcements_org_$code');
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => _bulkSet(true),
            child: const Text('All on', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => _bulkSet(false),
            child: const Text('All off', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              children: [
                _buildIntro(),
                _buildGeneralTile(),
                const Divider(height: 1),
                for (final entry in _groups.entries) ...[
                  _buildGroupHeader(entry.key),
                  for (final (code, label) in entry.value)
                    _buildOrgTile(code, label),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildIntro() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Jis exam ki update chahiye, sirf wahi on rakho. Off karne par push notification band ho jayegi.',
              style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.78),
                  fontSize: 12.5,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTile() {
    return SwitchListTile(
      title: const Text('General digest',
          style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: const Text(
          'Daily roll-up — all new admit cards / results / answer keys'),
      value: _generalEnabled,
      activeColor: AppColors.primary,
      onChanged: _toggleGeneral,
    );
  }

  Widget _buildGroupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildOrgTile(String code, String label) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: _enabled[code] ?? true,
      activeColor: AppColors.primary,
      dense: true,
      onChanged: (v) => _toggleOrg(code, v),
    );
  }
}
