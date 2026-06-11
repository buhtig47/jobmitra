// lib/screens/tools_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'salary_calculator_screen.dart';
import 'exam_calendar_screen.dart';
import 'competition_screen.dart';
import 'career_roadmap_screen.dart';
import 'dept_profiles_screen.dart';
import 'current_affairs_screen.dart';
import 'mock_test_screen.dart';
import 'age_calculator_screen.dart';
import 'daily_quiz_screen.dart';
import 'announcements_screen.dart';

class ToolsScreen extends StatefulWidget {
  final ApiService api;
  const ToolsScreen({super.key, required this.api});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

// Pin + Recent persistence keys. Bump _kPrefsVersion if the tool ID set ever
// breaks compat (e.g. an ID is renamed) so stale prefs flush cleanly.
const _kPinnedKey       = 'tools_pinned_ids_v1';
const _kRecentKey       = 'tools_recent_ids_v1';
const _kBookmarksData   = 'quiz_bookmarks_data_v1';
const _kRecentMax       = 3;

class _ToolsScreenState extends State<ToolsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  Set<String> _pinned = {};
  List<String> _recent = [];
  Map<String, int> _annCounts = {};
  List<Map<String, dynamic>> _bookmarked = [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAnnouncementCounts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkedRaw = prefs.getStringList(_kBookmarksData) ?? const <String>[];
    final parsed = <Map<String, dynamic>>[];
    for (final s in bookmarkedRaw) {
      try { parsed.add(Map<String, dynamic>.from(jsonDecode(s) as Map)); } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _pinned    = (prefs.getStringList(_kPinnedKey) ?? const <String>[]).toSet();
      _recent    = prefs.getStringList(_kRecentKey) ?? const <String>[];
      _bookmarked = parsed;
    });
  }

  Future<void> _loadAnnouncementCounts() async {
    final counts = await widget.api.getAnnouncementCounts();
    if (!mounted) return;
    setState(() => _annCounts = counts);
  }

  Future<void> _togglePin(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final next = Set<String>.from(_pinned);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    await prefs.setStringList(_kPinnedKey, next.toList());
    if (!mounted) return;
    setState(() => _pinned = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(next.contains(id) ? 'Pinned' : 'Unpinned',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _markRecent(String id) async {
    final next = <String>[id, ..._recent.where((x) => x != id)];
    if (next.length > _kRecentMax) next.removeRange(_kRecentMax, next.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentKey, next);
    if (!mounted) return;
    setState(() => _recent = next);
  }

  void _open(_ToolDef def) {
    _markRecent(def.id);
    // 'invite' is an action tile, not a screen — fires the share sheet.
    if (def.id == 'invite') {
      _shareApp();
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => def.builder(widget.api)));
  }

  Future<void> _shareApp() async {
    const msg = '🇮🇳 *JobMitra* — Sarkari Naukri ka smart app!\n\n'
        '✅ Sirf eligible jobs (profile-based filter)\n'
        '✅ Admit Card / Result / Answer Key alerts\n'
        '✅ Daily GK Quiz + Mock Tests — FREE\n'
        '✅ Deadline reminders — koi form miss nahi\n\n'
        'Download (FREE): $kPlayStoreUrl';
    await Share.share(msg);
  }

  // ── Source of truth for every tile. Add a new tool here and it shows up
  // in search, pin, and recents automatically.
  List<_ToolDef> get _allTools => [
        _ToolDef(
          id: 'salary',
          emoji: '💰',
          title: 'Salary Calculator',
          subtitle: '7th CPC in-hand salary — levels 1–18, tax, DA, 5-yr growth',
          section: 'Finance',
          color: const Color(0xFF2E7D32),
          builder: (_) => const SalaryCalculatorScreen(),
        ),
        _ToolDef(
          id: 'age',
          emoji: '🎂',
          title: 'Age Eligibility Calculator',
          subtitle: 'Check if you qualify — UPSC, SSC, RRB, Banking by category',
          section: 'Finance',
          color: const Color(0xFF6A1B9A),
          builder: (_) => const AgeCalculatorScreen(),
        ),
        _ToolDef(
          id: 'quiz',
          emoji: '🧠',
          title: 'Daily GK Quiz',
          subtitle: '5 questions every day — streak, score, 60-day rotation',
          section: 'Practice',
          color: const Color(0xFF4A148C),
          tag: 'Daily',
          builder: (api) => DailyQuizScreen(api: api),
        ),
        _ToolDef(
          id: 'mock',
          emoji: '📝',
          title: 'Mock Tests',
          subtitle: 'SSC, RRB, Banking, UPSC — 185 PYQ-based questions',
          section: 'Practice',
          color: const Color(0xFF1565C0),
          builder: (api) => MockTestScreen(api: api),
        ),
        _ToolDef(
          id: 'ca',
          emoji: '📰',
          title: 'Daily Current Affairs',
          subtitle: 'Auto-updated twice daily — polity, economy, science',
          section: 'Practice',
          color: const Color(0xFFE65100),
          builder: (api) => CurrentAffairsScreen(api: api),
        ),
        _ToolDef(
          id: 'ann',
          emoji: '🎟️',
          title: 'Admit Cards & Results',
          subtitle: 'Admit cards, results, answer keys, cut-offs — all exams',
          section: 'Practice',
          color: const Color(0xFFC62828),
          badge: () => _annTotal,
          builder: (api) => AnnouncementsScreen(api: api),
        ),
        _ToolDef(
          id: 'cal',
          emoji: '🗓️',
          title: 'Exam Calendar',
          subtitle: 'UPSC, SSC, Banking, Railway — 2025-26 important dates',
          section: 'Planning',
          color: const Color(0xFF1565C0),
          builder: (api) => ExamCalendarScreen(api: api),
        ),
        _ToolDef(
          id: 'compete',
          emoji: '⚔️',
          title: 'Competition Analysis',
          subtitle: 'How many candidates per post? See your real odds',
          section: 'Analysis',
          color: const Color(0xFFB71C1C),
          builder: (_) => const CompetitionScreen(),
        ),
        _ToolDef(
          id: 'roadmap',
          emoji: '🗺️',
          title: 'Career Roadmap',
          subtitle: 'Best exam path based on your age & qualification',
          section: 'Analysis',
          color: const Color(0xFF4A148C),
          builder: (api) => CareerRoadmapScreen(api: api),
        ),
        _ToolDef(
          id: 'dept',
          emoji: '🏢',
          title: 'Department Profiles',
          subtitle: 'DRDO, ISRO, Railways, Banks — salary & perks',
          section: 'Analysis',
          color: const Color(0xFF1A237E),
          builder: (api) => DeptProfilesScreen(api: api),
        ),
        _ToolDef(
          id: 'invite',
          emoji: '🤝',
          title: 'Dosto ko Bhejo',
          subtitle: 'WhatsApp pe JobMitra share karo — taiyari saath karo',
          section: 'Share',
          color: const Color(0xFFFF9933),
          builder: (_) => const SizedBox.shrink(), // action tile — see _open
        ),
      ];

  int get _annTotal =>
      _annCounts.values.fold<int>(0, (sum, n) => sum + n);

  bool _matchesQuery(_ToolDef t) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return t.title.toLowerCase().contains(q) ||
        t.subtitle.toLowerCase().contains(q) ||
        t.section.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final tools = _allTools;
    final byId = {for (final t in tools) t.id: t};
    final filtered = tools.where(_matchesQuery).toList();

    final pinnedTiles = _pinned
        .map((id) => byId[id])
        .whereType<_ToolDef>()
        .where(_matchesQuery)
        .toList();
    final recentTiles = _recent
        .map((id) => byId[id])
        .whereType<_ToolDef>()
        .where((t) => !_pinned.contains(t.id))
        .where(_matchesQuery)
        .toList();

    // Group remainder by section, dropping anything already in pinned/recent.
    final shown = {...pinnedTiles.map((t) => t.id), ...recentTiles.map((t) => t.id)};
    final remaining = filtered.where((t) => !shown.contains(t.id)).toList();
    final bySection = <String, List<_ToolDef>>{};
    for (final t in remaining) {
      bySection.putIfAbsent(t.section, () => <_ToolDef>[]).add(t);
    }
    const sectionOrder = ['Finance', 'Practice', 'Planning', 'Analysis', 'Share'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header + search ──
          SliverToBoxAdapter(
            child: Container(
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🛠️ Tools',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Long-press to pin • Tap to use',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                      const SizedBox(height: 14),
                      // Search field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search tools — quiz, salary, calendar…',
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (pinnedTiles.isEmpty && recentTiles.isEmpty && remaining.isEmpty)
                  _buildEmptyState(),
                if (_bookmarked.isNotEmpty && _query.isEmpty) ...[
                  _buildSectionLabel('🔖 Saved Questions'),
                  const SizedBox(height: 10),
                  _buildBookmarksCard(),
                  const SizedBox(height: 12),
                ],
                if (pinnedTiles.isNotEmpty) ...[
                  _buildSectionLabel('📌 Pinned'),
                  const SizedBox(height: 10),
                  for (final t in pinnedTiles) ...[
                    _buildTile(t, isPinned: true),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                ],
                if (recentTiles.isNotEmpty) ...[
                  _buildSectionLabel('🕒 Recently Used'),
                  const SizedBox(height: 10),
                  for (final t in recentTiles) ...[
                    _buildTile(t, isPinned: false),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                ],
                for (final s in sectionOrder)
                  if ((bySection[s] ?? const []).isNotEmpty) ...[
                    _buildSectionLabel('${_sectionEmoji(s)} $s'),
                    const SizedBox(height: 10),
                    for (final t in bySection[s]!) ...[
                      _buildTile(t, isPinned: false),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _sectionEmoji(String section) => switch (section) {
        'Finance'  => '💰',
        'Practice' => '📚',
        'Planning' => '📅',
        'Analysis' => '📊',
        'Share'    => '🤝',
        _          => '🔧',
      };

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('"$_query" se koi tool match nahi hua',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 6),
          Text('Try: salary, quiz, calendar, exam',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSecondary));
  }

  Widget _buildTile(_ToolDef t, {required bool isPinned}) {
    return _ToolCard(
      def: t,
      isPinned: isPinned,
      badgeCount: t.badge?.call(),
      onTap: () => _open(t),
      onLongPress: () => _togglePin(t.id),
    );
  }

  Widget _buildBookmarksCard() {
    final count = _bookmarked.length;
    return GestureDetector(
      onTap: _showBookmarksSheet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('🔖', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bookmarked Questions',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('$count saved question${count == 1 ? '' : 's'} — tap to review',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    const Text('🔖', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Bookmarked Questions',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    Text('${_bookmarked.length} saved',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarked.length,
                  itemBuilder: (_, i) {
                    final b = _bookmarked[i];
                    final opts = (b['opts'] as List?)?.cast<String>() ?? [];
                    final ans  = (b['ans'] as int?) ?? 0;
                    final exp  = (b['exp'] as String?) ?? '';
                    final src  = (b['src'] as String?) ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: src == 'daily'
                                      ? const Color(0xFF4A148C).withValues(alpha: 0.1)
                                      : const Color(0xFF1565C0).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(src == 'daily' ? 'Daily Quiz' : 'Mock Test',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: src == 'daily' ? const Color(0xFF4A148C) : const Color(0xFF1565C0))),
                              ),
                              const SizedBox(width: 6),
                              Text('Q${i + 1}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(b['q']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                          const SizedBox(height: 10),
                          ...List.generate(opts.length, (j) {
                            final correct = j == ans;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: correct
                                    ? const Color(0xFF2E7D32).withValues(alpha: 0.10)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: correct ? const Color(0xFF2E7D32).withValues(alpha: 0.5) : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(String.fromCharCode(65 + j),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: correct ? const Color(0xFF2E7D32) : Colors.grey[500])),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(opts[j],
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: correct ? FontWeight.w600 : FontWeight.w400,
                                            color: correct ? const Color(0xFF1B5E20) : AppColors.textPrimary)),
                                  ),
                                  if (correct) const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
                                ],
                              ),
                            );
                          }),
                          if (exp.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💡 ', style: TextStyle(fontSize: 13)),
                                  Expanded(child: Text(exp,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolDef {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final String section;
  final Color  color;
  final String? tag;
  final int Function()? badge;
  final Widget Function(ApiService api) builder;

  const _ToolDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.color,
    required this.builder,
    this.tag,
    this.badge,
  });
}

class _ToolCard extends StatelessWidget {
  final _ToolDef def;
  final bool     isPinned;
  final int?     badgeCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ToolCard({
    required this.def,
    required this.isPinned,
    required this.badgeCount,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount != null && badgeCount! > 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: def.color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: def.color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              Container(width: 6, height: 80, color: def.color),
              const SizedBox(width: 16),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: def.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(def.emoji, style: const TextStyle(fontSize: 26))),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          shape: badgeCount! > 9 ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: badgeCount! > 9 ? BorderRadius.circular(10) : null,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            badgeCount! > 99 ? '99+' : badgeCount!.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(def.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                          ),
                          if (def.tag != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                              child: Text(def.tag!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ],
                          if (isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.push_pin, size: 12, color: AppColors.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(def.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.chevron_right_rounded, color: def.color.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
