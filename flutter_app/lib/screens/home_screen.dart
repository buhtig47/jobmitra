// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import 'job_detail_screen.dart';
import 'search_screen.dart';
import 'saved_jobs_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  final _api = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _FeedTab(userId: widget.userId, api: _api),
          SearchScreen(api: _api),
          SavedJobsScreen(userId: widget.userId, api: _api),
          _ProfileTab(userId: widget.userId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
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

  String? _selectedFilter; // null = all

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) _loadMore();
      }
    });
  }

  Future<void> _loadJobs({bool refresh = false}) async {
    if (refresh) {
      setState(() { _jobs.clear(); _page = 1; _hasMore = true; });
    }
    setState(() => _isLoading = true);

    final data = await widget.api.getJobFeed(userId: widget.userId, page: _page);
    setState(() {
      _jobs.addAll(data['jobs'] as List<Job>);
      _hasMore    = data['has_more'];
      _isLoading  = false;
    });
  }

  void _loadMore() {
    _page++;
    _loadJobs();
  }

  List<Job> get _filteredJobs {
    if (_selectedFilter == null) return _jobs;
    return _jobs.where((j) => j.category == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🇮🇳', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('JobMitra'),
            const Spacer(),
            // Stats badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_jobs.length} jobs',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Category filter chips
          _buildFilterBar(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredJobs.length + (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _filteredJobs.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            return JobCard(
                              job: _filteredJobs[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobDetailScreen(
                                    jobId: _filteredJobs[i].id,
                                    api: widget.api,
                                    userId: widget.userId,
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

  Widget _buildFilterBar() {
    final categories = [null, ...JobCategories.all.map((c) => c['key'] as String)];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final key = categories[i];
          final cat = key == null ? null : JobCategories.all.firstWhere((c) => c['key'] == key);
          final label = key == null ? 'Sab' : cat?['label'];
          final emoji = key == null ? '🔍' : cat?['icon'];
          final selected = _selectedFilter == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('$emoji $label'),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFilter = key),
              selectedColor: AppColors.primary.withOpacity(0.15),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────
// PROFILE TAB (simple)
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

  @override
  void initState() {
    super.initState();
    _api.getSavedProfile().then((p) => setState(() => _profile = p));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: const Text('👤', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoCard('🗺️ State',       _profile!.state),
                _buildInfoCard('🎓 Education',    _profile!.education),
                _buildInfoCard('👤 Category',     _profile!.category.toUpperCase()),
                _buildInfoCard('🎂 Age',          '${_profile!.age} saal'),
                _buildInfoCard('💼 Job Types',    _profile!.jobTypes.join(', ')),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to edit profile / re-onboarding
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Profile Edit Karo',
                    style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
