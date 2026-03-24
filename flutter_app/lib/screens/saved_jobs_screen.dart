// lib/screens/saved_jobs_screen.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/job_card.dart';
import '../services/notification_service.dart';
import 'job_detail_screen.dart';

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
  bool _isLoading = true;
  late TabController _tabController;

  List<Job> get _savedJobs  => _allJobs.where((j) => j.jobStatus != 'applied').toList();
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
    final jobs = await widget.api.getSavedJobs(widget.userId);
    setState(() { _allJobs = jobs; _isLoading = false; });
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
                              'Apni jobs track karo',
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
                  // Applied jobs: show as-is with green Applied badge, no swipe
                  return _AppliedJobCard(
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
                            content: Text('Remove nahi hua, dobara try karo')),
                      );
                    }
                    return success;
                  },
                  onDismissed: (_) {
                    setState(() => _allJobs.removeWhere((j) => j.id == job.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Saved list se hataya'),
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
              isApplied ? 'Abhi tak koi apply nahi kiya' : 'Koi saved job nahi',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isApplied
                  ? 'Job detail mein "Apply Karo" dabao — yahan track hogi'
                  : 'Job detail mein bookmark icon dabaao — baad mein aasani se milegi',
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

// ── Applied Job Card (green Applied badge) ───────────────
class _AppliedJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const _AppliedJobCard({required this.job, required this.onTap});

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
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Last date: ${job.lastDate}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.people_outline,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          job.vacanciesText,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
