// lib/screens/announcements_screen.dart
//
// Admit Cards / Results / Answer Keys / Cut-offs / Syllabus / Exam Dates.
// Discovery + deep-link to official portal — we never host the artefact itself.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class AnnouncementsScreen extends StatefulWidget {
  final ApiService api;
  const AnnouncementsScreen({super.key, required this.api});

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _specs.length, vsync: this);
    _tabs.addListener(_onTab);
    _fetchCounts();
    _loadTab(_specs.first.type);
  }

  @override
  void dispose() {
    _tabs.dispose();
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

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final items = _data[spec.type] ?? const <Announcement>[];

    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: spec.color),
      );
    }

    if (items.isEmpty) {
      return _buildEmpty(spec);
    }

    return RefreshIndicator(
      color: spec.color,
      onRefresh: () => _loadTab(spec.type),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i], spec),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: spec.color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(a.sourceUrl),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      a.organisation.isNotEmpty ? a.organisation : a.source,
                      style: TextStyle(
                          color: spec.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.open_in_new_rounded,
                      size: 14, color: spec.color),
                  const SizedBox(width: 6),
                  Text(
                    'Official portal pe download karo',
                    style: TextStyle(
                        color: spec.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
