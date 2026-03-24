// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
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
  bool _isSearching  = false;
  int? _userId;
  String _userCategory = 'general';
  List<String> _recentSearches = [];
  String? _lastQuery;

  List<Job> get _filteredResults => _categoryFilter == null
      ? _results
      : _results.where((j) => j.category == _categoryFilter).toList();

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
    widget.api.getSavedUserId().then((id) => setState(() => _userId = id));
    widget.api.getSavedProfile().then((p) { if (p != null) setState(() => _userCategory = p.category); });
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
    if (q.length < 2) return;
    _controller.text = q;
    _focusNode.unfocus();
    await _saveRecentSearch(q);
    setState(() { _isSearching = true; _lastQuery = q; _categoryFilter = null; });
    final results = await widget.api.searchJobs(q, userCategory: _userCategory);
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
                        '${_results.length} results',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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
                    ? '${_results.length} naukri mili "$_lastQuery" ke liye'
                    : 'Apni pasand ki sarkari naukri dhundo',
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
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              '"$_lastQuery" search ho raha hai...',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_lastQuery == null) return _buildDiscovery();
    if (_results.isEmpty) return _buildNoResults();
    return _buildResults();
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
                        child: Text(
                          '$emoji $count',
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
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _filteredResults.length,
            itemBuilder: (ctx, i) => JobCard(
              job: _filteredResults[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobDetailScreen(
                    jobId: _filteredResults[i].id,
                    api: widget.api,
                    userId: _userId ?? 0,
                  ),
                ),
              ),
            ),
          ),
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

          // ── Recent searches ──
          if (_recentSearches.isNotEmpty) ...[
            const SizedBox(height: 28),
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
              'Long press karo recent search hatane ke liye',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
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

  Widget _buildNoResults() {
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
            Text(
              '"$_lastQuery" ke liye koi job nahi mili',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Alag keyword try karo — jaise "railway", "clerk", "constable"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () { _controller.clear(); _focusNode.requestFocus(); },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Nayi Search Karo'),
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
