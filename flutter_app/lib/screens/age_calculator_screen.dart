// lib/screens/age_calculator_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';

class _ExamDef {
  final String name, emoji;
  final int minAge, maxAge;
  final int obcRelax, scstRelax;
  final int? maxAttempts, obcAttempts; // null = unlimited
  final String? note;
  final Color color;
  const _ExamDef({
    required this.name,
    required this.emoji,
    required this.minAge,
    required this.maxAge,
    this.obcRelax = 3,
    this.scstRelax = 5,
    this.maxAttempts,
    this.obcAttempts,
    this.note,
    required this.color,
  });
}

const _exams = <_ExamDef>[
  _ExamDef(name: 'UPSC IAS / IPS / IFS', emoji: '🏛️', minAge: 21, maxAge: 32, obcRelax: 3, scstRelax: 5, maxAttempts: 6, obcAttempts: 9, note: 'SC/ST: unlimited attempts', color: Color(0xFF4E342E)),
  _ExamDef(name: 'SSC CGL', emoji: '📋', minAge: 18, maxAge: 32, color: Color(0xFF6A1B9A)),
  _ExamDef(name: 'SSC CHSL (10+2)', emoji: '📋', minAge: 18, maxAge: 27, color: Color(0xFF6A1B9A)),
  _ExamDef(name: 'SSC MTS', emoji: '📋', minAge: 18, maxAge: 27, color: Color(0xFF6A1B9A)),
  _ExamDef(name: 'SSC CPO (SI)', emoji: '👮', minAge: 20, maxAge: 25, color: Color(0xFF283593)),
  _ExamDef(name: 'RRB NTPC', emoji: '🚂', minAge: 18, maxAge: 33, color: Color(0xFF1565C0)),
  _ExamDef(name: 'RRB Group D', emoji: '🚂', minAge: 18, maxAge: 40, color: Color(0xFF1565C0)),
  _ExamDef(name: 'IBPS PO', emoji: '🏦', minAge: 20, maxAge: 30, color: Color(0xFF2E7D32)),
  _ExamDef(name: 'IBPS Clerk', emoji: '🏦', minAge: 20, maxAge: 28, color: Color(0xFF2E7D32)),
  _ExamDef(name: 'SBI PO', emoji: '🏦', minAge: 21, maxAge: 30, color: Color(0xFF2E7D32)),
  _ExamDef(name: 'SBI Clerk', emoji: '🏦', minAge: 20, maxAge: 28, color: Color(0xFF2E7D32)),
  _ExamDef(name: 'RBI Grade B', emoji: '🏦', minAge: 21, maxAge: 30, color: Color(0xFF2E7D32)),
  _ExamDef(name: 'NABARD Grade A / B', emoji: '🏦', minAge: 21, maxAge: 30, color: Color(0xFF2E7D32)),
  _ExamDef(name: 'Indian Army GD', emoji: '⭐', minAge: 17, maxAge: 21, obcRelax: 0, scstRelax: 0, note: 'No category relaxation', color: Color(0xFF558B2F)),
  _ExamDef(name: 'NDA / NA', emoji: '⭐', minAge: 16, maxAge: 19, obcRelax: 0, scstRelax: 0, note: 'No category relaxation', color: Color(0xFF558B2F)),
  _ExamDef(name: 'CISF / BSF / CRPF Constable', emoji: '👮', minAge: 18, maxAge: 23, color: Color(0xFF283593)),
  _ExamDef(name: 'Delhi Police Constable', emoji: '👮', minAge: 18, maxAge: 25, color: Color(0xFF283593)),
  _ExamDef(name: 'DRDO Scientist B', emoji: '🔬', minAge: 21, maxAge: 28, color: Color(0xFF4527A0)),
  _ExamDef(name: 'ISRO Scientist / Engineer', emoji: '🔬', minAge: 18, maxAge: 35, color: Color(0xFF4527A0)),
  _ExamDef(name: 'State PSC (General)', emoji: '🗂️', minAge: 21, maxAge: 40, color: Color(0xFF546E7A)),
];

int _calcAge(DateTime dob) {
  final now = DateTime.now();
  int age = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) age--;
  return age;
}

class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key});

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime? _dob;
  String _category = 'General';
  bool _showResults = false;

  static const _categories = ['General', 'OBC-NCL', 'SC', 'ST', 'EWS', 'PwBD'];

  int get _age => _dob != null ? _calcAge(_dob!) : 0;

  int _effectiveMax(_ExamDef e) {
    if (_category == 'OBC-NCL') return e.maxAge + e.obcRelax;
    if (_category == 'SC' || _category == 'ST') return e.maxAge + e.scstRelax;
    if (_category == 'PwBD') return e.maxAge + 10;
    return e.maxAge;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildInputCard()),
          if (_showResults && _dob != null) ...[
            SliverToBoxAdapter(child: _buildSummaryBanner()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildExamCard(_exams[i]),
                  childCount: _exams.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Age Eligibility Calculator',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 32),
                child: Text('Check which exams you can still apply for',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date of Birth', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dob != null ? const Color(0xFF1565C0) : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18,
                      color: _dob != null ? const Color(0xFF1565C0) : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dob != null ? DateFormat('dd MMMM yyyy').format(_dob!) : 'Tap to select date of birth',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _dob != null ? FontWeight.w700 : FontWeight.normal,
                        color: _dob != null ? AppColors.textPrimary : Colors.grey,
                      ),
                    ),
                  ),
                  if (_dob != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Age: $_age yrs',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _categories.map((c) {
              final sel = _category == c;
              return GestureDetector(
                onTap: () => setState(() { _category = c; _showResults = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF1565C0) : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? const Color(0xFF1565C0) : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(c,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textPrimary,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _dob == null ? null : () => setState(() => _showResults = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                disabledBackgroundColor: Colors.grey[200],
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Check Eligibility →',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final eligible = _exams.where((e) {
      final eff = _effectiveMax(e);
      return _age >= e.minAge && _age <= eff;
    }).length;
    final ineligible = _exams.length - eligible;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your age', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text('$_age years', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Category: $_category', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('$eligible', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              const Text('eligible', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('$ineligible', style: const TextStyle(color: Colors.white60, fontSize: 32, fontWeight: FontWeight.w800)),
              const Text('not eligible', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(_ExamDef e) {
    final eff = _effectiveMax(e);
    final eligible = _age >= e.minAge && _age <= eff;
    final tooYoung = _age < e.minAge;
    final yearsLeft = eligible ? eff - _age : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: eligible ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: eligible ? const Color(0xFF2E7D32).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (eligible ? e.color : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(e.emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: eligible ? AppColors.textPrimary : Colors.grey[400],
                    )),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('${e.minAge}–$eff yrs',
                        style: TextStyle(fontSize: 11, color: eligible ? const Color(0xFF2E7D32) : Colors.grey[400])),
                    if (eligible && e.maxAttempts != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _category == 'SC' || _category == 'ST'
                            ? 'Unlimited attempts'
                            : _category == 'OBC-NCL' && e.obcAttempts != null
                                ? 'Max ${e.obcAttempts} attempts'
                                : 'Max ${e.maxAttempts} attempts',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
                if (e.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(e.note!,
                        style: TextStyle(fontSize: 10, color: Colors.orange[700])),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (eligible)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('✓ Eligible', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: 4),
                Text('$yearsLeft yr${yearsLeft == 1 ? '' : 's'} left',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text(
                tooYoung ? 'Too Young' : 'Age Limit Over',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1998, 6, 15),
      firstDate: DateTime(1960),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _dob = picked; _showResults = false; });
  }
}
