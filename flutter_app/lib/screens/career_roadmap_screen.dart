// lib/screens/career_roadmap_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';

// ── Data model ─────────────────────────────────────────────
class _ExamRec {
  final String name;
  final String emoji;
  final String body;          // conducting body
  final String phase;         // 'short' | 'medium' | 'long'
  final String why;           // why recommended
  final List<String> edReq;   // education requirements
  final List<String> states;  // 'all' or specific states
  final List<String> cats;    // categories (general/obc/sc/st)
  final int minAge, maxAge;
  final String syllabus;      // short syllabus hint
  final String avgSalary;

  const _ExamRec({
    required this.name,
    required this.emoji,
    required this.body,
    required this.phase,
    required this.why,
    this.edReq = const ['graduate'],
    this.states = const ['all'],
    this.cats   = const ['general','obc','sc','st'],
    required this.minAge,
    required this.maxAge,
    required this.syllabus,
    required this.avgSalary,
  });
}

// ── All exam recommendations ────────────────────────────────
const _allExams = <_ExamRec>[
  // ── Short term (< 6 months, lower competition or quick results) ──
  _ExamRec(
    name: 'SSC MTS',
    emoji: '📋',
    body: 'Staff Selection Commission',
    phase: 'short',
    why: '10th pass ke liye best entry-level govt job',
    edReq: ['10th'],
    minAge: 18, maxAge: 25,
    syllabus: 'Reasoning, Maths, English, GK',
    avgSalary: '₹18,000–22,000/month',
  ),
  _ExamRec(
    name: 'RRB NTPC',
    emoji: '🚂',
    body: 'Railway Recruitment Board',
    phase: 'short',
    why: 'Railway mein lakhs vacancy, good salary + stability',
    edReq: ['12th', 'graduate'],
    minAge: 18, maxAge: 30,
    syllabus: 'Maths, Reasoning, GK, English',
    avgSalary: '₹25,000–35,000/month',
  ),
  _ExamRec(
    name: 'SSC CHSL',
    emoji: '📄',
    body: 'Staff Selection Commission',
    phase: 'short',
    why: 'Delhi posting possible, central govt job',
    edReq: ['12th'],
    minAge: 18, maxAge: 27,
    syllabus: 'Quant, English, Reasoning, GK',
    avgSalary: '₹22,000–28,000/month',
  ),
  _ExamRec(
    name: 'Post Office GDS',
    emoji: '📮',
    body: 'India Post',
    phase: 'short',
    why: 'Merit based, no exam — sirf 10th marks',
    edReq: ['10th'],
    minAge: 18, maxAge: 40,
    syllabus: 'No written exam — merit based',
    avgSalary: '₹12,000–14,500/month',
  ),
  _ExamRec(
    name: 'State Police Constable',
    emoji: '👮',
    body: 'State Police Recruitment Board',
    phase: 'short',
    why: 'Local posting, physical fitness se qualify',
    edReq: ['12th'],
    states: ['UP','MP','Rajasthan','Bihar','Haryana'],
    minAge: 18, maxAge: 25,
    syllabus: 'GK, Reasoning + Physical Test',
    avgSalary: '₹20,000–28,000/month',
  ),

  // ── Medium term (6–18 months prep) ──
  _ExamRec(
    name: 'SSC CGL',
    emoji: '🏛️',
    body: 'Staff Selection Commission',
    phase: 'medium',
    why: 'Inspector, Auditor, Tax Inspector — class A/B posts',
    edReq: ['graduate'],
    minAge: 18, maxAge: 27,
    syllabus: 'Quant, English, Reasoning, GK — 4 tier',
    avgSalary: '₹35,000–60,000/month',
  ),
  _ExamRec(
    name: 'IBPS PO',
    emoji: '🏦',
    body: 'Institute of Banking Personnel Selection',
    phase: 'medium',
    why: 'Bank PO — fastest promotion, urban posting',
    edReq: ['graduate'],
    minAge: 20, maxAge: 30,
    syllabus: 'Quant, Reasoning, English, GK, Computer',
    avgSalary: '₹40,000–55,000/month',
  ),
  _ExamRec(
    name: 'IBPS Clerk',
    emoji: '🏧',
    body: 'Institute of Banking Personnel Selection',
    phase: 'medium',
    why: 'Easier than PO, stepping stone to banking career',
    edReq: ['graduate'],
    minAge: 20, maxAge: 28,
    syllabus: 'Quant, Reasoning, English, GK',
    avgSalary: '₹25,000–35,000/month',
  ),
  _ExamRec(
    name: 'NDA',
    emoji: '🪖',
    body: 'UPSC',
    phase: 'medium',
    why: 'Defence officer — age 16-19 se apply karo',
    edReq: ['12th'],
    cats: ['general','obc','sc','st'],
    minAge: 16, maxAge: 19,
    syllabus: 'Maths, General Ability Test',
    avgSalary: '₹56,000–1,00,000/month (Lt.)',
  ),
  _ExamRec(
    name: 'RRB ALP / Technician',
    emoji: '🔧',
    body: 'Railway Recruitment Board',
    phase: 'medium',
    why: 'ITI/diploma walon ke liye railway mein direct entry',
    edReq: ['10th', 'ITI'],
    minAge: 18, maxAge: 28,
    syllabus: 'Maths, Physics, Reasoning + Trade',
    avgSalary: '₹22,000–35,000/month',
  ),
  _ExamRec(
    name: 'SBI PO',
    emoji: '🏦',
    body: 'State Bank of India',
    phase: 'medium',
    why: 'SBI brand — fastest career growth in banking',
    edReq: ['graduate'],
    minAge: 21, maxAge: 30,
    syllabus: 'Prelim: Quant+Reasoning+English; Mains: full',
    avgSalary: '₹42,000–60,000/month',
  ),
  _ExamRec(
    name: 'State PSC (PCS/SDM)',
    emoji: '🗂️',
    body: 'State Public Service Commission',
    phase: 'medium',
    why: 'State level officer — SDM, BDO, DSP cadre',
    edReq: ['graduate'],
    states: ['UP','MP','Bihar','Rajasthan','Haryana','Punjab'],
    minAge: 21, maxAge: 40,
    syllabus: 'GS Paper 1-4 + Optional + Interview',
    avgSalary: '₹45,000–70,000/month',
  ),

  // ── Long term (18+ months, premium posts) ──
  _ExamRec(
    name: 'UPSC CSE (IAS/IPS/IFS)',
    emoji: '🇮🇳',
    body: 'Union Public Service Commission',
    phase: 'long',
    why: 'India ka sabse prestiguous exam — IAS, IPS, IRS bano',
    edReq: ['graduate'],
    minAge: 21, maxAge: 32,
    syllabus: 'Prelims: GS + CSAT; Mains: 9 papers; Interview',
    avgSalary: '₹56,000–2,50,000/month',
  ),
  _ExamRec(
    name: 'UPSC CAPF (AC)',
    emoji: '🛡️',
    body: 'Union Public Service Commission',
    phase: 'long',
    why: 'CRPF, BSF, CISF, ITBP — Assistant Commandant',
    edReq: ['graduate'],
    minAge: 20, maxAge: 25,
    syllabus: 'GS Paper I & II + Physical + Interview',
    avgSalary: '₹56,000–90,000/month',
  ),
  _ExamRec(
    name: 'UPSC ESE (Engineering)',
    emoji: '⚙️',
    body: 'Union Public Service Commission',
    phase: 'long',
    why: 'Engineers ke liye — IES officer, premier govt tech job',
    edReq: ['B.Tech/BE'],
    minAge: 21, maxAge: 30,
    syllabus: 'GS + Engineering subjects (2 papers)',
    avgSalary: '₹70,000–1,20,000/month',
  ),
  _ExamRec(
    name: 'RBI Grade B Officer',
    emoji: '💰',
    body: 'Reserve Bank of India',
    phase: 'long',
    why: 'RBI — highest paying govt bank job',
    edReq: ['graduate'],
    minAge: 21, maxAge: 30,
    syllabus: 'Phase I: Objective; Phase II: Finance+Mains+Interview',
    avgSalary: '₹80,000–1,00,000/month',
  ),
];

