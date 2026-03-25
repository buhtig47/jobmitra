// lib/screens/competition_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class _Exam {
  final String name;
  final String category;
  final String emoji;
  final int    year;
  final int    vacancies;
  final int    applicants; // total applicants
  final bool   trendUp;   // competition increasing?
  final String tip;

  const _Exam({
    required this.name,
    required this.category,
    required this.emoji,
    required this.year,
    required this.vacancies,
    required this.applicants,
    this.trendUp = true,
    required this.tip,
  });

  int    get ratio     => vacancies > 0 ? (applicants ~/ vacancies) : 0;
  String get ratioText => '${_fmt(ratio)}:1';
  String get difficulty {
    if (ratio < 50)   return 'Easy';
    if (ratio < 200)  return 'Medium';
    if (ratio < 600)  return 'Hard';
    return 'Brutal';
  }
  Color get diffColor {
    if (ratio < 50)   return const Color(0xFF2E7D32);
    if (ratio < 200)  return const Color(0xFF1565C0);
    if (ratio < 600)  return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }
  String get appText {
    if (applicants >= 10000000) return '${(applicants / 10000000).toStringAsFixed(1)} Cr';
    if (applicants >= 100000)   return '${(applicants / 100000).toStringAsFixed(1)} L';
    return _fmt(applicants);
  }
  static String _fmt(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    final s = n.toString();
    if (s.length <= 3) return s;
    if (s.length <= 5) return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    return '${s.substring(0, s.length - 5)},${s.substring(s.length - 5, s.length - 3)},${s.substring(s.length - 3)}';
  }
}

const _exams = [
  // ── SSC ──
  _Exam(name: 'SSC CGL', category: 'ssc', emoji: '📋', year: 2024,
    vacancies: 17727, applicants: 3000000, trendUp: false,
    tip: 'Build strong English + Maths. Tier 2 cut-offs are predictable.'),
  _Exam(name: 'SSC CHSL', category: 'ssc', emoji: '📋', year: 2024,
    vacancies: 3712, applicants: 3200000, trendUp: true,
    tip: '10+2 level exam. Slightly less competition than SSC CGL.'),
  _Exam(name: 'SSC MTS', category: 'ssc', emoji: '📋', year: 2023,
    vacancies: 11409, applicants: 5500000, trendUp: true,
    tip: 'Best option for 10th pass candidates. CBE format is straightforward.'),
  _Exam(name: 'SSC GD Constable', category: 'ssc', emoji: '📋', year: 2024,
    vacancies: 26146, applicants: 10500000, trendUp: true,
    tip: 'Physical test is critical. GK + Reasoning at easy level.'),

  // ── Banking ──
  _Exam(name: 'IBPS PO', category: 'banking', emoji: '🏦', year: 2024,
    vacancies: 4455, applicants: 1200000, trendUp: false,
    tip: 'Solve Aptitude + Reasoning fast. Interview stage is important.'),
  _Exam(name: 'SBI PO', category: 'banking', emoji: '🏦', year: 2024,
    vacancies: 600, applicants: 600000, trendUp: true,
    tip: 'Most prestigious banking exam. GD + Interview stage is very tough.'),
  _Exam(name: 'IBPS Clerk', category: 'banking', emoji: '🏦', year: 2024,
    vacancies: 6128, applicants: 2800000, trendUp: false,
    tip: 'No interview! Prelims + Mains only. Speed critical.'),
  _Exam(name: 'RBI Grade B', category: 'banking', emoji: '🏦', year: 2024,
    vacancies: 94, applicants: 400000, trendUp: true,
    tip: 'Toughest banking exam. Deep knowledge of Economy + Finance required.'),

  // ── UPSC ──
  _Exam(name: 'UPSC Civil Services', category: 'upsc', emoji: '🏛️', year: 2024,
    vacancies: 1056, applicants: 1350000, trendUp: false,
    tip: 'Minimum 2-3 years dedicated prep needed. NCERT from scratch.'),
  _Exam(name: 'UPSC CDS', category: 'upsc', emoji: '🏛️', year: 2024,
    vacancies: 457, applicants: 450000, trendUp: false,
    tip: 'Under 25 only. Build strong Defence + GK. SSB interview is the key stage.'),

  // ── Railway ──
  _Exam(name: 'RRB NTPC', category: 'railway', emoji: '🚂', year: 2024,
    vacancies: 11558, applicants: 11800000, trendUp: true,
    tip: 'CBT 1 + CBT 2 + Skill test. Prepare Railway GK separately.'),
  _Exam(name: 'RRB Group D', category: 'railway', emoji: '🚂', year: 2022,
    vacancies: 103769, applicants: 11700000, trendUp: false,
    tip: 'Highest vacancies in govt jobs. Physical Efficiency Test is also included.'),
  _Exam(name: 'RRB ALP', category: 'railway', emoji: '🚂', year: 2024,
    vacancies: 18799, applicants: 7000000, trendUp: true,
    tip: 'Technical knowledge (ITI/Diploma) required. Part B trade test.'),

  // ── Defence ──
  _Exam(name: 'NDA', category: 'defence', emoji: '⭐', year: 2024,
    vacancies: 404, applicants: 450000, trendUp: false,
    tip: 'Under 21. Maths + GK. SSB interview is the real challenge.'),
  _Exam(name: 'Agniveer (Army)', category: 'defence', emoji: '⭐', year: 2024,
    vacancies: 25000, applicants: 1000000, trendUp: true,
    tip: 'Physical fitness is the #1 priority. Written test is straightforward.'),

  // ── State ──
  _Exam(name: 'UPPSC PCS', category: 'state', emoji: '📜', year: 2024,
    vacancies: 220, applicants: 500000, trendUp: true,
    tip: 'UP specific. Hindi medium is an advantage. Requires 2+ years of prep.'),
  _Exam(name: 'BPSC CCE', category: 'state', emoji: '📜', year: 2024,
    vacancies: 2035, applicants: 500000, trendUp: false,
    tip: 'Bihar specific. Optional subject choose wisely.'),
];

