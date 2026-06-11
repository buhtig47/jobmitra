// lib/screens/exam_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

// ── Exam data model ────────────────────────────────────────
class ExamEntry {
  final String id;
  final String name;
  final String category;    // upsc / ssc / banking / railway / state / defence
  final String emoji;
  final DateTime? notifDate;
  final DateTime? lastDate;
  final DateTime? examDate;
  final bool isTentative;
  final String? officialSite;

  const ExamEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    this.notifDate,
    this.lastDate,
    this.examDate,
    this.isTentative = false,
    this.officialSite,
  });

  String get status {
    final now = DateTime.now();
    if (examDate != null && now.isAfter(examDate!.add(const Duration(days: 1)))) {
      return 'result_awaited';
    }
    if (lastDate != null && now.isAfter(lastDate!)) {
      return 'closed';
    }
    if (notifDate != null && now.isAfter(notifDate!)) {
      return 'active';
    }
    return 'upcoming';
  }

  int? get daysToExam {
    if (examDate == null) return null;
    return examDate!.difference(DateTime.now()).inDays;
  }

  int? get daysToLastDate {
    if (lastDate == null) return null;
    return lastDate!.difference(DateTime.now()).inDays;
  }
}

// ── 2025-26 exam data ───────────────────────────────────────
final _allExams = <ExamEntry>[
  // ── UPSC ──
  ExamEntry(
    id: 'upsc_cse_2026',
    name: 'UPSC Civil Services 2026',
    category: 'upsc', emoji: '🏛️',
    notifDate: DateTime(2026, 1, 22),
    lastDate:  DateTime(2026, 3, 11),
    examDate:  DateTime(2026, 5, 24),
    isTentative: true,
    officialSite: 'upsc.gov.in',
  ),
  ExamEntry(
    id: 'upsc_cds2_2026',
    name: 'UPSC CDS II 2026',
    category: 'upsc', emoji: '🏛️',
    notifDate: DateTime(2026, 5, 28),
    lastDate:  DateTime(2026, 6, 17),
    examDate:  DateTime(2026, 9, 13),
    isTentative: true,
    officialSite: 'upsc.gov.in',
  ),
  ExamEntry(
    id: 'upsc_capf_2026',
    name: 'UPSC CAPF AC 2026',
    category: 'upsc', emoji: '🏛️',
    notifDate: DateTime(2026, 4, 22),
    lastDate:  DateTime(2026, 5, 13),
    examDate:  DateTime(2026, 8, 2),
    isTentative: true,
    officialSite: 'upsc.gov.in',
  ),

  // ── SSC ──
  ExamEntry(
    id: 'ssc_cgl_2025',
    name: 'SSC CGL 2025 (Tier II)',
    category: 'ssc', emoji: '📋',
    examDate: DateTime(2026, 1, 18),
    isTentative: false,
    officialSite: 'ssc.gov.in',
  ),
  ExamEntry(
    id: 'ssc_chsl_2026',
    name: 'SSC CHSL 2026',
    category: 'ssc', emoji: '📋',
    notifDate: DateTime(2026, 5, 1),
    lastDate:  DateTime(2026, 5, 31),
    examDate:  DateTime(2026, 7, 20),
    isTentative: true,
    officialSite: 'ssc.gov.in',
  ),
  ExamEntry(
    id: 'ssc_cgl_2026',
    name: 'SSC CGL 2026',
    category: 'ssc', emoji: '📋',
    notifDate: DateTime(2026, 6, 15),
    lastDate:  DateTime(2026, 7, 15),
    examDate:  DateTime(2026, 9, 10),
    isTentative: true,
    officialSite: 'ssc.gov.in',
  ),
  ExamEntry(
    id: 'ssc_mts_2026',
    name: 'SSC MTS 2026',
    category: 'ssc', emoji: '📋',
    notifDate: DateTime(2026, 7, 1),
    lastDate:  DateTime(2026, 7, 31),
    examDate:  DateTime(2026, 10, 1),
    isTentative: true,
    officialSite: 'ssc.gov.in',
  ),

  // ── Banking ──
  ExamEntry(
    id: 'sbi_po_2026',
    name: 'SBI PO 2026',
    category: 'banking', emoji: '🏦',
    notifDate: DateTime(2026, 4, 1),
    lastDate:  DateTime(2026, 4, 25),
    examDate:  DateTime(2026, 6, 14),
    isTentative: true,
    officialSite: 'sbi.co.in',
  ),
  ExamEntry(
    id: 'ibps_po_2026',
    name: 'IBPS PO 2026',
    category: 'banking', emoji: '🏦',
    notifDate: DateTime(2026, 7, 28),
    lastDate:  DateTime(2026, 8, 18),
    examDate:  DateTime(2026, 10, 3),
    isTentative: true,
    officialSite: 'ibps.in',
  ),
  ExamEntry(
    id: 'ibps_clerk_2026',
    name: 'IBPS Clerk 2026',
    category: 'banking', emoji: '🏦',
    notifDate: DateTime(2026, 8, 1),
    lastDate:  DateTime(2026, 8, 21),
    examDate:  DateTime(2026, 11, 28),
    isTentative: true,
    officialSite: 'ibps.in',
  ),
  ExamEntry(
    id: 'rbi_grade_b_2026',
    name: 'RBI Grade B 2026',
    category: 'banking', emoji: '🏦',
    notifDate: DateTime(2026, 5, 15),
    lastDate:  DateTime(2026, 6, 5),
    examDate:  DateTime(2026, 7, 19),
    isTentative: true,
    officialSite: 'rbi.org.in',
  ),

  // ── Railway ──
  ExamEntry(
    id: 'rrb_ntpc_2025',
    name: 'RRB NTPC 2025 (Result)',
    category: 'railway', emoji: '🚂',
    examDate: DateTime(2025, 9, 15),
    isTentative: false,
    officialSite: 'indianrailways.gov.in',
  ),
  ExamEntry(
    id: 'rrb_group_d_2026',
    name: 'RRB Group D 2026',
    category: 'railway', emoji: '🚂',
    notifDate: DateTime(2026, 6, 1),
    lastDate:  DateTime(2026, 7, 1),
    examDate:  DateTime(2026, 9, 15),
    isTentative: true,
    officialSite: 'indianrailways.gov.in',
  ),
  ExamEntry(
    id: 'rrb_alp_2026',
    name: 'RRB ALP / Technician 2026',
    category: 'railway', emoji: '🚂',
    notifDate: DateTime(2026, 5, 1),
    lastDate:  DateTime(2026, 6, 1),
    examDate:  DateTime(2026, 8, 10),
    isTentative: true,
    officialSite: 'indianrailways.gov.in',
  ),

  // ── Defence ──
  ExamEntry(
    id: 'nda1_2026',
    name: 'NDA & NA I 2026',
    category: 'defence', emoji: '⭐',
    notifDate: DateTime(2026, 1, 14),
    lastDate:  DateTime(2026, 2, 3),
    examDate:  DateTime(2026, 4, 12),
    isTentative: false,
    officialSite: 'upsc.gov.in',
  ),
  ExamEntry(
    id: 'agniveer_2026',
    name: 'Agniveer Army 2026',
    category: 'defence', emoji: '⭐',
    notifDate: DateTime(2026, 2, 1),
    lastDate:  DateTime(2026, 3, 1),
    examDate:  DateTime(2026, 5, 1),
    isTentative: true,
    officialSite: 'joinindianarmy.nic.in',
  ),

  // ── State PSC ──
  ExamEntry(
    id: 'bpsc_70th',
    name: 'BPSC 70th CCE',
    category: 'state', emoji: '📜',
    examDate: DateTime(2025, 12, 13),
    isTentative: false,
    officialSite: 'bpsc.bih.nic.in',
  ),
  ExamEntry(
    id: 'uppsc_pre_2026',
    name: 'UPPSC PCS Pre 2026',
    category: 'state', emoji: '📜',
    notifDate: DateTime(2026, 3, 1),
    lastDate:  DateTime(2026, 4, 15),
    examDate:  DateTime(2026, 7, 20),
    isTentative: true,
    officialSite: 'uppsc.up.nic.in',
  ),
  ExamEntry(
    id: 'rpsc_ras_2026',
    name: 'RPSC RAS 2026',
    category: 'state', emoji: '📜',
    notifDate: DateTime(2026, 4, 1),
    lastDate:  DateTime(2026, 5, 1),
    examDate:  DateTime(2026, 10, 18),
    isTentative: true,
    officialSite: 'rpsc.rajasthan.gov.in',
  ),
];

