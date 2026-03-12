// lib/screens/job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;
  final int userId;
  final ApiService api;

  const JobDetailScreen({
    super.key,
    required this.jobId,
    required this.userId,
    required this.api,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job?  _job;
  bool  _isLoading = true;
  bool  _isSaved   = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _profile = await widget.api.getSavedProfile();
    final job = await widget.api.getJobDetail(
      widget.jobId,
      _profile?.category ?? 'general',
    );
    setState(() { _job = job; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareJob,
          ),
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _job == null
              ? const Center(child: Text('Job nahi mili'))
              : _buildContent(),
      bottomNavigationBar: _job == null ? null : _buildApplyButton(),
    );
  }

  Widget _buildContent() {
    final job = _job!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(job.categoryEmoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.categoryLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(job.source,
                            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildUrgencyTag(),
                  ],
                ),
                const SizedBox(height: 14),
                Text(job.title,
                  style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(job.department,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quick Stats
        Row(
          children: [
            _buildStatCard('📋', 'Vacancies', job.vacanciesText),
            const SizedBox(width: 10),
            _buildStatCard('💰', 'Fee', job.feeText,
              highlight: job.isFree),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('📅', 'Last Date', job.lastDate),
            const SizedBox(width: 10),
            _buildStatCard('🎂', 'Age Limit', '${job.ageMin}-${job.ageMax} yrs'),
          ],
        ),
        const SizedBox(height: 16),

        // Eligibility (user-specific)
        if (_profile != null) _buildEligibilityCard(),
        const SizedBox(height: 12),

        // Documents Checklist
        if (job.documentsNeeded != null) _buildDocumentsCard(),
        const SizedBox(height: 12),

        // Qualifications
        _buildSection(
          '🎓 Qualification',
          job.qualifications.map((q) => '• ${q.toUpperCase()} Pass required').join('\n'),
        ),
        const SizedBox(height: 80), // space for bottom button
      ],
    );
  }

  Widget _buildUrgencyTag() {
    final job = _job!;
    Color c = job.urgency == 'red' ? AppColors.urgencyRed
             : job.urgency == 'yellow' ? AppColors.urgencyYellow
             : AppColors.urgencyGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        job.urgencyText,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$emoji $label',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 4),
              Text(value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEligibilityCard() {
    final profile = _profile!;
    return Card(
      color: AppColors.primary.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primary, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Aapke liye check',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            _buildCheckRow('State', profile.state),
            _buildCheckRow('Education', profile.education),
            _buildCheckRow('Category', profile.category.toUpperCase()),
            _buildCheckRow('Age', '${profile.age} saal'),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📄 Documents Checklist',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ..._job!.documentsNeeded!.map((doc) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank, size: 18, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Text(doc, style: const TextStyle(fontSize: 13)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(content,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: ElevatedButton(
        onPressed: _launchApplyUrl,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: AppColors.accent,
        ),
        child: const Text(
          'Apply Karo → Official Website',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ─── ACTIONS ───
  Future<void> _toggleSave() async {
    final success = await widget.api.saveJob(
      widget.userId,
      widget.jobId,
      _isSaved ? 'unsaved' : 'saved',
    );
    if (success) setState(() => _isSaved = !_isSaved);
  }

  void _shareJob() {
    if (_job == null) return;
    Share.share(
      '🇮🇳 Govt Job Alert!\n\n'
      '${_job!.title}\n'
      '${_job!.department}\n\n'
      '📋 Vacancies: ${_job!.vacanciesText}\n'
      '📅 Last Date: ${_job!.lastDate}\n'
      '💰 Fee: ${_job!.feeText}\n\n'
      'Apply: ${_job!.sourceUrl}\n\n'
      'JobMitra app se download karo — sirf eligible jobs!',
    );
  }

  Future<void> _launchApplyUrl() async {
    final url = Uri.parse(_job!.sourceUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