class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});
  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  String _filter = 'all';
  String _sort   = 'ratio'; // ratio / vacancies / applicants

  static const _filters = [
    ('all',     'All',     '🗓️'),
    ('ssc',     'SSC',     '📋'),
    ('banking', 'Banking', '🏦'),
    ('upsc',    'UPSC',    '🏛️'),
    ('railway', 'Railway', '🚂'),
    ('defence', 'Defence', '⭐'),
    ('state',   'State',   '📜'),
  ];

  List<_Exam> get _sorted {
    final list = _filter == 'all' ? [..._exams] : _exams.where((e) => e.category == _filter).toList();
    switch (_sort) {
      case 'ratio':      list.sort((a, b) => a.ratio.compareTo(b.ratio));
      case 'vacancies':  list.sort((a, b) => b.vacancies.compareTo(a.vacancies));
      case 'applicants': list.sort((a, b) => b.applicants.compareTo(a.applicants));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Competition Analysis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Kitna mushkil hai har exam?', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              )),
            ]),
          )),
        ),
      ),
      body: Column(children: [
        // ── Filters + Sort ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(children: [
            // Category filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _filters.map((f) {
                final (key, label, emoji) = f;
                final sel = _filter == key;
                return GestureDetector(
                  onTap: () => setState(() => _filter = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$emoji $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey[700])),
                  ),
                );
              }).toList()),
            ),
            // Sort row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Text('Sort: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ...[('ratio', 'Difficulty'), ('vacancies', 'Vacancies'), ('applicants', 'Applicants')].map((s) {
                  final sel = _sort == s.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _sort = s.$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? AppColors.accent : Colors.grey[300]!),
                      ),
                      child: Text(s.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? AppColors.accent : Colors.grey[600])),
                    ),
                  );
                }),
              ]),
            ),
          ]),
        ),
        // ── List ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sorted.length,
            itemBuilder: (ctx, i) => _buildCard(_sorted[i], i),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(_Exam e, int rank) {
    return GestureDetector(
      onTap: () => _showDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: e.diffColor.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: e.diffColor.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: e.diffColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(e.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('Data: ${e.year}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ])),
              // Difficulty badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: e.diffColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(e.difficulty, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: e.diffColor)),
              ),
            ]),
            const SizedBox(height: 12),
            // Stats row
            Row(children: [
              _statBox('Vacancies', '${_Exam._fmt(e.vacancies)}', Icons.work_outline, AppColors.primary),
              const SizedBox(width: 10),
              _statBox('Applicants', e.appText, Icons.people_outline, const Color(0xFF7B1FA2)),
              const SizedBox(width: 10),
              _statBox('Ratio', e.ratioText, Icons.show_chart_rounded, e.diffColor),
            ]),
            const SizedBox(height: 10),
            // Ratio bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (e.ratio / 1500).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation(e.diffColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(e.trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 14, color: e.trendUp ? Colors.red[600] : Colors.green[600]),
              const SizedBox(width: 4),
              Text(
                e.trendUp ? 'Competition badh rahi hai' : 'Competition stable/ghaat rahi hai',
                style: TextStyle(fontSize: 11, color: e.trendUp ? Colors.red[600] : Colors.green[600]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
      ]),
    ));
  }

  void _showDetail(_Exam e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Text(e.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: e.diffColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(e.difficulty, style: TextStyle(color: e.diffColor, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            _bigStat('Posts', _Exam._fmt(e.vacancies), AppColors.primary),
            _bigStat('Applied', e.appText, const Color(0xFF7B1FA2)),
            _bigStat('Ratio', e.ratioText, e.diffColor),
          ]),
          const SizedBox(height: 20),
          const Text('💡 Strategy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(e.tip, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _bigStat(String label, String value, Color color) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  ]));
}
