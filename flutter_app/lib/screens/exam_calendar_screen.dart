// lib/screens/exam_calendar_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

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
  const ExamCalendarScreen({super.key});
  @override
  State<ExamCalendarScreen> createState() => _ExamCalendarScreenState();
}

class _ExamCalendarScreenState extends State<ExamCalendarScreen> {
  String _filter = 'all';

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
      _filter == 'all' ? _allExams : _allExams.where((e) => e.category == _filter).toList();

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
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Exam Calendar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('2025-26 upcoming exams', style: TextStyle(color: Colors.white70, fontSize: 11)),
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
                    onTap: () => setState(() => _filter = key),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exams.length,
              itemBuilder: (ctx, i) => _buildCard(exams[i]),
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

    return Container(
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
                      // Status badge
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
    );
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
              child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
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
}
