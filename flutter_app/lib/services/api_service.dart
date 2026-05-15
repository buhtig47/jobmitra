// lib/services/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // Defensive coercion — backend hiccups, partial responses, or future schema
  // changes should never crash the UI. Always return a usable empty value.
  static List _asList(dynamic v) => v is List ? v : const [];
  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Open the Hive cache box safely. If Hive failed to init at boot, return
  /// null so callers degrade to network-only mode instead of crashing.
  static dynamic _safeBox() {
    try { return Hive.box('jobs_cache'); }
    catch (_) { return null; }
  }

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
        if (i == retries) debugPrint('GET failed: $e');
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
      debugPrint('POST failed: $e');
      return null;
    }
  }

  Future<int?> registerUser(UserProfile profile) async {
    try {
      final res = await _post('$kApiBase/users/register', profile.toJson());
      if (res != null && res.statusCode == 200) {
        final data = _asMap(jsonDecode(res.body));
        final userId = data['user_id'];
        if (userId is! int) return null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_userIdKey, userId);
        await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
        return userId;
      }
    } catch (e) { debugPrint('Register error: $e'); }
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
      installId: json['install_id'] ?? prefs.getString('install_id'),
      state:     json['state']      ?? '',
      education: json['education']  ?? 'graduate',
      category:  json['category']   ?? 'general',
      age:       json['age']        ?? 25,
      jobTypes:  List<String>.from(json['job_types'] ?? []),
    );
  }

  /// Load cached feed instantly (no network) — for stale-while-revalidate.
  /// Pass [stateOverride] so the splash cache matches the state the user
  /// last viewed; otherwise the All-India cache flashes before the override
  /// reloads, producing a visible flicker.
  Future<List<Job>> getCachedFeed({String? stateOverride}) async {
    try {
      final box = _safeBox();
      if (box == null) return [];
      final key = (stateOverride == null || stateOverride.isEmpty)
          ? 'feed_jobs'
          : 'feed_jobs_${stateOverride.toLowerCase()}';
      final cached = box.get(key) as String?;
      if (cached == null) return [];
      final data = _asMap(jsonDecode(cached));
      return _asList(data['jobs']).map((j) => Job.fromJson(j)).toList();
    } catch (_) { return []; }
  }

  /// [stateOverride] — optional. Pass a state code (eg "up", "bihar") to override
  /// the user's profile state for this call, or "all_india" to drop state filter.
  Future<Map<String, dynamic>> getJobFeed({
    required int userId,
    int page = 1,
    String? stateOverride,
  }) async {
    final box = _safeBox();
    final params = StringBuffer('user_id=$userId&page=$page&page_size=20');
    if (stateOverride != null && stateOverride.isNotEmpty) {
      params.write('&state=${Uri.encodeQueryComponent(stateOverride)}');
    }
    // Cache key isolates per state so switching tabs doesn't clobber the default feed
    final cacheKey = (stateOverride == null || stateOverride.isEmpty)
        ? 'feed_jobs'
        : 'feed_jobs_${stateOverride.toLowerCase()}';
    final cacheTsKey = '${cacheKey}_ts';

    try {
      final res = await _get('$kApiBase/jobs/feed?$params');
      if (res != null) {
        final data = _asMap(jsonDecode(res.body));
        final jobs = _asList(data['jobs']).map((j) => Job.fromJson(j)).toList();
        if (page == 1 && box != null) {
          await box.put(cacheKey, res.body);
          await box.put(cacheTsKey, DateTime.now().toIso8601String());
        }
        return {
          'jobs': jobs,
          'total': data['total'] ?? jobs.length,
          'has_more': data['has_more'] ?? false,
          'is_cached': false,
        };
      }
    } catch (e) { debugPrint('Feed error: $e'); }

    if (box == null) {
      return {'jobs': <Job>[], 'total': 0, 'has_more': false, 'is_cached': false};
    }
    final cached = box.get(cacheKey) as String?;
    final timestamp = box.get(cacheTsKey) as String?;
    if (cached != null) {
      try {
        final data = _asMap(jsonDecode(cached));
        final jobs = _asList(data['jobs']).map((j) => Job.fromJson(j)).toList();
        return {
          'jobs': jobs,
          'total': jobs.length,
          'has_more': false,
          'is_cached': true,
          'cached_at': timestamp,
        };
      } catch (e) { debugPrint('Cache load error: $e'); }
    }
    return {'jobs': <Job>[], 'total': 0, 'has_more': false, 'is_cached': false};
  }

  Future<Job?> getJobDetail(int jobId, String category) async {
    try {
      final res = await _get('$kApiBase/jobs/$jobId?user_category=$category');
      if (res != null) return Job.fromJson(jsonDecode(res.body));
    } catch (e) { debugPrint('Job detail error: $e'); }
    return null;
  }

  Future<List<Job>> searchJobs(String query, {String userCategory = 'general'}) async {
    try {
      final url = '$kApiBase/jobs/search?q=${Uri.encodeComponent(query)}&user_category=$userCategory';
      final res = await _get(url);
      if (res != null) {
        final data = _asMap(jsonDecode(res.body));
        return _asList(data['jobs']).map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) { debugPrint('Search error: $e'); }
    return [];
  }

  /// Returns 'saved', 'applied', 'unsaved', or null
  Future<String?> getJobStatus(int userId, int jobId) async {
    try {
      final res = await _get('$kApiBase/users/$userId/job/$jobId/status');
      if (res != null) {
        final data = _asMap(jsonDecode(res.body));
        final s = data['status'];
        return s is String ? s : null;
      }
    } catch (e) { debugPrint('Job status error: $e'); }
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
    } catch (e) { debugPrint('Update profile error: $e'); }
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
        final data = _asMap(jsonDecode(res.body));
        return _asList(data['saved_jobs']).map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) { debugPrint('Saved jobs error: $e'); }
    return [];
  }

  Future<Map<String, dynamic>?> getStats() async {
    try {
      final res = await _get('$kApiBase/stats');
      if (res != null) return _asMap(jsonDecode(res.body));
    } catch (e) { debugPrint('Stats error: $e'); }
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
    // Fire-and-forget sync to backend so push fires at scrape-time, not just
    // when the app reopens. We swallow errors — the local copy stays the
    // source of truth and the next save will retry.
    final userId = prefs.getInt(_userIdKey);
    if (userId == null) return;
    try {
      await http
          .put(
            Uri.parse('$kApiBase/users/$userId/alert-rules'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(rules.map((r) => r.toJson()).toList()),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
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
      final data = _asMap(jsonDecode(res.body));
      final qs = _asList(data['questions']);
      if (qs.isEmpty) return null;
      return qs.whereType<Map>().map((q) => Map<String, dynamic>.from(q)).toList();
    } catch (_) { return null; }
  }

  /// Returns mock test pack list from the API.
  /// Returns null if the API returns no packs.
  Future<List<Map<String, dynamic>>?> getMockTestPacks() async {
    try {
      final res = await _get('$kApiBase/mock-tests');
      if (res == null) return null;
      final data = _asMap(jsonDecode(res.body));
      final packs = _asList(data['packs']);
      if (packs.isEmpty) return null;
      return packs.whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList();
    } catch (_) { return null; }
  }

  /// Returns questions for a specific mock test pack from the API.
  /// Returns null if the API returns no questions.
  Future<List<Map<String, dynamic>>?> getMockTestQuestions(String packId) async {
    try {
      final res = await _get('$kApiBase/mock-tests/${Uri.encodeComponent(packId)}');
      if (res == null) return null;
      final data = _asMap(jsonDecode(res.body));
      final qs = _asList(data['questions']);
      if (qs.isEmpty) return null;
      return qs.whereType<Map>().map((q) => Map<String, dynamic>.from(q)).toList();
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
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((j) => CurrentAffair.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Announcements (admit cards / results / answer keys / cut-offs) ────────
  Future<List<Announcement>> getAnnouncements({String? type, int limit = 50}) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (type != null && type.isNotEmpty) params['type'] = type;
      final uri = Uri.parse('$kApiBase/announcements').replace(queryParameters: params);
      final res = await _get(uri.toString());
      if (res == null) return [];
      final data = _asMap(jsonDecode(res.body));
      return _asList(data['announcements'])
          .whereType<Map>()
          .map((j) => Announcement.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, int>> getAnnouncementCounts() async {
    try {
      final res = await _get('$kApiBase/announcements/counts');
      if (res == null) return {};
      final data = _asMap(jsonDecode(res.body));
      final raw = _asMap(data['counts']);
      final out = <String, int>{};
      raw.forEach((k, v) {
        if (v is num) out[k] = v.toInt();
      });
      return out;
    } catch (_) {
      return {};
    }
  }
}
