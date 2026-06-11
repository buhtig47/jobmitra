// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/i18n.dart';
import '../widgets/job_card.dart';
import '../widgets/banner_ad_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'job_detail_screen.dart';
import 'search_screen.dart';
import 'saved_jobs_screen.dart';
import 'profile_edit_screen.dart';
import 'notification_prefs_screen.dart';
import 'language_picker_screen.dart';
import 'personal_info_screen.dart';
import 'tools_screen.dart';
import 'alerts_screen.dart';
import 'announcements_screen.dart';
import 'disclaimer_screen.dart';
import '../services/notification_service.dart';
import '../services/ad_service.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTab = 0;
  int _savedRefreshKey = 0;
  int _savedCount = 0;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedCount();
    Future.delayed(const Duration(seconds: 3), _maybeShowRateUs);
  }

  void _loadSavedCount() {
    _api.getSavedJobs(widget.userId).then((jobs) {
      if (mounted) setState(() => _savedCount = jobs.length);
    });
  }

  Future<void> _maybeShowRateUs() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('has_rated') ?? false) return;
    final openCount = prefs.getInt('app_open_count') ?? 0;
    if (openCount < 5) return;
    final firstOpen = prefs.getString('first_open_date');
    if (firstOpen == null) return;
    final daysSinceInstall =
        DateTime.now().difference(DateTime.parse(firstOpen)).inDays;
    if (daysSinceInstall < 3) return;
    final snoozeUntil = prefs.getString('rate_us_snooze_until');
    if (snoozeUntil != null &&
        DateTime.now().isBefore(DateTime.parse(snoozeUntil))) {
      return;
    }
    if (!mounted) return;
    _showRateUsDialog();
  }

  void _showRateUsDialog() {
    int stars = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('JobMitra kaisa laga? ⭐',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ek minute mein apna review do —\nismein bahut mehnat lagi hai!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setSt(() => stars = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        stars > i ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFFF9933),
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                final snooze = DateTime.now()
                    .add(const Duration(days: 7))
                    .toIso8601String()
                    .substring(0, 10);
                await prefs.setString('rate_us_snooze_until', snooze);
              },
              child: const Text('Baad Mein', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: stars == 0
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('has_rated', true);
                      if (stars >= 4) {
                        final uri = Uri.parse(
                            'https://play.google.com/store/apps/details?id=com.jobmitra.app');
                        try {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdService().showAppOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _FeedTab(userId: widget.userId, api: _api),
          SearchScreen(api: _api),
          SavedJobsScreen(
            key: ValueKey(_savedRefreshKey),
            userId: widget.userId,
            api: _api,
            onBrowseJobs: () => setState(() => _selectedTab = 0),
          ),
          ToolsScreen(api: _api),
          _ProfileTab(userId: widget.userId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) {
          if (i == 2 && _selectedTab != 2) {
            _savedRefreshKey++;
            _loadSavedCount();
          }
          setState(() => _selectedTab = i);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.work_outline),
            selectedIcon: const Icon(Icons.work, color: AppColors.primary),
            label: L10n.tr('nav_jobs'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            selectedIcon: const Icon(Icons.search, color: AppColors.primary),
            label: L10n.tr('nav_search'),
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$_savedCount'),
              backgroundColor: const Color(0xFFFF9933),
              isLabelVisible: _savedCount > 0,
              child: const Icon(Icons.bookmark_outline),
            ),
            selectedIcon: Badge(
              label: Text('$_savedCount'),
              backgroundColor: const Color(0xFFFF9933),
              isLabelVisible: _savedCount > 0,
              child: const Icon(Icons.bookmark, color: AppColors.primary),
            ),
            label: L10n.tr('nav_saved'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.handyman_outlined),
            selectedIcon: const Icon(Icons.handyman, color: AppColors.primary),
            label: L10n.tr('nav_tools'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppColors.primary),
            label: L10n.tr('nav_profile'),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────
// JOB DEDUPLICATION  (NLP — Jaccard title similarity)
// ─────────────────────────────────────────

const _kStopWords = {
  'recruitment', 'notification', 'vacancy', 'vacancies', 'post', 'posts',
  'job', 'jobs', 'exam', 'examination', 'apply', 'online', 'application',
  'form', 'direct', 'advt', 'advertisement', 'adv', 'sarkari', 'bharti',
  'result', 'admit', 'card', 'answer', 'key', 'syllabus', 'cut', 'off',
  'the', 'of', 'in', 'and', 'to', 'a', 'an', 'by', 'on', 'at', 'for',
  'from', 'with', 'is', 'are', 'was', 'new', 'latest', 'total', 'under',
  '2022', '2023', '2024', '2025', '2026', '2027',
  'combined', 'level', 'higher', 'secondary', 'multi', 'tasking', 'staff',
  'tier', 'phase', 'stage', 'paper',
  'india', 'indian', 'national', 'central', 'government', 'govt',
};

Set<String> _titleTokens(String raw) => raw
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.length > 1 && !_kStopWords.contains(w))
    .toSet();

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  return a.intersection(b).length / a.union(b).length;
}

int _jobQuality(Job j) =>
    (j.vacancies > 0 ? 2 : 0) +
    (j.isFree ? 1 : 0) +
    ((j.payScale?.isNotEmpty ?? false) ? 2 : 0) +
    (j.qualifications.isNotEmpty ? 1 : 0) +
    ((j.documentsNeeded?.isNotEmpty ?? false) ? 1 : 0);

List<Job> _deduplicateJobs(List<Job> jobs) {
  if (jobs.length < 2) return jobs;
  final tokens = jobs.map((j) => _titleTokens(j.title)).toList();
  final drop = List<bool>.filled(jobs.length, false);
  for (var i = 0; i < jobs.length; i++) {
    if (drop[i]) continue;
    // An empty token set has nothing to match — skip rather than risk a
    // false-positive Jaccard=1.0 collapse of two empty-titled jobs.
    if (tokens[i].isEmpty) continue;
    final stI = jobs[i].states.map((s) => s.toLowerCase()).toSet();
    for (var j = i + 1; j < jobs.length; j++) {
      if (drop[j]) continue;
      if (tokens[j].isEmpty) continue;
      if (jobs[i].category != jobs[j].category) continue;
      final stJ = jobs[j].states.map((s) => s.toLowerCase()).toSet();
      final bothExplicit = !stI.contains('all') && stI.isNotEmpty &&
                           !stJ.contains('all') && stJ.isNotEmpty;
      if (bothExplicit && stI.intersection(stJ).isEmpty) continue;
      if (_jaccard(tokens[i], tokens[j]) >= 0.72) {
        if (_jobQuality(jobs[i]) >= _jobQuality(jobs[j])) {
          drop[j] = true;
        } else {
          drop[i] = true;
          break;
        }
      }
    }
  }
  return [for (var i = 0; i < jobs.length; i++) if (!drop[i]) jobs[i]];
}

// ─────────────────────────────────────────
// FEED TAB
// ─────────────────────────────────────────
class _FeedTab extends StatefulWidget {
  final int userId;
  final ApiService api;
  const _FeedTab({required this.userId, required this.api});

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _scrollController = ScrollController();
  final List<Job> _jobs = [];
  bool _isLoading = true;
  bool _hasMore   = true;
  int  _page      = 1;
  bool _isCached  = false;
  DateTime? _cachedAt;
  // Reentrancy guard — prevents a pull-to-refresh from racing an in-flight
  // load and interleaving the resulting setState calls (which produced
  // duplicate page-1 jobs and a brief flicker between cached/fresh).
  bool _fetchInFlight = false;

  String? _selectedFilter; // null = all
  bool _freeOnly = false;  // free jobs toggle
  String _sortBy = 'deadline'; // deadline | vacancies | newest
  UserProfile? _profile;
  String _userName = '';
  int _activeAlertCount = 0;
  String? _stateOverride; // null = use profile state; "all_india" = drop filter
  int _quizStreak = 0;
  bool _disclaimerSeen = true; // default true; set false only if pref missing

  static const _kStatePrefKey = 'home_state_override';

  // Top-12 traffic states for govt-job searches in India (incl. All India)
  static const List<(String, String)> _stateChips = [
    ('', '🇮🇳 All India'),
    ('up',           '🛕 UP'),
    ('bihar',        '🪔 Bihar'),
    ('maharashtra',  '🏙️ Maharashtra'),
    ('rajasthan',    '🏜️ Rajasthan'),
    ('mp',           '🌾 MP'),
    ('west bengal',  '🐅 West Bengal'),
    ('karnataka',    '☕ Karnataka'),
    ('tamil nadu',   '🌴 Tamil Nadu'),
    ('gujarat',      '🦁 Gujarat'),
    ('delhi',        '🏛️ Delhi'),
    ('punjab',       '🌾 Punjab'),
    ('haryana',      '🌾 Haryana'),
    ('odisha',       '🏛️ Odisha'),
    ('telangana',    '🏛️ Telangana'),
  ];

  @override
  void initState() {
    super.initState();
    _restoreStateOverride().then((_) => _loadJobs());
    SharedPreferences.getInstance().then((p) {
      final streak = p.getInt('quiz_streak') ?? 0;
      final seen = p.getBool('disclaimer_seen') ?? false;
      if (mounted) {
        setState(() {
        if (streak > 0) { _quizStreak = streak; }
        _disclaimerSeen = seen;
      });
      }
    });
    widget.api.getSavedProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    });
    widget.api.getPersonalInfo().then((info) {
      if (mounted && info.name.isNotEmpty) setState(() => _userName = info.name.split(' ').first);
    });
    widget.api.syncFcmToken(widget.userId);
    // Fire-and-forget: check saved job deadlines on app startup
    // (also triggered on Saved tab open — this ensures users who
    //  only browse the feed still get deadline alerts)
    widget.api.getSavedJobs(widget.userId).then(
      (saved) => NotificationService.checkDeadlines(saved),
    );
    // Load active alert count for bell badge
    widget.api.getAlertRules().then((rules) {
      final active = rules.where((r) => r.isActive).length;
      if (mounted) setState(() => _activeAlertCount = active);
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs({bool refresh = false}) async {
    if (_fetchInFlight) return;
    _fetchInFlight = true;
    try {
      if (refresh) {
        if (!mounted) return;
        setState(() { _jobs.clear(); _page = 1; _hasMore = true; _isCached = false; });
      }

      // Page 1 first-load: show Hive cache immediately, then fetch fresh in background
      if (_page == 1 && _jobs.isEmpty) {
        final cached = await widget.api.getCachedFeed(stateOverride: _stateOverride);
        if (!mounted) return;
        if (cached.isNotEmpty) {
          setState(() { _jobs.addAll(_deduplicateJobs(cached)); _isCached = true; _isLoading = false; });
        } else {
          setState(() => _isLoading = true);
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = true);
      }

      final data = await widget.api.getJobFeed(
        userId: widget.userId,
        page: _page,
        stateOverride: _stateOverride,
      );
      if (!mounted) return;
      final freshJobs = (data['jobs'] is List<Job>)
          ? data['jobs'] as List<Job>
          : <Job>[];
      final wasCached = data['is_cached'] as bool? ?? false;
      setState(() {
        if (_page == 1) _jobs.clear();
        final existingIds = _jobs.map((j) => j.id).toSet();
        _jobs.addAll(freshJobs.where((j) => !existingIds.contains(j.id)));
        final deduped = _deduplicateJobs(List<Job>.from(_jobs));
        _jobs..clear()..addAll(deduped);
        _hasMore  = data['has_more'] as bool? ?? false;
        _isLoading = false;
        _isCached  = wasCached;
        if (wasCached && data['cached_at'] != null) {
          _cachedAt = DateTime.tryParse(data['cached_at'] as String);
        } else {
          _isCached = false;
        }
      });
      // Check smart alert rules against fresh (non-cached) jobs
      if (!wasCached && _page == 1) {
        NotificationService.checkAlerts(freshJobs, widget.api);
      }
    } finally {
      _fetchInFlight = false;
    }
  }

  void _loadMore() {
    if (_fetchInFlight) return;
    _page++;
    _loadJobs();
  }

  List<Job> get _filteredJobs {
    var list = _selectedFilter == null
        ? List<Job>.from(_jobs)
        : _jobs.where((j) => j.category == _selectedFilter).toList();
    if (_freeOnly) list = list.where((j) => j.isFree).toList();
    switch (_sortBy) {
      case 'vacancies':
        list.sort((a, b) => b.vacancies.compareTo(a.vacancies));
        break;
      case 'newest':
        // Keep original order (backend returns newest-first)
        break;
      default: // deadline
        list.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    }
    return list;
  }

  int _countForCategory(String? category) {
    var list = category == null ? _jobs : _jobs.where((j) => j.category == category).toList();
    if (_freeOnly) list = list.where((j) => j.isFree).toList();
    return list.length;
  }

  // Builds a flat list of display items: section headers, job cards, and ad slots.
  // Live subtitle: "12 new today • Updated 2h ago" beats a static tagline —
  // it tells the user the feed is fresh (trust) and what's waiting (pull).
  String get _feedSubtitle {
    if (_jobs.isEmpty) {
      return _userName.isNotEmpty
          ? 'Your Sarkari Jobs Today'
          : 'Today\'s Government Jobs';
    }
    final newCount = _jobs.where((j) => j.isNew).length;
    var newest = '';
    for (final j in _jobs) {
      if (j.scrapedAt.compareTo(newest) > 0) newest = j.scrapedAt;
    }
    String ago = '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(newest));
      ago = diff.inMinutes < 60
          ? '${diff.inMinutes}m ago'
          : diff.inHours < 24
              ? '${diff.inHours}h ago'
              : '${diff.inDays}d ago';
    } catch (_) {}
    final parts = <String>[
      if (newCount > 0) '$newCount new today',
      if (ago.isNotEmpty) 'Updated $ago',
    ];
    return parts.isEmpty ? 'Your Sarkari Jobs Today' : parts.join('  •  ');
  }

  List<Object> get _feedItems {
    final all = _filteredJobs;
    if (all.isEmpty) return [];

    final closing  = all.where((j) => j.urgency == 'red').toList();
    final newToday = all.where((j) => j.isNew && j.urgency != 'red').toList();
    final rest     = all.where((j) => j.urgency != 'red' && !j.isNew).toList();

    // Quick-access strip rides at the top of the feed (scrolls away while
    // browsing). Admit cards / results are the highest-intent destinations
    // for sarkari aspirants — surfacing them here instead of burying them
    // in Tools measurably lifts announcement engagement.
    final items = <Object>['__quick__'];
    // Narrow preferences (e.g. only PSU+UPSC) can shrink the feed to a
    // handful of stale jobs while fresh ones land in other categories.
    // Tell the user why the feed is thin instead of looking broken.
    if (all.length < 10) items.add('__thin__');
    int jobCount = 0;

    void addJob(Job j) {
      items.add(j);
      jobCount++;
      if (jobCount % 5 == 0) items.add('__ad__');
    }

    if (closing.isNotEmpty) {
      items.add(('🚨 Closing Soon', '${closing.length} jobs expiring within 7 days'));
      for (final j in closing) {
        addJob(j);
      }
    }
    if (newToday.isNotEmpty) {
      items.add(('🆕 New Today', '${newToday.length} freshly added'));
      for (final j in newToday) {
        addJob(j);
      }
    }
    if (rest.isNotEmpty) {
      if (closing.isNotEmpty || newToday.isNotEmpty) {
        items.add(('📋 All Jobs', '${rest.length} jobs'));
      }
      for (final j in rest) {
        addJob(j);
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title + subtitle column
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty ? 'Namaste, $_userName! 🇮🇳' : '🇮🇳 JobMitra',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _feedSubtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Jobs count pill badge
                  if (_jobs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9933),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_jobs.length} Jobs',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (_quizStreak > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🔥 $_quizStreak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Bell / Alerts button with active badge
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AlertsScreen(api: widget.api)),
                    ).then((_) {
                      // Refresh badge count when returning from AlertsScreen
                      widget.api.getAlertRules().then((rules) {
                        final active = rules.where((r) => r.isActive).length;
                        if (mounted) setState(() => _activeAlertCount = active);
                      });
                    }),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                        ),
                        if (_activeAlertCount > 0)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _activeAlertCount > 9 ? '9+' : '$_activeAlertCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!_disclaimerSeen) _buildDisclaimerStrip(),
          // State landing chips (top-traffic Indian states)
          _buildStateBar(),
          // Category filter chips + free toggle
          _buildFilterBar(),
          // Sort bar
          _buildSortBar(),
          // Offline cache banner
          if (_isCached) _buildCacheBanner(),
          // Jobs list
          Expanded(
            child: _isLoading && _jobs.isEmpty
                ? _buildShimmer()
                : _filteredJobs.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadJobs(refresh: true),
                        color: AppColors.primary,
                        child: Builder(builder: (ctx) {
                          final items = _feedItems;
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: items.length + (_hasMore ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i == items.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(child: SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: AppColors.primary),
                                  )),
                                );
                              }
                              final item = items[i];
                              if (item == '__ad__') return const BannerAdWidget();
                              if (item == '__quick__') return _buildQuickAccessRow();
                              if (item == '__thin__') return _buildThinFeedBanner();
                              if (item is (String, String)) {
                                return _SectionHeader(title: item.$1, subtitle: item.$2);
                              }
                              final job = item as Job;
                              return JobCard(
                                job: job,
                                profile: _profile,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobDetailScreen(
                                      jobId: job.id,
                                      api: widget.api,
                                      userId: widget.userId,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _markDisclaimerSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('disclaimer_seen', true);
    if (mounted) setState(() => _disclaimerSeen = true);
  }

  Widget _buildDisclaimerStrip() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Color(0xFFE65100)),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _markDisclaimerSeen();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DisclaimerScreen()),
                );
              },
              child: const Text(
                'Not affiliated with any Govt. entity. Info aggregated from official sources.',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFBF360C),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _markDisclaimerSeen();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DisclaimerScreen()),
              );
            },
            child: const Text('View sources',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFBF360C),
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _markDisclaimerSeen,
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.close, size: 14, color: Color(0xFFBF360C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheBanner() {
    final mins = _cachedAt != null
        ? DateTime.now().difference(_cachedAt!).inMinutes
        : 0;
    final timeText = mins < 1 ? 'just now' : '$mins min ago';
    return Container(
      width: double.infinity,
      color: Colors.amber[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cached data — last updated $timeText',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _loadJobs(refresh: true),
            child: Icon(Icons.refresh_rounded, size: 20, color: Colors.amber[800]),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreStateOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kStatePrefKey);
    if (mounted) setState(() => _stateOverride = saved);
  }

  Future<void> _setStateOverride(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null || code.isEmpty) {
      await prefs.remove(_kStatePrefKey);
    } else {
      await prefs.setString(_kStatePrefKey, code);
    }
    if (!mounted) return;
    setState(() => _stateOverride = (code == null || code.isEmpty) ? null : code);
    _loadJobs(refresh: true);
  }

  // Shown when the filtered feed has <10 jobs — narrow job-type
  // preferences are usually the cause, and the fix is one tap away.
  Widget _buildThinFeedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Kam jobs dikh rahi hain? Job categories badhao — '
              'aur naukriyan milengi',
              style: TextStyle(fontSize: 12.5, height: 1.4,
                  color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileEditScreen(
                      api: widget.api, userId: widget.userId),
                ),
              );
              _loadJobs(refresh: true);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Badhao',
                  style: TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // Quick-access shortcuts to the highest-intent announcement tabs.
  // Rendered as the first feed item so it scrolls away while browsing jobs.
  Widget _buildQuickAccessRow() {
    Widget shortcut(String emoji, String label, String type, Color color) {
      return Expanded(
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AnnouncementsScreen(api: widget.api, initialType: type),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          shortcut('📊', 'Results', 'result', const Color(0xFF1A6B3C)),
          const SizedBox(width: 10),
          shortcut('🎟️', 'Admit Cards', 'admit_card', const Color(0xFFE65100)),
          const SizedBox(width: 10),
          shortcut('🔑', 'Answer Keys', 'answer_key', const Color(0xFF6A1B9A)),
        ],
      ),
    );
  }

  Widget _buildStateBar() {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _stateChips.length,
        itemBuilder: (ctx, i) {
          final (code, label) = _stateChips[i];
          final isAll       = code.isEmpty;
          final isAllIndia  = isAll;
          final apiValue    = isAllIndia ? 'all_india' : code;
          final selected = isAllIndia
              ? (_stateOverride == 'all_india')
              : (_stateOverride == code);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => _setStateOverride(selected ? null : apiValue),
              selectedColor: AppColors.primary.withValues(alpha: 0.18),
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : Colors.grey.shade300,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    // Only show categories with at least 1 job once jobs are loaded
    // (Always keep "All" and the currently selected filter visible)
    final categories = <String?>[
      null, // "All"
      ...JobCategories.all
          .map((c) => c['key'] as String)
          .where((key) =>
              !_jobs.isNotEmpty ||      // show all while still loading
              _countForCategory(key) > 0 ||
              key == _selectedFilter),  // keep selected even if count drops to 0
    ];

    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final key      = categories[i];
          final cat      = key == null ? null : JobCategories.all.firstWhere((c) => c['key'] == key);
          final label    = key == null ? 'All' : cat?['label'] as String;
          final emoji    = key == null ? '🔍' : cat?['icon'] as String;
          final selected = _selectedFilter == key;
          final count    = _countForCategory(key);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('$emoji $label${_jobs.isNotEmpty ? ' ($count)' : ''}'),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFilter = key),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortBar() {
    const sortOptions = [
      ('deadline', '⏰ Deadline'),
      ('vacancies', '👥 Vacancies'),
      ('newest',   '🆕 Newest'),
    ];
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(
          children: [
            // Sort buttons
            ...sortOptions.map((opt) {
              final selected = _sortBy == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _sortBy = opt.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Divider
            Container(width: 1, height: 14, color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 6)),
            // Free jobs toggle — moved here from filter bar
            GestureDetector(
              onTap: () => setState(() => _freeOnly = !_freeOnly),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _freeOnly
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _freeOnly
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '💰 Free',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _freeOnly ? FontWeight.w700 : FontWeight.w500,
                    color: _freeOnly ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilter = _selectedFilter != null || _freeOnly;
    final catLabel  = _selectedFilter != null
        ? (JobCategories.all.firstWhere(
            (c) => c['key'] == _selectedFilter,
            orElse: () => {'label': _selectedFilter!},
          )['label'] as String)
        : null;

    final String emoji, title, subtitle;
    if (hasFilter) {
      emoji    = '🔍';
      title    = catLabel != null
          ? 'No $catLabel Jobs Found'
          : 'No Free Jobs Found';
      subtitle = 'Try a different filter or refresh';
    } else {
      emoji    = '😔';
      title    = 'No Jobs Found';
      subtitle = 'Pull down to refresh';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (hasFilter) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => setState(() { _selectedFilter = null; _freeOnly = false; }),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear Filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: List.generate(5, (_) => _shimmerCard()),
        ),
      ),
    );
  }

  Widget _shimmerCard() {
    // Placeholder boxes are explicit gray so the shimmer gradient has visible
    // shapes to animate across. White-on-white would just produce a uniform
    // wash and look broken.
    const ph = Color(0xFFE0E0E0);
    return Container(
      height: 160,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            decoration: const BoxDecoration(
              color: ph,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 88, height: 24, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(12))),
                    const SizedBox(width: 8),
                    Container(width: 70, height: 24, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(12))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 15, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(width: 220, height: 15, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(width: 160, height: 12, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(width: 72, height: 28, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(width: 8),
                    Container(width: 60, height: 28, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(8))),
                    const Spacer(),
                    Container(width: 72, height: 32, decoration: BoxDecoration(color: ph, borderRadius: BorderRadius.circular(20))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────
// SECTION HEADER WIDGET
// ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, width: 60, color: AppColors.divider),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────
class _ProfileTab extends StatefulWidget {
  final int userId;
  const _ProfileTab({required this.userId});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _api = ApiService();
  UserProfile? _profile;
  int? _userId;
  String _userName = '';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _api.getSavedProfile().then((p) => setState(() => _profile = p));
    _api.getSavedUserId().then((id) => setState(() => _userId = id));
    _api.getPersonalInfo().then((info) {
      if (mounted && info.name.isNotEmpty) setState(() => _userName = info.name);
    });
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = '${info.version} (build ${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _profile == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // Gradient header
                SliverToBoxAdapter(child: _buildHeader()),
                // Info tiles
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _buildSectionTitle('Personal Info'),
                      const SizedBox(height: 10),
                      _buildInfoTile(Icons.location_on_rounded, 'State / Region', _profile!.state, const Color(0xFF1565C0)),
                      _buildInfoTile(Icons.school_rounded, 'Education', _titleCase(_profile!.education), const Color(0xFF6A1B9A)),
                      _buildInfoTile(Icons.badge_rounded, 'Category', _titleCase(_profile!.category), const Color(0xFF00695C)),
                      _buildInfoTile(Icons.cake_rounded, 'Age', '${_profile!.age} yrs', const Color(0xFFE65100)),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Job Preferences'),
                      const SizedBox(height: 10),
                      _buildJobTypesTile(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Form Fill Details'),
                      const SizedBox(height: 10),
                      _buildFormDetailsTile(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Notifications & Language'),
                      const SizedBox(height: 10),
                      _buildNotifPrefsTile(),
                      const SizedBox(height: 10),
                      _buildLanguageTile(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Support'),
                      const SizedBox(height: 10),
                      _buildSupportTile(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Legal & Info'),
                      const SizedBox(height: 10),
                      _buildLegalTile(),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            children: [
              // Avatar — name initial; a person icon (not a cryptic "?")
              // when the name isn't filled. Tap opens Personal Info so the
              // empty avatar is its own call-to-action.
              GestureDetector(
                onTap: _userName.isNotEmpty
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PersonalInfoScreen(api: _api)),
                        );
                        final info = await _api.getPersonalInfo();
                        if (mounted && info.name.isNotEmpty) {
                          setState(() => _userName = info.name);
                        }
                      },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A6B3C),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                  ),
                  child: Center(
                    child: _userName.isNotEmpty
                        ? Text(
                            _userName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded,
                            size: 34, color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _userName.isNotEmpty ? 'Namaste, $_userName!' : 'My Profile',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JobMitra filters jobs based on your profile',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  if (_userId == null) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileEditScreen(api: _api, userId: _userId!),
                    ),
                  );
                  // Reload profile after editing
                  _api.getSavedProfile().then((p) { if (mounted) setState(() => _profile = p); });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildCompletionBar(),
              const SizedBox(height: 16),
              // Quick pills row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPill(_profile!.state),
                  const SizedBox(width: 8),
                  _buildPill(_titleCase(_profile!.category)),
                  const SizedBox(width: 8),
                  _buildPill('${_profile!.age} yrs'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
  }

  Widget _buildCompletionBar() {
    int filled = 0;
    final p = _profile!;
    if (p.state.isNotEmpty) filled++;
    if (p.education.isNotEmpty) filled++;
    if (p.category.isNotEmpty) filled++;
    if (p.age > 0) filled++;
    if (p.jobTypes.isNotEmpty) filled++;
    const total = 5;
    final pct = filled / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Complete',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobTypesTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job Types', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  Text('Preferred Job Types', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _profile!.jobTypes.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormDetailsTile() {
    return FutureBuilder(
      future: _api.getPersonalInfo(),
      builder: (context, snap) {
        final info    = snap.data;
        final filled  = info?.filledCount ?? 0;
        final isEmpty = info == null || info.isEmpty;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PersonalInfoScreen(api: _api)),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A6B3C).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF1A6B3C), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Form Fill Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        isEmpty
                            ? 'Name, DOB, Category not filled yet'
                            : '$filled/11 fields filled — copy while applying',
                        style: TextStyle(fontSize: 11, color: isEmpty ? Colors.orange[700] : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isEmpty ? Icons.warning_amber_rounded : Icons.chevron_right_rounded,
                  color: isEmpty ? Colors.orange : Colors.grey[400],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _aboutRow(
            icon: Icons.share_rounded,
            color: const Color(0xFF1A6B3C),
            title: 'Share JobMitra',
            subtitle: 'Apne friends ko bhi naukri alerts dilaao',
            onTap: _shareApp,
          ),
          const Divider(height: 1, indent: 56),
          _aboutRow(
            icon: Icons.star_outline_rounded,
            color: const Color(0xFFE65100),
            title: 'Rate App on Play Store',
            subtitle: '5-star reviews app ko grow karte hain',
            onTap: _rateApp,
          ),
          const Divider(height: 1, indent: 56),
          _aboutRow(
            icon: Icons.email_outlined,
            color: const Color(0xFF2E7D32),
            title: 'Contact Support',
            subtitle: 'support.jobmitra@gmail.com',
            onTap: () => _openExternal(
                'mailto:support.jobmitra@gmail.com?subject=JobMitra%20Feedback'),
          ),
          const Divider(height: 1, indent: 56),
          // Play Console Data Safety form requires either an in-app delete
          // affordance or a publicly reachable URL.
          _aboutRow(
            icon: Icons.delete_forever_outlined,
            color: const Color(0xFFC62828),
            title: 'Delete My Data',
            subtitle: 'Request account & profile deletion',
            onTap: () => _openExternal(
                'https://buhtig47.github.io/jobmitra/delete-data.html'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _aboutRow(
            icon: Icons.gavel_rounded,
            color: const Color(0xFFE65100),
            title: 'Disclaimer & Official Sources',
            subtitle: 'Not affiliated with Govt. View 22+ official sources',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DisclaimerScreen()),
            ),
          ),
          const Divider(height: 1, indent: 56),
          _aboutRow(
            icon: Icons.privacy_tip_outlined,
            color: const Color(0xFF1565C0),
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () => _openExternal(
                'https://buhtig47.github.io/jobmitra/privacy.html'),
          ),
          const Divider(height: 1, indent: 56),
          _aboutRow(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF6A1B9A),
            title: 'App Version',
            subtitle: _appVersion.isNotEmpty ? _appVersion : '—',
            onTap: null,
          ),
        ],
      ),
    );
  }

  static const _playStoreId = 'com.jobmitra.app';

  Future<void> _shareApp() async {
    const msg =
        '🇮🇳 *JobMitra — Free Sarkari Naukri App*\n\n'
        '✅ 270+ govt jobs daily\n'
        '✅ Eligibility filter — no waste results\n'
        '✅ Admit cards & results in one place\n'
        '✅ Daily GK quiz + current affairs\n'
        '✅ Deadline & exam date alerts\n\n'
        '👇 Free download karo:\n'
        'https://play.google.com/store/apps/details?id=$_playStoreId';
    await Share.share(msg);
  }

  Future<void> _rateApp() async {
    // market:// opens Play Store app directly. https fallback for emulator
    // or devices without Play Store installed.
    final marketUri = Uri.parse('market://details?id=$_playStoreId');
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      return;
    }
    await _openExternal(
        'https://play.google.com/store/apps/details?id=$_playStoreId');
  }

  Widget _aboutRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildLanguageTile() {
    final label = L10n.supported[L10n.current] ?? 'Hinglish';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LanguagePickerScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.translate_rounded,
                  color: Color(0xFF6A1B9A), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Language',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    'Currently: $label',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifPrefsTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationPrefsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFE65100), size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 3),
                  Text(
                    'Choose which exams send you push alerts',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
