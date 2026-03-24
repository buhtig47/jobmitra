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
          _ProfileTab(userId: widget.userId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) {
          // Force Saved tab to reload fresh data every time it's visited
          if (i == 2 && _selectedTab != 2) _savedRefreshKey++;
          setState(() => _selectedTab = i);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.12),
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
  UserProfile? _profile;
  List<Job> _recentlyViewed = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
    widget.api.getSavedProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    });
    widget.api.getRecentlyViewed().then((r) {
      if (mounted) setState(() => _recentlyViewed = r);
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
    setState(() => _isLoading = true);

    final data = await widget.api.getJobFeed(userId: widget.userId, page: _page);
    setState(() {
      _jobs.addAll(data['jobs'] as List<Job>);
      _hasMore   = data['has_more'] as bool;
      _isLoading = false;
      _isCached  = data['is_cached'] as bool? ?? false;
      if (_isCached && data['cached_at'] != null) {
        _cachedAt = DateTime.tryParse(data['cached_at'] as String);
      }
    });
  }

  void _loadMore() {
    _page++;
    _loadJobs();
  }

  List<Job> get _filteredJobs {
    var list = _selectedFilter == null
        ? _jobs
        : _jobs.where((j) => j.category == _selectedFilter).toList();
    if (_freeOnly) list = list.where((j) => j.isFree).toList();
    return list;
  }

  void _refreshRecentlyViewed() {
    widget.api.getRecentlyViewed().then((r) {
      if (mounted) setState(() => _recentlyViewed = r);
    });
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
                          'Aaj ki Sarkari Naukri',
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
                          itemCount: (_recentlyViewed.isNotEmpty ? 1 : 0) +
                              _filteredJobs.length +
                              (_filteredJobs.length ~/ 5) + // ad slots
                              (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, rawIdx) {
                            // Recently viewed strip as first item
                            final offset = _recentlyViewed.isNotEmpty ? 1 : 0;
                            if (_recentlyViewed.isNotEmpty && rawIdx == 0) {
                              return _buildRecentlyViewed();
                            }
                            // Map adjusted index → job or ad
                            // Every 6th slot (pos 5 in a group of 6) is a banner ad
                            final adj = rawIdx - offset;
                            final group = adj ~/ 6;
                            final pos   = adj % 6;
                            final jobIdx = group * 5 + pos;

                            if (pos == 5) return const BannerAdWidget();

                            if (jobIdx < _filteredJobs.length) {
                              final job = _filteredJobs[jobIdx];
                              return JobCard(
                                job: job,
                                profile: _profile,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => JobDetailScreen(
                                        jobId: job.id,
                                        api: widget.api,
                                        userId: widget.userId,
                                      ),
                                    ),
                                  ).then((_) => _refreshRecentlyViewed());
                                },
                              );
                            }
                            // Load-more spinner
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
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
    final timeText = mins < 1 ? 'abhi' : '$mins min pehle';
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
    final categories = [null, ...JobCategories.all.map((c) => c['key'] as String)];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length + 1, // +1 for free toggle
        itemBuilder: (ctx, i) {
          // Last chip: Free Jobs toggle
          if (i == categories.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('💰 Free Only'),
                selected: _freeOnly,
                onSelected: (_) => setState(() => _freeOnly = !_freeOnly),
                selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                checkmarkColor: const Color(0xFF2E7D32),
                labelStyle: TextStyle(
                  color: _freeOnly ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                  fontWeight: _freeOnly ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            );
          }
          final key = categories[i];
          final cat = key == null
              ? null
              : JobCategories.all.firstWhere((c) => c['key'] == key);
          final label = key == null ? 'Sab' : cat?['label'];
          final emoji = key == null ? '🔍' : cat?['icon'];
          final selected = _selectedFilter == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('$emoji $label'),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFilter = key),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'Haal hi mein dekha',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentlyViewed.length,
            itemBuilder: (ctx, i) {
              final job = _recentlyViewed[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailScreen(
                        jobId: job.id,
                        api: widget.api,
                        userId: widget.userId,
                      ),
                    ),
                  ).then((_) => _refreshRecentlyViewed());
                },
                child: Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        job.cleanTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(job.categoryEmoji,
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.categoryLabel,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😔', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text('Abhi koi job nahi mili', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Pull down karo refresh karne ke liye',
            style: Theme.of(context).textTheme.bodyMedium),
        ],
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
                      _buildInfoTile(Icons.cake_rounded, 'Age', '${_profile!.age} saal', const Color(0xFFE65100)),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Job Preferences'),
                      const SizedBox(height: 10),
                      _buildJobTypesTile(),
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
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
                ),
                child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Mera Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JobMitra aapke liye jobs filter karta hai',
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
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
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('Profile Edit Karo', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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
                  _buildPill('${_profile!.age} saal'),
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
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                  color: AppColors.accent.withOpacity(0.12),
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
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
}
