// lib/services/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';
import '../utils/constants.dart';

class ApiService {
  static const _userIdKey     = 'user_id';
  static const _profileKey    = 'user_profile';
  static const _recentKey     = 'recently_viewed_jobs';
  static const _longTimeout   = Duration(seconds: 60);

  Future<void> wakeUpServer() async {
    try {
      await http.get(Uri.parse('$kApiBase/stats')).timeout(_longTimeout);
    } catch (_) {}
  }

  Future<http.Response?> _get(String url, {int retries = 2}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(_longTimeout);
        if (res.statusCode == 200) return res;
      } catch (e) {
        if (i == retries) print('GET failed: $e');
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<http.Response?> _post(String url, Map body) async {
    try {
      return await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_longTimeout);
    } catch (e) {
      print('POST failed: $e');
      return null;
    }
  }

  Future<int?> registerUser(UserProfile profile) async {
    try {
      final res = await _post('$kApiBase/users/register', profile.toJson());
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final userId = data['user_id'] as int;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_userIdKey, userId);
        await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
        return userId;
      }
    } catch (e) { print('Register error: $e'); }
    return null;
  }

  Future<int?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  Future<UserProfile?> getSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_profileKey);
    if (str == null) return null;
    final json = jsonDecode(str);
    return UserProfile(
      fcmToken:  json['fcm_token']  ?? '',
      state:     json['state']      ?? '',
      education: json['education']  ?? 'graduate',
      category:  json['category']   ?? 'general',
      age:       json['age']        ?? 25,
      jobTypes:  List<String>.from(json['job_types'] ?? []),
    );
  }

  /// Load cached feed instantly (no network) — for stale-while-revalidate
  Future<List<Job>> getCachedFeed() async {
    try {
      final box = Hive.box('jobs_cache');
      final cached = box.get('feed_jobs') as String?;
      if (cached == null) return [];
      final data = jsonDecode(cached);
      return (data['jobs'] as List).map((j) => Job.fromJson(j)).toList();
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> getJobFeed({required int userId, int page = 1}) async {
    final box = Hive.box('jobs_cache');
    try {
      final res = await _get('$kApiBase/jobs/feed?user_id=$userId&page=$page&page_size=20');
      if (res != null) {
        final data = jsonDecode(res.body);
        final jobs = (data['jobs'] as List).map((j) => Job.fromJson(j)).toList();
        // Cache first page for offline fallback
        if (page == 1) {
          await box.put('feed_jobs', res.body);
          await box.put('feed_timestamp', DateTime.now().toIso8601String());
        }
        return {
          'jobs': jobs,
          'total': data['total'] ?? jobs.length,
          'has_more': data['has_more'] ?? false,
          'is_cached': false,
        };
      }
    } catch (e) { print('Feed error: $e'); }

    // Network failed — load from Hive cache
    final cached = box.get('feed_jobs') as String?;
    final timestamp = box.get('feed_timestamp') as String?;
    if (cached != null) {
      try {
        final data = jsonDecode(cached);
        final jobs = (data['jobs'] as List).map((j) => Job.fromJson(j)).toList();
        return {
          'jobs': jobs,
          'total': jobs.length,
          'has_more': false,
          'is_cached': true,
          'cached_at': timestamp,
        };
      } catch (e) { print('Cache load error: $e'); }
    }
    return {'jobs': <Job>[], 'total': 0, 'has_more': false, 'is_cached': false};
  }

  Future<Job?> getJobDetail(int jobId, String category) async {
    try {
      final res = await _get('$kApiBase/jobs/$jobId?user_category=$category');
      if (res != null) return Job.fromJson(jsonDecode(res.body));
    } catch (e) { print('Job detail error: $e'); }
    return null;
  }

  Future<List<Job>> searchJobs(String query, {String userCategory = 'general'}) async {
    try {
      final url = '$kApiBase/jobs/search?q=${Uri.encodeComponent(query)}&user_category=$userCategory';
      final res = await _get(url);
      if (res != null) {
        final data = jsonDecode(res.body);
        return (data['jobs'] as List).map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) { print('Search error: $e'); }
    return [];
  }

  /// Returns 'saved', 'applied', 'unsaved', or null
  Future<String?> getJobStatus(int userId, int jobId) async {
    try {
      final res = await _get('$kApiBase/users/$userId/job/$jobId/status');
      if (res != null) return jsonDecode(res.body)['status'] as String?;
    } catch (e) { print('Job status error: $e'); }
    return null;
  }

  Future<bool> updateProfile(int userId, UserProfile profile) async {
    try {
      final res = await http.put(
        Uri.parse('$kApiBase/users/$userId/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile.toJson()),
      ).timeout(_longTimeout);
      if (res.statusCode == 200) {
        // Keep local cache in sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', jsonEncode(profile.toJson()));
        return true;
      }
    } catch (e) { print('Update profile error: $e'); }
    return false;
  }

  /// Sync the latest FCM token to the backend if it changed
  Future<void> syncFcmToken(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token') ?? '';
      if (token.isEmpty || token == 'test') return;
      final profile = await getSavedProfile();
      if (profile == null || profile.fcmToken == token) return;
      final updated = profile.copyWith(fcmToken: token);
      await updateProfile(userId, updated);
      await prefs.setString(_profileKey, jsonEncode(updated.toJson()));
    } catch (_) {}
  }

  Future<bool> saveJob(int userId, int jobId, String status) async {
    try {
      final res = await _post('$kApiBase/jobs/save', {'user_id': userId, 'job_id': jobId, 'status': status});
      return res != null && res.statusCode == 200;
    } catch (e) { return false; }
  }

  Future<List<Job>> getSavedJobs(int userId) async {
    try {
      final res = await _get('$kApiBase/users/$userId/saved');
      if (res != null) {
        final data = jsonDecode(res.body);
        return (data['saved_jobs'] as List).map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) { print('Saved jobs error: $e'); }
    return [];
  }

  Future<Map<String, dynamic>?> getStats() async {
    try {
      final res = await _get('$kApiBase/stats');
      if (res != null) return jsonDecode(res.body);
    } catch (e) { print('Stats error: $e'); }
    return null;
  }

  // ── Recently Viewed ─────────────────────────────────────
  Future<void> addRecentlyViewed(Job job) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentKey) ?? [];
      // Remove existing entry for same job
      raw.removeWhere((s) {
        try { return jsonDecode(s)['id'] == job.id; } catch (_) { return false; }
      });
      raw.insert(0, jsonEncode(job.toJson()));
      if (raw.length > 10) raw.removeLast();
      await prefs.setStringList(_recentKey, raw);
    } catch (_) {}
  }

  Future<List<Job>> getRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentKey) ?? [];
      return raw
          .map((s) { try { return Job.fromJson(jsonDecode(s)); } catch (_) { return null; } })
          .whereType<Job>()
          .toList();
    } catch (_) { return []; }
  }

  // ── Application Stage Tracker ──────────────────────────────
  static const _trackerKey = 'app_stage_tracker_v1';

  // Returns Map<jobId, Map<field, value>>
  // Fields: stage, reg_no, exam_date, note
  Future<Map<int, Map<String, String>>> getAllTrackers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_trackerKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) =>
          MapEntry(int.parse(k), Map<String, String>.from(v as Map)));
    } catch (_) { return {}; }
  }

  Future<Map<String, String>?> getTracker(int jobId) async {
    final all = await getAllTrackers();
    return all[jobId];
  }

  Future<void> updateTracker(int jobId, Map<String, String> data) async {
    final all = await getAllTrackers();
    all[jobId] = {...(all[jobId] ?? {}), ...data};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _trackerKey,
        jsonEncode(all.map((k, v) => MapEntry(k.toString(), v))));
  }

  // ── Personal Info (stored locally only, never sent to server) ──
  static const _personalInfoKey = 'personal_info_v1';

  Future<PersonalInfo> getPersonalInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_personalInfoKey);
      if (raw == null) return const PersonalInfo();
      return PersonalInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) { return const PersonalInfo(); }
  }

  Future<void> savePersonalInfo(PersonalInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_personalInfoKey, jsonEncode(info.toJson()));
  }

  // ── Alert Rules (stored locally only) ──────────────────────
  static const _alertsKey   = 'alert_rules_v1';
  static const _alertSeenKey = 'alert_seen_ids_v1';

  Future<List<AlertRule>> getAlertRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_alertsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((j) => AlertRule.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<void> saveAlertRules(List<AlertRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertsKey, jsonEncode(rules.map((r) => r.toJson()).toList()));
  }

  Future<Set<int>> getSeenJobIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_alertSeenKey) ?? [];
      return raw.map((s) => int.tryParse(s) ?? -1).where((i) => i >= 0).toSet();
    } catch (_) { return {}; }
  }

  Future<void> markJobsSeen(Set<int> ids) async {
    try {
      final existing = await getSeenJobIds();
      final merged = {...existing, ...ids};
      // Keep only last 2000 to prevent unbounded growth
      final trimmed = merged.toList();
      if (trimmed.length > 2000) trimmed.removeRange(0, trimmed.length - 2000);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_alertSeenKey, trimmed.map((i) => i.toString()).toList());
    } catch (_) {}
  }

  // ── Quiz / Mock Test ─────────────────────────────────────────

  /// Returns questions for a daily quiz set from the API.
  /// Returns null if the API has no questions for that set.
  Future<List<Map<String, dynamic>>?> getDailyQuizQuestions(int setIndex) async {
    try {
      final res = await _get('$kApiBase/daily-quiz?set_index=$setIndex');
      if (res == null) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final qs = data['questions'] as List?;
      if (qs == null || qs.isEmpty) return null;
      return qs.map((q) => q as Map<String, dynamic>).toList();
    } catch (_) { return null; }
  }

  /// Returns mock test pack list from the API.
  /// Returns null if the API returns no packs.
  Future<List<Map<String, dynamic>>?> getMockTestPacks() async {
    try {
      final res = await _get('$kApiBase/mock-tests');
      if (res == null) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final packs = data['packs'] as List?;
      if (packs == null || packs.isEmpty) return null;
      return packs.map((p) => p as Map<String, dynamic>).toList();
    } catch (_) { return null; }
  }

  /// Returns questions for a specific mock test pack from the API.
  /// Returns null if the API returns no questions.
  Future<List<Map<String, dynamic>>?> getMockTestQuestions(String packId) async {
    try {
      final res = await _get('$kApiBase/mock-tests/${Uri.encodeComponent(packId)}');
      if (res == null) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final qs = data['questions'] as List?;
      if (qs == null || qs.isEmpty) return null;
      return qs.map((q) => q as Map<String, dynamic>).toList();
    } catch (_) { return null; }
  }

  // ── Current Affairs ──────────────────────────────────────────
  Future<List<CurrentAffair>> getCurrentAffairs({String? category, int days = 7}) async {
    try {
      final params = <String, String>{'days': days.toString()};
      if (category != null && category != 'all') params['category'] = category;
      final uri = Uri.parse('$kApiBase/current-affairs').replace(queryParameters: params);
      final res = await _get(uri.toString());
      if (res == null) return [];
      final data = jsonDecode(res.body) as List;
      return data.map((j) => CurrentAffair.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
