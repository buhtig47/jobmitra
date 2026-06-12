// lib/screens/current_affairs_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/banner_ad_widget.dart';

class CurrentAffairsScreen extends StatefulWidget {
  final ApiService api;
  const CurrentAffairsScreen({super.key, required this.api});

  @override
  State<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

// Maps each backend category to the govt exams whose syllabus normally covers
// it. Used to render the "useful for: …" relevance chips on each article so
// users can scan which articles are worth reading for *their* exam.
const _examRelevance = <String, List<String>>{
  'national':      ['SSC', 'UPSC', 'Banking', 'Railway'],
  'international': ['UPSC', 'SSC'],
  'economy':       ['Banking', 'UPSC', 'SSC'],
  'science':       ['SSC', 'UPSC', 'Railway'],
  'sports':        ['SSC', 'Railway'],
  'awards':        ['SSC', 'UPSC', 'Banking'],
  'appointments':  ['UPSC', 'Banking'],
  'misc':          ['SSC'],
};

const _kBookmarksKey = 'ca_bookmarks_v1';

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen> {
  List<CurrentAffair> _all   = [];
  bool                _loading = true;
  String              _cat   = 'all';
  int                 _days  = 7;
  bool                _bookmarksOnly = false;
  Set<int>            _bookmarks = <int>{};

  static const _cats = [
    ('all',          'Sab',           Icons.public),
    ('national',     'National',      Icons.flag),
    ('international','International', Icons.language),
    ('economy',      'Economy',       Icons.currency_rupee),
    ('science',      'Science',       Icons.science),
    ('sports',       'Sports',        Icons.sports_cricket),
    ('awards',       'Awards',        Icons.emoji_events),
    ('appointments', 'Appointments',  Icons.person_pin),
    ('misc',         'Misc',          Icons.more_horiz),
  ];

  static const _catColors = {
    'national':      Color(0xFF1A6B3C),
    'international': Color(0xFF1565C0),
    'economy':       Color(0xFFE65100),
    'science':       Color(0xFF6A1B9A),
    'sports':        Color(0xFF00695C),
    'awards':        Color(0xFFB7950B),
    'appointments':  Color(0xFF37474F),
    'misc':          Color(0xFF757575),
    'all':           Color(0xFF1A6B3C),
  };

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _load();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kBookmarksKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _bookmarks = raw.map((s) => int.tryParse(s) ?? -1).where((i) => i > 0).toSet();
    });
  }

  Future<void> _toggleBookmark(int id) async {
    if (id <= 0) return;
    final next = Set<int>.from(_bookmarks);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBookmarksKey, next.map((i) => i.toString()).toList());
    if (!mounted) return;
    setState(() => _bookmarks = next);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<CurrentAffair> data = [];
    for (int attempt = 0; attempt < 3; attempt++) {
      data = await widget.api.getCurrentAffairs(
        category: _cat == 'all' ? null : _cat,
        days: _days,
      );
      if (data.isNotEmpty) break;
      if (attempt < 2) await Future.delayed(const Duration(seconds: 3));
    }
    if (!mounted) return;
    setState(() { _all = data; _loading = false; });
  }

  List<CurrentAffair> get _visible {
    if (!_bookmarksOnly) return _all;
    return _all.where((a) => _bookmarks.contains(a.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: _loading ? _buildShimmer() : _buildList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFBF360C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📰 Daily Current Affairs',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Tap card to read • Bookmark to revisit',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  ],
                ),
              ),
              // Bookmark filter toggle
              GestureDetector(
                onTap: () => setState(() => _bookmarksOnly = !_bookmarksOnly),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _bookmarksOnly
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Icon(
                    _bookmarksOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 18,
                    color: _bookmarksOnly ? const Color(0xFFE65100) : Colors.white,
                  ),
                ),
              ),
              _DaysChip(days: _days, onChanged: (d) { _days = d; _load(); }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _cats.map((t) {
            final (key, label, icon) = t;
            final sel = _cat == key;
            final color = _catColors[key] ?? AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: sel ? Colors.white : color),
                    const SizedBox(width: 4),
                    Text(label),
                  ],
                ),
                selected: sel,
                onSelected: (_) { setState(() => _cat = key); _load(); },
                selectedColor: color,
                backgroundColor: color.withValues(alpha: 0.08),
                labelStyle: TextStyle(
                  color: sel ? Colors.white : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: sel ? color : color.withValues(alpha: 0.3)),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList() {
    final list = _visible;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_bookmarksOnly ? '🔖' : '📭', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              _bookmarksOnly
                  ? 'No bookmarks yet\nTap the bookmark icon on any article'
                  : 'Articles update ho rahe hain,\nthodi der mein try karo',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            if (!_bookmarksOnly)
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        // Inline banner after every 6 articles
        itemCount: list.length + list.length ~/ 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if ((i + 1) % 7 == 0) {
            return const BannerAdWidget();
          }
          final a = list[i - (i + 1) ~/ 7];
          return _ArticleCard(
            article: a,
            bookmarked: _bookmarks.contains(a.id),
            onBookmark: () => _toggleBookmark(a.id),
            onTap: () => _openArticle(a.sourceUrl),
          );
        },
      ),
    );
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open article link')),
      );
    }
  }

  Widget _buildShimmer() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
              SizedBox(width: 10),
              Text('Loading articles...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, __) => Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _DaysChip extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;
  const _DaysChip({required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How many days back?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 16),
              RadioGroup<int>(
                groupValue: days,
                onChanged: (v) { Navigator.pop(context); onChanged(v!); },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [(1, 'Today'), (3, 'Last 3 days'), (7, 'Last week'), (14, 'Last 2 weeks'), (30, 'Last month')]
                      .map((t) {
                    final (d, label) = t;
                    return ListTile(
                      title: Text(label),
                      leading: Radio<int>(
                        value: d,
                        activeColor: AppColors.primary,
                      ),
                      onTap: () { Navigator.pop(context); onChanged(d); },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(days == 1 ? 'Today' : '${days}d',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const Icon(Icons.expand_more, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final CurrentAffair article;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onTap;
  const _ArticleCard({
    required this.article,
    required this.bookmarked,
    required this.onBookmark,
    required this.onTap,
  });

  static const _catColors = {
    'national':      Color(0xFF1A6B3C),
    'international': Color(0xFF1565C0),
    'economy':       Color(0xFFE65100),
    'science':       Color(0xFF6A1B9A),
    'sports':        Color(0xFF00695C),
    'awards':        Color(0xFFB7950B),
    'appointments':  Color(0xFF37474F),
    'misc':          Color(0xFF757575),
  };

  static const _catLabels = {
    'national':      'National',
    'international': 'International',
    'economy':       'Economy',
    'science':       'Science',
    'sports':        'Sports',
    'awards':        'Awards',
    'appointments':  'Appointment',
    'misc':          'General',
  };

  @override
  Widget build(BuildContext context) {
    final color = _catColors[article.category] ?? const Color(0xFF757575);
    final label = _catLabels[article.category] ?? 'General';
    final relevance = _examRelevance[article.category] ?? const <String>[];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(label,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                          ),
                          const Spacer(),
                          if (article.pubDate.isNotEmpty)
                            Text(_formatDate(article.pubDate),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onBookmark,
                            child: Icon(
                              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 18,
                              color: bookmarked ? const Color(0xFFE65100) : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(article.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.35)),
                      if (article.summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(article.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                      ],
                      // Exam relevance chips
                      if (relevance.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            const Text('Useful for:',
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            for (final exam in relevance)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(exam,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                              ),
                          ],
                        ),
                      ],
                      if (article.sourceName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.link, size: 11, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(article.sourceName,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String d) {
    try {
      final parts = d.split('-');
      if (parts.length < 3) return d;
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${parts[2]} ${months[int.parse(parts[1])]}';
    } catch (_) { return d; }
  }
}
