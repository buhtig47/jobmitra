// lib/screens/announcements_screen.dart
//
// Admit Cards / Results / Answer Keys / Cut-offs / Syllabus / Exam Dates.
// Discovery + deep-link to official portal — we never host the artefact itself.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/banner_ad_widget.dart';

class AnnouncementsScreen extends StatefulWidget {
  final ApiService api;
  // When set (e.g. 'result', 'admit_card'), opens directly on that tab —
  // used by the home-screen quick-access shortcuts.
  final String? initialType;
  const AnnouncementsScreen({super.key, required this.api, this.initialType});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final List<_TabSpec> _specs = const [
    _TabSpec('admit_card', 'Admit Cards', '🎟️', Color(0xFFE65100)),
    _TabSpec('result',     'Results',     '📊', Color(0xFF1A6B3C)),
    _TabSpec('answer_key', 'Answer Keys', '🔑', Color(0xFF6A1B9A)),
    _TabSpec('cutoff',     'Cut-offs',    '✂️', Color(0xFFC62828)),
    _TabSpec('syllabus',   'Syllabus',    '📚', Color(0xFF1565C0)),
    _TabSpec('exam_date',  'Exam Dates',  '📅', Color(0xFF00838F)),
  ];

  final Map<String, List<Announcement>> _data = {};
  final Map<String, bool> _loading = {};
  Map<String, int> _counts = {};

  Set<int> _readIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final initialIdx = widget.initialType == null
        ? 0
        : _specs.indexWhere((s) => s.type == widget.initialType).clamp(0, _specs.length - 1);
    _tabs = TabController(
        length: _specs.length, vsync: this, initialIndex: initialIdx);
    _tabs.addListener(_onTab);
    _fetchCounts();
    _loadTab(_specs[initialIdx].type);
    _loadReadIds();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    final spec = _specs[_tabs.index];
    if (!_data.containsKey(spec.type)) _loadTab(spec.type);
  }

  Future<void> _fetchCounts() async {
    final c = await widget.api.getAnnouncementCounts();
    if (mounted) setState(() => _counts = c);
  }

  Future<void> _loadTab(String type) async {
    setState(() => _loading[type] = true);
    final data = await widget.api.getAnnouncements(type: type, limit: 100);
    if (!mounted) return;
    setState(() {
      _data[type] = data;
      _loading[type] = false;
    });
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('read_notification_ids') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<int>();
    if (mounted) setState(() => _readIds = list.toSet());
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onCardTap(Announcement a) async {
    _open(a.sourceUrl);
    if (_readIds.contains(a.id)) return;
    setState(() => _readIds.add(a.id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'read_notification_ids', jsonEncode(_readIds.toList()));
  }

  String _relativeTime(String isoDate) {
    if (isoDate.isEmpty) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Notifications Hub',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _specs.map((s) {
            final n = _counts[s.type] ?? 0;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${s.emoji} ${s.label}'),
                  if (n > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$n',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _specs.map((s) => _buildTab(s)).toList(),
      ),
    );
  }

  Widget _buildTab(_TabSpec spec) {
    final loading = _loading[spec.type] ?? true;
    final allItems = _data[spec.type] ?? const <Announcement>[];

    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: spec.color),
      );
    }

    if (allItems.isEmpty) {
      return _buildEmpty(spec);
    }

    final items = _searchQuery.isEmpty
        ? allItems
        : allItems
            .where((a) =>
                a.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return RefreshIndicator(
      color: spec.color,
      onRefresh: () => _loadTab(spec.type),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Exam ya subject search karo...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.grey),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                constraints: const BoxConstraints(maxHeight: 40),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Koi result nahi mila 🔍',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    // Inline banner after every 6 cards (same cadence
                    // pattern as the home feed's every-5th slot).
                    itemCount: items.length + items.length ~/ 6,
                    itemBuilder: (_, i) {
                      if ((i + 1) % 7 == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: BannerAdWidget(),
                        );
                      }
                      final dataIndex = i - (i + 1) ~/ 7;
                      return _buildCard(items[dataIndex], spec);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(_TabSpec spec) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(spec.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              'Koi ${spec.label} abhi nahi',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Scraper roz check karta hai. Naye release pe push notification milegi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Announcement a, _TabSpec spec) {
    final timeStr = _relativeTime(a.scrapedAt);
    final isUnread = !_readIds.contains(a.id);

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: spec.color.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: spec.color),
                  Expanded(
                    child: InkWell(
                      onTap: () => _onCardTap(a),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 120),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    a.organisation.isNotEmpty
                                        ? a.organisation
                                        : a.source,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1A6B3C),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (a.releaseDate.isNotEmpty)
                                  Text(
                                    a.releaseDate.length >= 10
                                        ? a.releaseDate.substring(0, 10)
                                        : a.releaseDate,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a.title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.3),
                            ),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                timeStr,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                            if (a.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                a.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.35),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                Icons.open_in_new,
                                size: 18,
                                color: Color(0xFF1A6B3C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isUnread)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _TabSpec {
  final String type;
  final String label;
  final String emoji;
  final Color  color;
  const _TabSpec(this.type, this.label, this.emoji, this.color);
}
