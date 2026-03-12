// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';
import '../utils/constants.dart';

class ApiService {
  static const _userIdKey    = 'user_id';
  static const _profileKey   = 'user_profile';

  // ─────────────────────────────────────────
  // USER
  // ─────────────────────────────────────────
  Future<int?> registerUser(UserProfile profile) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile.toJson()),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final userId = data['user_id'] as int;

        // Save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_userIdKey, userId);
        await prefs.setString(_profileKey, jsonEncode(profile.toJson()));

        return userId;
      }
    } catch (e) {
      print('Register error: $e');
    }
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

  // ─────────────────────────────────────────
  // JOBS FEED
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> getJobFeed({
    required int userId,
    int page = 1,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/jobs/feed?user_id=$userId&page=$page&page_size=20'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final jobs = (data['jobs'] as List)
            .map((j) => Job.fromJson(j))
            .toList();
        return {
          'jobs':     jobs,
          'total':    data['total'],
          'has_more': data['has_more'],
        };
      }
    } catch (e) {
      print('Feed error: $e');
    }
    return {'jobs': <Job>[], 'total': 0, 'has_more': false};
  }

  // ─────────────────────────────────────────
  // JOB DETAIL
  // ─────────────────────────────────────────
  Future<Job?> getJobDetail(int jobId, String category) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/jobs/$jobId?user_category=$category'),
      );
      if (res.statusCode == 200) {
        return Job.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      print('Job detail error: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────
  Future<List<Job>> searchJobs(String query) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/jobs/search?q=${Uri.encodeComponent(query)}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['jobs'] as List).map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) {
      print('Search error: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────
  // SAVE JOB
  // ─────────────────────────────────────────
  Future<bool> saveJob(int userId, int jobId, String status) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/jobs/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'job_id': jobId, 'status': status}),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('Save job error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────
  // SAVED JOBS
  // ─────────────────────────────────────────
  Future<List<Job>> getSavedJobs(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/users/$userId/saved'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['saved_jobs'] as List).map((j) => Job.fromJson(j)).toList();
      }
    } catch (e) {
      print('Saved jobs error: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final res = await http.get(Uri.parse('$kApiBase/stats'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) { print('Stats error: $e'); }
    return null;
  }
}
