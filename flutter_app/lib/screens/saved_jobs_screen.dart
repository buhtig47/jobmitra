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

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<Job> _savedJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedJobs();
  }

  Future<void> _loadSavedJobs() async {
    setState(() => _isLoading = true);
    final jobs = await widget.api.getSavedJobs(widget.userId);
    setState(() { _savedJobs = jobs; _isLoading = false; });
    // Check for deadline alerts
    NotificationService.checkDeadlines(jobs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Baad mein apply karne ke liye',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_savedJobs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9933),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_savedJobs.length} Saved',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadSavedJobs,
              color: AppColors.primary,
              child: _savedJobs.isEmpty
                  ? ListView(
                      // Wrap empty state in ListView so pull-to-refresh works
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildEmpty(),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _savedJobs.length,
                      itemBuilder: (ctx, i) {
                        final job = _savedJobs[i];
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
                                Icon(Icons.bookmark_remove_rounded, color: Colors.white, size: 28),
                                SizedBox(height: 4),
                                Text('Remove', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final success = await widget.api.saveJob(
                              widget.userId, job.id, 'unsaved',
                            );
                            if (!success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Remove nahi hua, dobara try karo')),
                              );
                            }
                            return success;
                          },
                          onDismissed: (_) {
                            setState(() => _savedJobs.removeAt(i));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Saved list se hataya'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    await widget.api.saveJob(widget.userId, job.id, 'saved');
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
                                  jobId: job.id,
                                  api: widget.api,
                                  userId: widget.userId,
                                )),
                              );
                              _loadSavedJobs();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Text('🔖', style: TextStyle(fontSize: 52)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Koi saved job nahi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Job detail mein bookmark icon dabaao — baad mein aasani se milegi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