// ── Main Screen ─────────────────────────────────────────────
class CareerRoadmapScreen extends StatefulWidget {
  final ApiService api;
  const CareerRoadmapScreen({super.key, required this.api});

  @override
  State<CareerRoadmapScreen> createState() => _CareerRoadmapScreenState();
}

class _CareerRoadmapScreenState extends State<CareerRoadmapScreen> {
  UserProfile? _profile;
  List<_ExamRec> _recs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await widget.api.getSavedProfile();
    setState(() {
      _profile = p;
      _recs = _filterRecs(p);
    });
  }

  List<_ExamRec> _filterRecs(UserProfile? p) {
    if (p == null) return _allExams;
    return _allExams.where((e) {
      // Age filter
      if (p.age < e.minAge || p.age > e.maxAge) return false;
      // Education filter
      final edu = p.education.toLowerCase();
      if (!e.edReq.contains('all')) {
        final match = e.edReq.any((req) {
          switch (req) {
            case '10th':   return true;
            case 'ITI':    return edu.contains('iti') || edu.contains('diploma');
            case '12th':   return !edu.contains('10th only');
            case 'graduate': return edu.contains('graduate') || edu.contains('pg') || edu.contains('b.');
            case 'B.Tech/BE': return edu.contains('b.tech') || edu.contains('be') || edu.contains('engineering');
            default: return true;
          }
        });
        if (!match) return false;
      }
      // Category filter
      if (!e.cats.contains('all') && !e.cats.contains(p.category.toLowerCase())) return false;
      return true;
    }).toList();
  }

  Color _phaseColor(String phase) {
    switch (phase) {
      case 'short':  return const Color(0xFF2E7D32);
      case 'medium': return const Color(0xFF1565C0);
      default:       return const Color(0xFF6A1B9A);
    }
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'short':  return '0–6 months';
      case 'medium': return '6–18 months';
      default:       return '18+ months';
    }
  }

  String _phaseEmoji(String phase) {
    switch (phase) {
      case 'short':  return '⚡';
      case 'medium': return '🎯';
      default:       return '🏆';
    }
  }

  @override
  Widget build(BuildContext context) {
    final short  = _recs.where((e) => e.phase == 'short').toList();
    final medium = _recs.where((e) => e.phase == 'medium').toList();
    final long   = _recs.where((e) => e.phase == 'long').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF311B92)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 4),
                        const Text('🗺️ Career Roadmap',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        _profile != null
                            ? 'Aapki profile ke hisaab se — age ${_profile!.age}, ${_profile!.education}'
                            : 'Aapke liye best government exams',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                      ),
                      if (_profile == null) ...[
                        const SizedBox(height: 12),
                        _ProfileMissingBanner(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Timeline
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (short.isNotEmpty)  ...[_PhaseHeader(phase:'short',  color:_phaseColor('short'),  label:_phaseLabel('short'),  emoji:_phaseEmoji('short')),  const SizedBox(height:10), ..._buildCards(short,  context), const SizedBox(height:20)],
                if (medium.isNotEmpty) ...[_PhaseHeader(phase:'medium', color:_phaseColor('medium'), label:_phaseLabel('medium'), emoji:_phaseEmoji('medium')), const SizedBox(height:10), ..._buildCards(medium, context), const SizedBox(height:20)],
                if (long.isNotEmpty)   ...[_PhaseHeader(phase:'long',   color:_phaseColor('long'),   label:_phaseLabel('long'),   emoji:_phaseEmoji('long')),   const SizedBox(height:10), ..._buildCards(long,   context), const SizedBox(height:20)],
                if (_recs.isEmpty) _EmptyState(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCards(List<_ExamRec> exams, BuildContext context) =>
      exams.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ExamCard(exam: e, onTap: () => _showDetail(context, e)),
      )).toList();

  void _showDetail(BuildContext context, _ExamRec e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(exam: e),
    );
  }
}

