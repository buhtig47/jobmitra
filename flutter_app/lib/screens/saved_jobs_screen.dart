// lib/screens/saved_jobs_screen.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import '../services/notification_service.dart';
import 'job_detail_screen.dart';

// ── Application stages ─────────────────────────────────────
class _Stage {
  final String key;
  final String label;
  final String emoji;
  final Color  color;
  const _Stage(this.key, this.label, this.emoji, this.color);
}

const _stages = [
  _Stage('applied',        'Applied',         '📝', Color(0xFF1565C0)),
  _Stage('fee_paid',       'Fee Paid',         '💳', Color(0xFF7B1FA2)),
  _Stage('form_submitted', 'Form Submitted',   '✅', Color(0xFF2E7D32)),
  _Stage('admit_card',     'Admit Card',       '🪪', Color(0xFFE65100)),
  _Stage('exam_appeared',  'Exam Appeared',    '✍️', Color(0xFF00695C)),
  _Stage('result',         'Result',           '🏆', Color(0xFFC62828)),
];

class SavedJobsScreen extends StatefulWidget {
  final int userId;
  final ApiService api;
  const SavedJobsScreen({super.key, required this.userId, required this.api});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen>
    with SingleTickerProviderStateMixin {
  List<Job> _allJobs = [];
  Map<int, Map<String, String>> _trackers = {};
  bool _isLoading = true;
  late TabController _tabController;

  List<Job> get _savedJobs   => _allJobs.where((j) => j.jobStatus == 'saved').toList();
  List<Job> get _appliedJobs => _allJobs.where((j) => j.jobStatus == 'applied').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedJobs() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      widget.api.getSavedJobs(widget.userId),
      widget.api.getAllTrackers(),
    ]);
    final jobs     = results[0] as List<Job>;
    final trackers = results[1] as Map<int, Map<String, String>>;
    setState(() { _allJobs = jobs; _trackers = trackers; _isLoading = false; });
    NotificationService.checkDeadlines(jobs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '🔖 Saved Jobs',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Track your applications',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (_allJobs.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9933),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_allJobs.length} Total',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
                // Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFFF9933),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: [
                    Tab(text: '🔖 Saved (${_savedJobs.length})'),
                    Tab(text: '✅ Applied (${_appliedJobs.length})'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildJobList(_savedJobs, isApplied: false),
                _buildJobList(_appliedJobs, isApplied: true),
              ],
            ),
    );
  }

  Widget _buildJobList(List<Job> jobs, {required bool isApplied}) {
    return RefreshIndicator(
      onRefresh: _loadSavedJobs,
      color: AppColors.primary,
      child: jobs.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: _buildEmpty(isApplied),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (ctx, i) {
                final job = jobs[i];
                if (isApplied) {
                  return Dismissible(
                    key: ValueKey('applied_${job.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.undo_rounded, color: Colors.white, size: 28),
                          SizedBox(height: 4),
                          Text('Undo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    confirmDismiss: (_) async {
                      final success = await widget.api.saveJob(widget.userId, job.id, 'saved');
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Something went wrong, please try again')),
                        );
                      }
                      return success;
                    },
                    onDismissed: (_) {
                      setState(() => _allJobs.removeWhere((j) => j.id == job.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Moved from Applied to Saved'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      _loadSavedJobs();
                    },
                    child: _AppliedJobCard(
                      job: job,
                      tracker: _trackers[job.id],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => JobDetailScreen(
                            jobId: job.id, api: widget.api, userId: widget.userId,
                          )),
                        );
                        _loadSavedJobs();
                      },
                      onUpdateStage: () async {
                        await _showStageSheet(job);
                        _loadSavedJobs();
                      },
                    ),
                  );
                }
                // Saved jobs: swipe left to remove
                return Dismissible(
                  key: ValueKey(job.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red[400],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_remove_rounded,
                            color: Colors.white, size: 28),
                        SizedBox(height: 4),
                        Text('Remove',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  confirmDismiss: (_) async {
                    final success = await widget.api.saveJob(
                        widget.userId, job.id, 'unsaved');
                    if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Failed to remove, please try again')),
                      );
                    }
                    return success;
                  },
                  onDismissed: (_) {
                    setState(() => _allJobs.removeWhere((j) => j.id == job.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Removed from saved'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            await widget.api.saveJob(
                                widget.userId, job.id, 'saved');
                            _loadSavedJobs();
                          },
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                  child: JobCard(
                    job: job,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => JobDetailScreen(
                          jobId: job.id, api: widget.api, userId: widget.userId,
                        )),
                      );
                      _loadSavedJobs();
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showStageSheet(Job job) async {
    final tracker  = _trackers[job.id] ?? {};
    // Use a mutable local so stage chips update visually without reopening the sheet
    String localStage = tracker['stage'] ?? 'applied';
    final regCtrl  = TextEditingController(text: tracker['reg_no'] ?? '');
    final examCtrl = TextEditingController(text: tracker['exam_date'] ?? '');
    final noteCtrl = TextEditingController(text: tracker['note'] ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(
                    children: [
                      Text(job.categoryEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(job.cleanTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                // Stage stepper
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _stages.map((s) {
                      final stageIdx  = _stages.indexWhere((st) => st.key == s.key);
                      final curIdx    = _stages.indexWhere((st) => st.key == localStage);
                      final isDone    = stageIdx <= curIdx;
                      final isCurrent = s.key == localStage;
                      return GestureDetector(
                        onTap: () async {
                          setS(() => localStage = s.key); // update chip immediately
                          await widget.api.updateTracker(job.id, {'stage': s.key});
                          if (mounted) setState(() { _trackers[job.id] = {...(_trackers[job.id] ?? {}), 'stage': s.key}; });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDone ? s.color : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: isCurrent ? Border.all(color: s.color, width: 2) : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.emoji, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 5),
                              Text(s.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDone ? Colors.white : Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Extra fields
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _miniField(regCtrl,  'Registration No.',  Icons.numbers_rounded),
                      const SizedBox(height: 8),
                      _miniField(examCtrl, 'Exam Date (DD/MM/YYYY)', Icons.calendar_today_rounded, keyboard: TextInputType.datetime),
                      const SizedBox(height: 8),
                      _miniField(noteCtrl, 'Note (optional)', Icons.note_rounded),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.api.updateTracker(job.id, {
                        'reg_no':    regCtrl.text.trim(),
                        'exam_date': examCtrl.text.trim(),
                        'note':      noteCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    regCtrl.dispose(); examCtrl.dispose(); noteCtrl.dispose();
  }

  Widget _miniField(TextEditingController ctrl, String hint, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true, fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _buildEmpty(bool isApplied) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Text(
                isApplied ? '✅' : '🔖',
                style: const TextStyle(fontSize: 52),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isApplied ? 'No applications yet' : 'No saved jobs',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isApplied
                  ? 'Tap "Apply Now" in job detail to track here'
                  : 'Tap the bookmark in job detail to save for later',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Applied Job Card (with stage tracker) ────────────────
class _AppliedJobCard extends StatelessWidget {
  final Job                   job;
  final Map<String, String>?  tracker;
  final VoidCallback          onTap;
  final VoidCallback          onUpdateStage;
  const _AppliedJobCard({required this.job, this.tracker, required this.onTap, required this.onUpdateStage});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                height: 4,
                color: const Color(0xFF2E7D32),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(job.categoryEmoji,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            job.cleanTitle,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 12, color: Color(0xFF2E7D32)),
                              SizedBox(width: 4),
                              Text('Applied',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('Last date: ${job.lastDate}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Icon(Icons.people_outline, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(job.vacanciesText, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ── Stage tracker row ──
                    _buildStageRow(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageRow(BuildContext context) {
    final curStage = tracker?['stage'] ?? 'applied';
    final curIdx   = _stages.indexWhere((s) => s.key == curStage);
    final stage    = curIdx >= 0 ? _stages[curIdx] : _stages[0];
    return GestureDetector(
      onTap: onUpdateStage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: stage.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: stage.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Text(stage.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(stage.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: stage.color)),
            const Spacer(),
            // Mini step dots
            Row(
              children: List.generate(_stages.length, (i) => Container(
                width: 7, height: 7,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= curIdx ? stage.color : Colors.grey[300],
                ),
              )),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_rounded, size: 14, color: stage.color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
