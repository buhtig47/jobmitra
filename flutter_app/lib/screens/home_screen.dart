// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import '../widgets/banner_ad_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'job_detail_screen.dart';
import 'search_screen.dart';
import 'saved_jobs_screen.dart';
import 'profile_edit_screen.dart';
import 'personal_info_screen.dart';
import 'tools_screen.dart';
import 'alerts_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  int _savedRefreshKey = 0; // Increments every time Saved tab is visited
  final _api = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _FeedTab(userId: widget.userId, api: _api),
          SearchScreen(api: _api),
          SavedJobsScreen(key: ValueKey(_savedRefreshKey), userId: widget.userId, api: _api),
          ToolsScreen(api: _api),
          _ProfileTab(userId: widget.userId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) {
          if (i == 2 && _selectedTab != 2) _savedRefreshKey++;
          setState(() => _selectedTab = i);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work, color: AppColors.primary),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search, color: AppColors.primary),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark, color: AppColors.primary),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman, color: AppColors.primary),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
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
    final stI = jobs[i].states.map((s) => s.toLowerCase()).toSet();
    for (var j = i + 1; j < jobs.length; j++) {
      if (drop[j]) continue;
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

  String? _selectedFilter; // null = all
  bool _freeOnly = false;  // free jobs toggle
  String _sortBy = 'deadline'; // deadline | vacancies | newest
  UserProfile? _profile;
  int _activeAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    widget.api.getSavedProfile().then((p) {
      if (mounted) setState(() => _profile = p);
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

  Future<void> _loadJobs({bool refresh = false}) async {
    if (refresh) {
      setState(() { _jobs.clear(); _page = 1; _hasMore = true; _isCached = false; });
    }

    // Page 1 first-load: show Hive cache immediately, then fetch fresh in background
    if (_page == 1 && _jobs.isEmpty) {
      final cached = await widget.api.getCachedFeed();
      if (cached.isNotEmpty && mounted) {
        setState(() { _jobs.addAll(_deduplicateJobs(cached)); _isCached = true; _isLoading = false; });
      } else {
        setState(() => _isLoading = true);
      }
    } else {
      setState(() => _isLoading = true);
    }

    final data = await widget.api.getJobFeed(userId: widget.userId, page: _page);
    if (!mounted) return;
    final freshJobs = data['jobs'] as List<Job>;
    final wasCached = data['is_cached'] as bool? ?? false;
    setState(() {
      if (_page == 1) _jobs.clear();
      final existingIds = _jobs.map((j) => j.id).toSet();
      _jobs.addAll(freshJobs.where((j) => !existingIds.contains(j.id)));
      final deduped = _deduplicateJobs(List<Job>.from(_jobs));
      _jobs..clear()..addAll(deduped);
      _hasMore  = data['has_more'] as bool;
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
  }

  void _loadMore() {
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
                      children: const [
                        Text(
                          '🇮🇳 JobMitra',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Today\'s Government Jobs',
                          style: TextStyle(
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
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: _filteredJobs.length +
                              (_filteredJobs.length ~/ 5) + // ad slots
                              (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, rawIdx) {
                            // Every 6th slot (pos 5 in a group of 6) is a banner ad
                            final group  = rawIdx ~/ 6;
                            final pos    = rawIdx % 6;
                            final jobIdx = group * 5 + pos;

                            if (pos == 5) return const BannerAdWidget();

                            if (jobIdx < _filteredJobs.length) {
                              final job = _filteredJobs[jobIdx];
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
                            }
                            // Load-more spinner
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
          // Colored top bar (shimmer target)
          Container(
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
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
                    Container(width: 88, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                    const SizedBox(width: 8),
                    Container(width: 70, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 15, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(width: 220, height: 15, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(width: 160, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(width: 72, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(width: 8),
                    Container(width: 60, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                    const Spacer(),
                    Container(width: 72, height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
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

  @override
  void initState() {
    super.initState();
    _api.getSavedProfile().then((p) => setState(() => _profile = p));
    _api.getSavedUserId().then((id) => setState(() => _userId = id));
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
                      _buildInfoTile(Icons.school_rounded, 'Education', _profile!.education, const Color(0xFF6A1B9A)),
                      _buildInfoTile(Icons.badge_rounded, 'Category', _profile!.category.toUpperCase(), const Color(0xFF00695C)),
                      _buildInfoTile(Icons.cake_rounded, 'Age', '${_profile!.age} yrs', const Color(0xFFE65100)),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Job Preferences'),
                      const SizedBox(height: 10),
                      _buildJobTypesTile(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Form Fill Details'),
                      const SizedBox(height: 10),
                      _buildFormDetailsTile(),
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
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                ),
                child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'My Profile',
                style: TextStyle(
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
              const SizedBox(height: 20),
              // Quick pills row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPill(_profile!.state),
                  const SizedBox(width: 8),
                  _buildPill(_profile!.category.toUpperCase()),
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
                  Text('Interested categories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
}