// ── Phase header ────────────────────────────────────────────
class _PhaseHeader extends StatelessWidget {
  final String phase, label, emoji;
  final Color color;
  const _PhaseHeader({required this.phase, required this.color, required this.label, required this.emoji});

  String get _title {
    switch (phase) {
      case 'short':  return '⚡ Quick Wins';
      case 'medium': return '🎯 Main Target';
      default:       return '🏆 Dream Goal';
    }
  }

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Text(_title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    ),
  ]);
}

// ── Exam card ───────────────────────────────────────────────
class _ExamCard extends StatelessWidget {
  final _ExamRec exam;
  final VoidCallback onTap;
  const _ExamCard({required this.exam, required this.onTap});

  Color get _color {
    switch (exam.phase) {
      case 'short':  return const Color(0xFF2E7D32);
      case 'medium': return const Color(0xFF1565C0);
      default:       return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(children: [
          Container(width: 5, height: 90, color: _color),
          const SizedBox(width: 14),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(exam.emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exam.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(exam.body, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(exam.why, style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(exam.avgSalary.split('–').first, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color)),
              const Text('salary', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Icon(Icons.chevron_right_rounded, color: _color.withValues(alpha: 0.5), size: 20),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// ── Detail bottom sheet ─────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final _ExamRec exam;
  const _DetailSheet({required this.exam});

  Color get _color {
    switch (exam.phase) {
      case 'short':  return const Color(0xFF2E7D32);
      case 'medium': return const Color(0xFF1565C0);
      default:       return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(children: [
      // Handle
      const SizedBox(height: 12),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      // Header
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_color, _color.withValues(alpha: 0.75)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Text(exam.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            Text(exam.body, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          ])),
        ]),
      ),
      // Details
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row('💡 Kyun karo?', exam.why),
          _row('📚 Syllabus', exam.syllabus),
          _row('🎓 Education', exam.edReq.join(', ')),
          _row('🎂 Age Limit', '${exam.minAge}–${exam.maxAge} years'),
          _row('💰 Avg Salary', exam.avgSalary),
          const SizedBox(height: 16),
          // Start today box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _color.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🚀 Aaj se shuru karo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _color)),
              const SizedBox(height: 8),
              _tip('1. Official website dekho — notification ka wait mat karo'),
              _tip('2. Previous year papers download karo'),
              _tip('3. Daily 2-3 hours — consistency matters'),
            ]),
          ),
        ]),
      )),
      // Close
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ),
    ]),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
    ]),
  );

  Widget _tip(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
  );
}

// ── Profile missing banner ──────────────────────────────────
class _ProfileMissingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      const Expanded(child: Text('Profile set karo for personalized recommendations',
          style: TextStyle(color: Colors.white, fontSize: 12))),
    ]),
  );
}

// ── Empty state ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🤔', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text('Aapke profile ke hisaab se koi match nahi mila',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Profile update karo — age aur education check karo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    ),
  );
}
