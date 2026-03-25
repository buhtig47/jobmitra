// lib/screens/job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../services/ad_service.dart';
import '../utils/constants.dart';
import '../widgets/profile_fill_sheet.dart';

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
  bool  _isLoading  = true;
  bool  _isSaved    = false;
  bool  _isApplied  = false;
  UserProfile? _profile;

  static const Map<String, Color> _catColors = {
    'railway':   Color(0xFF1565C0),
    'banking':   Color(0xFF2E7D32),
    'ssc':       Color(0xFF6A1B9A),
    'teaching':  Color(0xFF00838F),
    'police':    Color(0xFF283593),
    'defence':   Color(0xFF558B2F),
    'upsc':      Color(0xFF4E342E),
    'anganwadi': Color(0xFFAD1457),
    'psu':       Color(0xFF00695C),
    'medical':   Color(0xFFC62828),
    'research':  Color(0xFF4527A0),
    'engineering': Color(0xFF1565C0),
    'legal':     Color(0xFF37474F),
  };

  Color get _catColor => _catColors[_job?.category] ?? AppColors.primary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _profile = await widget.api.getSavedProfile();
    final results = await Future.wait([
      widget.api.getJobDetail(widget.jobId, _profile?.category ?? 'general'),
      widget.api.getJobStatus(widget.userId, widget.jobId),
    ]);
    final job    = results[0] as Job?;
    final status = results[1] as String?;
    setState(() {
      _job       = job;
      _isLoading = false;
      _isSaved   = status == 'saved';
      _isApplied = status == 'applied';
    });
    if (job != null) widget.api.addRecentlyViewed(job);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _job != null
                  ? [_catColor, _catColor.withValues(alpha: 0.75)]
                  : [AppColors.primary, const Color(0xFF0D4A28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
                        const Text(
                          'Job Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_job != null)
                          Text(
                            _job!.categoryLabel,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    onPressed: _shareJob,
                  ),
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      color: _isSaved ? Colors.amber[300] : Colors.white,
                    ),
                    onPressed: _toggleSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _job == null
              ? const Center(child: Text('Job not found'))
              : _buildContent(),
      bottomNavigationBar: _job == null ? null : _buildApplyButton(),
    );
  }

  Widget _buildContent() {
    final job = _job!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card with colored top bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _catColor.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_catColor, _catColor.withValues(alpha: 0.5)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _catColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: _catColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(job.categoryEmoji, style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 5),
                                Text(
                                  job.categoryLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _catColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _buildUrgencyTag(),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        job.cleanTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.account_balance_outlined, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.cleanDepartment,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.link_rounded, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            job.source,
                            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
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
        const SizedBox(height: 14),

        // Quick Stats Grid
        Row(
          children: [
            _buildStatCard('📋', 'Vacancies', job.vacanciesText),
            const SizedBox(width: 10),
            _buildStatCard('💰', 'Fee', job.feeText, highlight: job.isFree),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('📅', 'Last Date', job.lastDate),
            const SizedBox(width: 10),
            _buildStatCard('🎂', 'Age Limit', '${job.ageMin}–${job.ageMax} yrs'),
          ],
        ),
        if (_job!.payScale != null && _job!.payScale!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💵 Pay Scale / Salary', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(height: 5),
                  Text(_job!.payScale!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),

        // Eligibility
        if (_profile != null) _buildEligibilityCard(),
        const SizedBox(height: 12),

        // Documents Checklist
        if (job.documentsNeeded != null) _buildDocumentsCard(),
        const SizedBox(height: 12),

        // Qualifications
        _buildSection(
          '🎓 Qualification',
          job.qualifications.isEmpty
              ? 'As per official notification'
              : job.qualifications.map((q) {
                  final s = q.trim();
                  return '• ${s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s} pass required';
                }).join('\n'),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildUrgencyTag() {
    final job = _job!;
    Color bg, fg;
    IconData icon;
    switch (job.urgency) {
      case 'red':
        bg = const Color(0xFFFFEBEE); fg = const Color(0xFFD32F2F); icon = Icons.warning_amber_rounded; break;
      case 'yellow':
        bg = const Color(0xFFFFF8E1); fg = const Color(0xFFE65100); icon = Icons.access_time_rounded; break;
      default:
        bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32); icon = Icons.check_circle_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            job.urgencyText,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$emoji $label',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityCard() {
    final profile = _profile!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Your Eligibility Check',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckRow('State', profile.state),
          _buildCheckRow('Education', profile.education),
          _buildCheckRow('Category', profile.category.toUpperCase()),
          _buildCheckRow('Age', '${profile.age} yrs'),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📄', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'Documents Checklist',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._job!.documentsNeeded!.map((doc) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.check_box_outline_blank_rounded, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 10),
                Text(doc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: _isApplied
          ? Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Text('Applied ✓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _launchApplyUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            )
          : ElevatedButton(
              onPressed: _applyAndMark,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Apply Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
    );
  }

  // ─── ACTIONS ───
  Future<void> _toggleSave() async {
    final wasSaved = _isSaved;
    final success = await widget.api.saveJob(
      widget.userId,
      widget.jobId,
      wasSaved ? 'unsaved' : 'saved',
    );
    if (success) {
      setState(() => _isSaved = !_isSaved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  wasSaved ? Icons.bookmark_remove_rounded : Icons.bookmark_added_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  wasSaved ? 'Removed from saved' : 'Job saved!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: wasSaved ? Colors.grey[700] : AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong, please try again'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _shareJob() async {
    if (_job == null) return;
    final msg =
        '🇮🇳 *Govt Job Alert!*\n\n'
        '*${_job!.cleanTitle}*\n'
        '${_job!.cleanDepartment}\n\n'
        '📋 Vacancies: ${_job!.vacanciesText}\n'
        '📅 Last Date: ${_job!.lastDate}\n'
        '💰 Fee: ${_job!.feeText}\n\n'
        'Apply here: ${_job!.sourceUrl}\n\n'
        '_From JobMitra — track your eligible govt jobs!_';
    final waUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl);
    } else {
      Share.share(msg);
    }
  }

  Future<void> _applyAndMark() async {
    if (!mounted) return;
    // Load personal info & show profile card sheet
    final info = await widget.api.getPersonalInfo();
    if (!mounted) return;

    final confirmed = await ProfileFillSheet.show(
      context,
      info: info,
      api: widget.api,
    );
    if (!confirmed) return; // user dismissed without tapping "Form Kholo"

    AdService().showInterstitial();
    await _launchApplyUrl();
    final success = await widget.api.saveJob(widget.userId, widget.jobId, 'applied');
    if (success && mounted) setState(() { _isApplied = true; _isSaved = false; });
  }

  Future<void> _launchApplyUrl() async {
    final url = Uri.parse(_job!.sourceUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