// ── Screen ──────────────────────────────────────────────────
class ExamCalendarScreen extends StatefulWidget {
  final ApiService? api;
  const ExamCalendarScreen({super.key, this.api});
  @override
  State<ExamCalendarScreen> createState() => _ExamCalendarScreenState();
}

ExamEntry? _parseApiEntry(Map<String, dynamic> e) {
  try {
    DateTime? dt(String? s) => (s != null && s.isNotEmpty) ? DateTime.tryParse(s) : null;
    return ExamEntry(
      id:           e['id'] as String,
      name:         e['name'] as String,
      category:     e['category'] as String? ?? 'other',
      emoji:        e['emoji'] as String? ?? '📅',
      notifDate:    dt(e['notif_date'] as String?),
      lastDate:     dt(e['last_date'] as String?),
      examDate:     dt(e['exam_date'] as String?),
      isTentative:  (e['is_tentative'] as bool?) ?? false,
      officialSite: e['official_site'] as String?,
    );
  } catch (_) {
    return null;
  }
}

class _ExamCalendarScreenState extends State<ExamCalendarScreen> {
  String _filter = 'all';
  List<ExamEntry> _exams = _allExams;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  Future<void> _loadFromBackend() async {
    if (widget.api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final raw = await widget.api!.getExamCalendar();
      if (raw.isNotEmpty) {
        final parsed = raw.map(_parseApiEntry).whereType<ExamEntry>().toList();
        if (parsed.isNotEmpty && mounted) {
          setState(() { _exams = parsed; _loading = false; });
          return;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Internet check karo ya baad mein try karo'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () { setState(() => _loading = true); _loadFromBackend(); },
            ),
          ),
        );
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  static const _filters = [
    ('all',     'All',     '🗓️'),
    ('upsc',    'UPSC',    '🏛️'),
    ('ssc',     'SSC',     '📋'),
    ('banking', 'Banking', '🏦'),
    ('railway', 'Railway', '🚂'),
    ('defence', 'Defence', '⭐'),
    ('state',   'State',   '📜'),
  ];

  List<ExamEntry> get _filtered =>
      _filter == 'all' ? _exams : _exams.where((e) => e.category == _filter).toList();

  static const _statusColors = {
    'active':          Color(0xFF2E7D32),
    'upcoming':        Color(0xFF1565C0),
    'closed':          Color(0xFFB71C1C),
    'result_awaited':  Color(0xFFE65100),
  };
  static const _statusLabels = {
    'active':         'Forms Open',
    'upcoming':       'Coming Soon',
    'closed':         'Closed / Exam Pending',
    'result_awaited': 'Result Awaited',
  };
  static const _statusEmoji = {
    'active':         '🟢',
    'upcoming':       '🔵',
    'closed':         '🔴',
    'result_awaited': '🟡',
  };

  @override
  Widget build(BuildContext context) {
    final exams = _filtered;
    final isLive = _exams != _allExams;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Exam Calendar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(
                          isLive ? 'Live data from server' : '2025-26 upcoming exams',
                          style: TextStyle(color: isLive ? const Color(0xFF81C784) : Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Filter chips ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final (key, label, emoji) = f;
                  final sel = _filter == key;
                  return GestureDetector(
                    onTap: () { HapticFeedback.lightImpact(); setState(() => _filter = key); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: sel ? null : Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        '$emoji $label',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Exam list ──
          Expanded(
            child: _loading
                ? _buildShimmer()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () { setState(() => _loading = true); return _loadFromBackend(); },
                    child: exams.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text('Koi exam nahi mila',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text('Filter change karke dekho',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: exams.length,
                            itemBuilder: (ctx, i) => _buildCard(exams[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ExamEntry e) {
    final status   = e.status;
    final color    = _statusColors[status]!;
    final dtExam   = e.daysToExam;
    final dtLast   = e.daysToLastDate;

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); _showExamDetail(e); },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored top bar
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(e.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      // Status badge + countdown badge stacked
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_statusEmoji[status]} ${_statusLabels[status]}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                            ),
                          ),
                          if (dtExam != null && dtExam >= 0 && status != 'result_awaited') ...[
                            const SizedBox(height: 4),
                            _countdownBadge(dtExam),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (e.isTentative)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 30),
                      child: Text('(Tentative dates)', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 12),

                  // Date rows
                  if (e.notifDate != null) _dateRow('📢 Notification', e.notifDate!, null),
                  if (e.lastDate != null)
                    _dateRow('📝 Last Date', e.lastDate!, status == 'active' && dtLast != null && dtLast >= 0
                        ? '$dtLast din bacha!' : null, highlight: status == 'active'),
                  if (e.examDate != null)
                    _dateRow('📅 Exam Date', e.examDate!, dtExam != null && dtExam > 0
                        ? '$dtExam din mein' : dtExam == 0 ? 'AAJ!' : null,
                        highlight: status == 'closed'),

                  // Countdown bar
                  if (dtExam != null && dtExam > 0 && dtExam <= 90) ...[
                    const SizedBox(height: 10),
                    _countdownBar(dtExam, 90, color),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),  // Container
  );    // GestureDetector
  }

  Widget _dateRow(String label, DateTime date, String? badge, {bool highlight = false}) {
    final formatted = '${date.day.toString().padLeft(2, '0')} '
        '${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month]} '
        '${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(formatted, style: TextStyle(fontSize: 12, fontWeight: highlight ? FontWeight.w700 : FontWeight.w600, color: highlight ? AppColors.primary : AppColors.textPrimary)),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _countdownBar(int days, int max, Color color) {
    final pct = 1.0 - (days / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Exam countdown', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            Text('$days days left', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // M16 — color-coded countdown pill badge
  Widget _countdownBadge(int days) {
    final Color color;
    final String text;
    if (days == 0) {
      color = const Color(0xFFB71C1C);
      text = 'AAJ Exam!';
    } else if (days <= 30) {
      color = const Color(0xFFB71C1C);
      text = '$days days left';
    } else if (days <= 60) {
      color = const Color(0xFFE65100);
      text = '$days days left';
    } else {
      color = const Color(0xFF2E7D32);
      text = '$days days left';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text('⏰ $text',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // M4 — shimmer skeleton while loading
  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // M15 — tap card → bottom sheet with full timeline + "View Site" CTA
  void _showExamDetail(ExamEntry e) {
    final status  = e.status;
    final color   = _statusColors[status]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Text(e.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_statusEmoji[status]} ${_statusLabels[status]}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Timeline
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IMPORTANT DATES',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 0.8, color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      _timelineItem('📢', 'Notification', e.notifDate, color, isFirst: true),
                      _timelineItem('📝', 'Last Date to Apply', e.lastDate, color),
                      _timelineItem('📅', 'Exam Date', e.examDate, color),
                      _timelineItem('🏆', 'Result', null, color, isLast: true,
                          label2: 'To be announced'),
                      if (e.isTentative) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Text('Dates are tentative', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // CTA
              if (e.officialSite != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('https://${e.officialSite}');
                        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text('Visit ${e.officialSite}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineItem(String emoji, String label, DateTime? date, Color accent,
      {bool isFirst = false, bool isLast = false, String? label2}) {
    final fmtDate = date == null
        ? (label2 ?? 'TBA')
        : '${date.day.toString().padLeft(2, '0')} '
            '${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month]} '
            '${date.year}';
    final isPast = date != null && DateTime.now().isAfter(date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isPast
                        ? accent.withValues(alpha: 0.12)
                        : (date == null ? Colors.grey[100] : AppColors.primary.withValues(alpha: 0.1)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPast ? accent : (date == null ? Colors.grey[300]! : AppColors.primary.withValues(alpha: 0.4)),
                      width: 1.5,
                    ),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[200],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPast ? accent : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(fmtDate,
                    style: TextStyle(
                        fontSize: 12,
                        color: date == null ? Colors.grey[400] : AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
