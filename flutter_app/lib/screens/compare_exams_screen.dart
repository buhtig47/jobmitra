// lib/screens/compare_exams_screen.dart
//
// Side-by-side comparison of two govt jobs. Aspirants routinely choose
// between SSC CGL vs RRB NTPC etc.; this screen lays the eligibility +
// reward axes next to each other so the decision takes 30 seconds.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class CompareExamsScreen extends StatelessWidget {
  final Job left;
  final Job right;
  const CompareExamsScreen({super.key, required this.left, required this.right});

  Color _color(Job j) => left == j ? const Color(0xFF1A6B3C) : const Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final rows = <_DiffRow>[
      _DiffRow('Category',        left.categoryLabel, right.categoryLabel),
      _DiffRow('Department',      left.cleanDepartment, right.cleanDepartment),
      _DiffRow('Vacancies',       left.vacanciesText, right.vacanciesText),
      _DiffRow('Last date',       left.lastDate, right.lastDate),
      _DiffRow('Days left',       '${left.daysLeft} days', '${right.daysLeft} days'),
      _DiffRow('Fee',             left.feeText, right.feeText),
      _DiffRow('Age range',       '${left.ageMin}-${left.ageMax} yrs',
                                  '${right.ageMin}-${right.ageMax} yrs'),
      _DiffRow('Pay scale',       left.payScale ?? '—', right.payScale ?? '—'),
      _DiffRow('Qualifications',  left.qualifications.join(', '),
                                  right.qualifications.join(', ')),
      _DiffRow('States',          left.states.join(', '),
                                  right.states.join(', ')),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Compare Exams',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _shareSummary(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildTable(rows),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: _buildJobCard(left, _color(left))),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('VS',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey)),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildJobCard(right, _color(right))),
      ],
    );
  }

  Widget _buildJobCard(Job j, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${j.categoryEmoji} ${j.categoryLabel}',
              style: TextStyle(
                  fontSize: 10.5, color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Text(j.cleanTitle,
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildTable(List<_DiffRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            _buildRow(rows[i], isLast: i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _buildRow(_DiffRow r, {required bool isLast}) {
    final isDifferent = r.left.trim() != r.right.trim();
    final hl = isDifferent ? AppColors.primary.withValues(alpha: 0.04) : null;
    return Container(
      decoration: BoxDecoration(
        color: hl,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(r.label,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2)),
          ),
          Expanded(
            child: Text(r.left,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r.right,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _shareSummary() {
    final msg = '''
🇮🇳 *Job Comparison — JobMitra*

📌 *${left.cleanTitle}*
📅 Last: ${left.lastDate} | 👥 ${left.vacanciesText} | 💰 ${left.feeText}

VS

📌 *${right.cleanTitle}*
📅 Last: ${right.lastDate} | 👥 ${right.vacanciesText} | 💰 ${right.feeText}

_Compare more on JobMitra._
''';
    Share.share(msg.trim());
  }
}

class _DiffRow {
  final String label;
  final String left;
  final String right;
  const _DiffRow(this.label, this.left, this.right);
}

// ── Picker — pick a second job to compare with ───────────────────────────────
class CompareJobPicker extends StatefulWidget {
  final Job seed;
  final ApiService api;
  const CompareJobPicker({super.key, required this.seed, required this.api});

  @override
  State<CompareJobPicker> createState() => _CompareJobPickerState();
}

class _CompareJobPickerState extends State<CompareJobPicker> {
  final _controller = TextEditingController();
  List<Job> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Seed with same category so the first 20 options are relevant.
    _controller.text = widget.seed.categoryLabel.split(' ').first.toLowerCase();
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.length < 2) return;
    setState(() => _loading = true);
    final list = await widget.api.searchJobs(q);
    if (!mounted) return;
    setState(() {
      _results = list.where((j) => j.id != widget.seed.id).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pick to Compare',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search: SSC, RRB, UPSC…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _search,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _results.isEmpty
                    ? const Center(
                        child: Text(
                          'Koi match nahi mila. Doosra keyword try karo.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final j = _results[i];
                          return InkWell(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompareExamsScreen(
                                      left: widget.seed, right: j),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Text(j.categoryEmoji,
                                      style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(j.cleanTitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${j.categoryLabel} · ${j.vacanciesText} · ${j.lastDate}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
