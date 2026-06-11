// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import '../widgets/banner_ad_widget.dart';
import 'job_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final ApiService api;
  const SearchScreen({super.key, required this.api});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller  = TextEditingController();
  final _focusNode   = FocusNode();
  List<Job> _results = [];
  String? _categoryFilter;
  bool _filterFreeOnly = false;
  bool _isSearching  = false;
  int? _userId;
  String _userCategory = 'general';
  UserProfile? _profile;
  List<String> _recentSearches = [];
  String? _lastQuery;
  String _deadlineFilter = 'any'; // 'any' | 'week' | 'month'
  bool _filterHasVacancies = false;
  bool _filterNewOnly = false;
  String? _stateFilter;

  bool get _hasActiveFilter =>
      _categoryFilter != null ||
      _filterFreeOnly ||
      _deadlineFilter != 'any' ||
      _filterHasVacancies ||
      _filterNewOnly ||
      _stateFilter != null;

  List<Job> get _filteredResults {
    var list = _results.toList();
    if (_categoryFilter != null) list = list.where((j) => j.category == _categoryFilter).toList();
    if (_filterFreeOnly) list = list.where((j) => j.isFree).toList();
    if (_filterHasVacancies) list = list.where((j) => j.vacancies > 0).toList();
    if (_filterNewOnly) {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      list = list.where((j) {
        try { return DateTime.parse(j.scrapedAt).isAfter(cutoff); } catch (_) { return false; }
      }).toList();
    }
    if (_deadlineFilter != 'any') {
      final maxDays = _deadlineFilter == 'week' ? 7 : 30;
      list = list.where((j) => j.daysLeft >= 0 && j.daysLeft <= maxDays).toList();
    }
    if (_stateFilter != null) {
      list = list.where((j) => j.states.contains(_stateFilter)).toList();
    }
    return list;
  }

  // Build a virtual items list: one BannerAdWidget slot after every 5 jobs.
  // Using Object avoids a nullable union — banners are const BannerAdWidget(),
  // jobs are Job instances.
  List<Object> get _displayItems {
    final jobs = _filteredResults;
    final out = <Object>[];
    for (int i = 0; i < jobs.length; i++) {
      out.add(jobs[i]);
      if ((i + 1) % 5 == 0) out.add(const BannerAdWidget());
    }
    return out;
  }

  static const _catLabels = {
    'railway': 'Railway', 'banking': 'Banking', 'ssc': 'SSC',
    'teaching': 'Teaching', 'police': 'Police', 'defence': 'Defence',
    'upsc': 'UPSC', 'anganwadi': 'Anganwadi', 'psu': 'PSU',
    'medical': 'Medical', 'research': 'Research',
    'engineering': 'Engineering', 'legal': 'Legal', 'postal': 'Postal',
    'admin': 'Admin', 'it_tech': 'IT', 'accounts': 'Accounts',
    'forest': 'Forest',
  };

  String _catLabel(String cat) => _catLabels[cat] ?? 'Others';

  Widget _buildResultsList() {
    final items = _displayItems;
    return ListView.builder(
      // Swiping through results drops the keyboard — otherwise it covers
      // the bottom half of the list after every search.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item is BannerAdWidget) return item;
        final job = item as Job;
        return JobCard(
          job: job,
          profile: _profile,
          onTap: () {
            if (_userId == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JobDetailScreen(
                  jobId: job.id,
                  api: widget.api,
                  userId: _userId!,
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const _kRecentKey = 'recent_searches';

  static const _kTrending = [
    ('Railway',   '🚂', Color(0xFF1565C0)),
    ('Banking',   '🏦', Color(0xFF2E7D32)),
    ('SSC',       '📋', Color(0xFF6A1B9A)),
    ('Police',    '👮', Color(0xFF283593)),
    ('UPSC',      '🏛️', Color(0xFF4E342E)),
    ('Teaching',  '📚', Color(0xFF00838F)),
    ('Defence',   '⭐', Color(0xFF558B2F)),
    ('Medical',   '🏥', Color(0xFFC62828)),
    ('Anganwadi', '🌸', Color(0xFFAD1457)),
    ('Research',  '🔬', Color(0xFF4527A0)),
  ];

  @override
  void initState() {
    super.initState();
    widget.api.getSavedUserId().then((id) { if (mounted) setState(() => _userId = id); });
    widget.api.getSavedProfile().then((p) {
      if (p != null && mounted) setState(() { _profile = p; _userCategory = p.category; });
    });
    _loadRecentSearches();
    _controller.addListener(() {
      if (_controller.text.isEmpty && _lastQuery != null) {
        setState(() { _lastQuery = null; _results = []; });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { _recentSearches = prefs.getStringList(_kRecentKey) ?? []; });
  }

  Future<void> _saveRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [query, ..._recentSearches.where((s) => s != query)].take(5).toList();
    await prefs.setStringList(_kRecentKey, updated);
    setState(() => _recentSearches = updated);
  }

  Future<void> _deleteRecentSearch(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = _recentSearches.where((s) => s != term).toList();
    await prefs.setStringList(_kRecentKey, updated);
    setState(() => _recentSearches = updated);
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      // Without visible feedback the user thinks search is broken when they
      // hit submit on a 1-char query (e.g. "U"). Surface the constraint.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Type at least 2 characters to search'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }
    _controller.text = q;
    _focusNode.unfocus();
    await _saveRecentSearch(q);
    setState(() { _isSearching = true; _lastQuery = q; _categoryFilter = null; });
    final results = await widget.api.searchJobs(q, userCategory: _userCategory);
    if (!mounted) return;
    setState(() { _results = results; _isSearching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Premium gradient header with floating search bar ──
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
        child: Column(
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  const Text(
                    '🔍 Job Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_lastQuery != null && _results.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_filteredResults.length} results',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _hasActiveFilter
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                        ),
                        if (_hasActiveFilter)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _lastQuery != null
                    ? '${_results.length} results for "$_lastQuery"'
                    : 'Find your perfect government job',
                style: const TextStyle(color: Colors.white60, fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 14),
            // Floating search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmitted: _search,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Railway, SSC, Police, Banking...',
                    hintStyle: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: AppColors.textHint, size: 20),
                            onPressed: () { _controller.clear(); _focusNode.requestFocus(); },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) return _buildShimmer();
    if (_lastQuery == null) return _buildDiscovery();
    if (_filteredResults.isEmpty) return _buildNoResults();
    return _buildResults();
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        if (_results.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              children: [
                // "All" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _categoryFilter = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _categoryFilter == null
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _categoryFilter == null
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '🔍 All (${_results.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _categoryFilter == null ? FontWeight.w700 : FontWeight.w500,
                          color: _categoryFilter == null ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                // Category chips - only show categories that appear in results
                ..._results.map((j) => j.category).toSet().map((cat) {
                  final count = _results.where((j) => j.category == cat).length;
                  final selected = _categoryFilter == cat;
                  final emoji = const {
                    'railway': '🚂', 'banking': '🏦', 'ssc': '📋', 'teaching': '📚',
                    'police': '👮', 'defence': '⭐', 'upsc': '🏛️', 'anganwadi': '🌸',
                    'psu': '🏭', 'medical': '🏥', 'research': '🔬', 'engineering': '⚙️',
                    'legal': '⚖️', 'postal': '📮', 'admin': '🗂️', 'it_tech': '💻',
                    'accounts': '💰', 'forest': '🌳',
                  }[cat] ?? '💼';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _categoryFilter = selected ? null : cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent,
                          ),
                        ),
                        // "📋 SSC (10)" — bare "📋 10" was unreadable
                        child: Text(
                          '$emoji ${_catLabel(cat)} ($count)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        Expanded(
          child: _buildResultsList(),
        ),
      ],
    );
  }

  Widget _buildDiscovery() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Recent searches (shown first if available) ──
          if (_recentSearches.isNotEmpty) ...[
            _buildSectionHeader(
              '⏰ Recent Searches',
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove(_kRecentKey);
                  setState(() => _recentSearches = []);
                },
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: _recentSearches.asMap().entries.map((entry) {
                  final i = entry.key;
                  final term = entry.value;
                  final isLast = i == _recentSearches.length - 1;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () { _controller.text = term; _search(term); },
                        onLongPress: () => _deleteRecentSearch(term),
                        borderRadius: BorderRadius.vertical(
                          top: i == 0 ? const Radius.circular(16) : Radius.zero,
                          bottom: isLast ? const Radius.circular(16) : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  term,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.north_west_rounded,
                                size: 16,
                                color: AppColors.textHint,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: 52, color: Color(0xFFF0F0F0)),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Long press to remove a recent search',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
            const SizedBox(height: 28),
          ],

          // ── Trending searches ──
          _buildSectionHeader('🔥 Trending Searches', null),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kTrending.map((t) {
              final (term, emoji, color) = t;
              return GestureDetector(
                onTap: () { _controller.text = term; _search(term); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        term,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Widget? trailing) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  void _showFilterSheet() {
    String? tempCat = _categoryFilter;
    bool tempFree = _filterFreeOnly;
    String tempDeadline = _deadlineFilter;
    bool tempHasVacancies = _filterHasVacancies;
    bool tempNewOnly = _filterNewOnly;
    String? tempState = _stateFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget toggleTile(String emoji, String label, bool value, VoidCallback onTap) {
            return GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: value ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: value ? AppColors.primary : AppColors.divider),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    if (value) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            );
          }

          Widget deadlineOption(String value, String label) {
            final sel = tempDeadline == value;
            return GestureDetector(
              onTap: () => setS(() => tempDeadline = value),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header (fixed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text('Filters', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setS(() {
                              tempCat = null; tempFree = false; tempDeadline = 'any';
                              tempHasVacancies = false; tempNewOnly = false; tempState = null;
                            }),
                            child: const Text('Clear all', style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // State filter (S2)
                        const Text('State', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _filterChip('🌏 All India', null, tempState, (v) => setS(() => tempState = v)),
                              const SizedBox(width: 8),
                              ...IndianStates.all
                                  .where((s) => s != 'All India')
                                  .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _filterChip(s, s, tempState, (v) => setS(() => tempState = v)),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Category
                        const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _filterChip('All', null, tempCat, (v) => setS(() => tempCat = v)),
                            ...JobCategories.all.map((c) => _filterChip(
                              '${c['icon']} ${c['label']}', c['key'] as String, tempCat, (v) => setS(() => tempCat = v),
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Deadline
                        const Text('Deadline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            deadlineOption('any', '📅 Any'),
                            deadlineOption('week', '⚡ This Week'),
                            deadlineOption('month', '🗓️ This Month'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Options
                        const Text('Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        toggleTile('💸', 'Free to Apply only', tempFree, () => setS(() => tempFree = !tempFree)),
                        toggleTile('🏢', 'Has Vacancies listed', tempHasVacancies, () => setS(() => tempHasVacancies = !tempHasVacancies)),
                        toggleTile('🆕', 'New Jobs (last 7 days)', tempNewOnly, () => setS(() => tempNewOnly = !tempNewOnly)),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // Apply button (fixed at bottom)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _categoryFilter = tempCat;
                          _filterFreeOnly = tempFree;
                          _deadlineFilter = tempDeadline;
                          _filterHasVacancies = tempHasVacancies;
                          _filterNewOnly = tempNewOnly;
                          _stateFilter = tempState;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, String? value, String? selected, void Function(String?) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildNoResults() {
    final filtersActive = _hasActiveFilter && _results.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Text('🔍', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Koi job nahi mila 🔍',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              filtersActive
                  ? 'Filters ki wajah se koi result nahi'
                  : 'Dusra keyword try karo — e.g. "railway", "clerk", "constable"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            if (filtersActive)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _categoryFilter = null;
                    _filterFreeOnly = false;
                    _deadlineFilter = 'any';
                    _filterHasVacancies = false;
                    _filterNewOnly = false;
                    _stateFilter = null;
                  });
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Filters Clear Karo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () { _controller.clear(); _focusNode.requestFocus(); },
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Search Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
