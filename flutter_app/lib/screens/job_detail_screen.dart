// lib/screens/job_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../services/ad_service.dart';
import '../utils/constants.dart';
import '../widgets/profile_fill_sheet.dart';
import '../widgets/job_share_sheet.dart';
import '../services/cheatsheet_pdf.dart';
import 'compare_exams_screen.dart';
import '../services/notification_service.dart';

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

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  Job?  _job;
  bool  _isLoading  = true;
  bool  _isSaved    = false;
  bool  _isApplied  = false;
  UserProfile? _profile;
  late final TabController _tabController;
  bool _isReminderSet = false;
  Map<String, bool> _checkedDocs = {};
  static const _kReminderPrefix = 'job_reminder_';
  static const _kDocsCheckedPfx = 'docs_checked_';

  // ── Official govt portal lookup ──────────────────────────────
  // Keys are lowercase substrings checked against "title dept"
  static const Map<String, String> _orgPortals = {
    'ssc':          'https://ssc.gov.in',
    'upsc':         'https://upsconline.nic.in',
    'ibps':         'https://www.ibps.in',
    'sbi po':       'https://bank.sbi/web/careers',
    'sbi clerk':    'https://bank.sbi/web/careers',
    'sbi':          'https://bank.sbi/web/careers',
    'rbi':          'https://opportunities.rbi.org.in',
    'rrb':          'https://rrbapply.gov.in',
    'drdo':         'https://rac.gov.in',
    'rac':          'https://rac.gov.in',
    'isro':         'https://www.isro.gov.in/careers',
    'aiims':        'https://aiimsexams.ac.in',
    'join indian army': 'https://joinindianarmy.nic.in',
    'indian army':  'https://joinindianarmy.nic.in',
    'indian navy':  'https://joinindiannavy.gov.in',
    'air force':    'https://careerairforce.nic.in',
    'indian coast': 'https://joinindiancoastguard.cdac.in',
    'lic':          'https://licindia.in',
    'ongc':         'https://ongcindia.com',
    'bhel':         'https://bhel.com',
    'npcil':        'https://npcilcareers.co.in',
    'india post':   'https://indiapostgdsonline.gov.in',
    'postal':       'https://indiapostgdsonline.gov.in',
    'navodaya':     'https://navodaya.gov.in',
    'nvs':          'https://navodaya.gov.in',
    'kvs':          'https://kvsangathan.nic.in',
    'kendriya vidyalaya': 'https://kvsangathan.nic.in',
    'csir':         'https://csirhrdg.res.in',
    'icmr':         'https://icmr.gov.in',
    'nabard':       'https://www.nabard.org',
    'sebi':         'https://www.sebi.gov.in',
    'bsnl':         'https://www.bsnl.co.in',
    'nhm':          'https://nhm.gov.in',
    'nrhm':         'https://nhm.gov.in',
    'fci':          'https://www.fci.gov.in',
    'food corporation': 'https://www.fci.gov.in',
    'high court':   'https://njdg.ecourts.gov.in',
    'district court': 'https://njdg.ecourts.gov.in',
  };

  static const Map<String, String> _categoryPortals = {
    'ssc':      'https://ssc.gov.in',
    'upsc':     'https://upsconline.nic.in',
    'railway':  'https://rrbapply.gov.in',
    'banking':  'https://www.ibps.in',
    'defence':  'https://joinindianarmy.nic.in',
    'postal':   'https://indiapostgdsonline.gov.in',
    'teaching': 'https://ctet.nic.in',
  };

  /// Returns (url, portalName) — best apply URL we can determine.
  (String, String?) _resolveApply() {
    if (_job == null) return ('', null);

    // If sourceUrl is already an official domain → use it directly
    final srcHost = Uri.tryParse(_job!.sourceUrl)?.host ?? '';
    if (srcHost.endsWith('.gov.in') || srcHost.endsWith('.nic.in')) {
      return (_job!.sourceUrl, srcHost);
    }

    final combined = '${_job!.title} ${_job!.department}'.toLowerCase();

    // Org keyword match (longest key first for specificity)
    final sortedKeys = _orgPortals.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      if (combined.contains(key)) {
        final host = Uri.tryParse(_orgPortals[key]!)?.host ?? key;
        return (_orgPortals[key]!, host);
      }
    }

    // Category fallback
    final cat = _categoryPortals[_job!.category];
    if (cat != null) {
      final host = Uri.tryParse(cat)?.host ?? cat;
      return (cat, host);
    }

    return (_job!.sourceUrl, null); // last resort: news article
  }

  Color get _catColor => _job == null
      ? AppColors.primary
      : JobCategoryColors.colorFor(_job!.category);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadLocalState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // getSavedProfile is a SharedPrefs read — run in parallel with network calls
    final profileFuture = widget.api.getSavedProfile();
    final statusFuture  = widget.api.getJobStatus(widget.userId, widget.jobId);

    final profile = await profileFuture;
    // Now fetch detail with the correct user category
    final results = await Future.wait([
      widget.api.getJobDetail(widget.jobId, profile?.category ?? 'general'),
      statusFuture,
    ]);
    final job    = results[0] as Job?;
    final status = results[1] as String?;

    if (!mounted) return; // guard against dispose during async gap
    setState(() {
      _profile   = profile;
      _job       = job;
      _isLoading = false;
      _isSaved   = status == 'saved';
      _isApplied = status == 'applied';
    });
    // addRecentlyViewed removed — recently viewed feature removed
  }

  // Fire an interstitial on the way out (the frequency cap in AdService keeps
  // this from showing on every single back-nav). Called from both the system
  // back-gesture (via PopScope) and the AppBar back button.
  void _maybeShowExitInterstitial() {
    AdService().showInterstitial();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _job != null ? _catColor : AppColors.primary;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _maybeShowExitInterstitial();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(116), // 68 toolbar + 48 tabs
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catColor, catColor.withValues(alpha: 0.82)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toolbar row
                  SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                            onPressed: () {
                              _maybeShowExitInterstitial();
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Job Details',
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                                if (_job != null)
                                  Text(
                                    '${_job!.categoryEmoji} ${_job!.categoryLabel}',
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
                            tooltip: 'Set deadline reminder',
                            icon: Icon(
                              _isReminderSet
                                  ? Icons.notifications_active_rounded
                                  : Icons.add_alert_rounded,
                              color: _isReminderSet ? Colors.amber[300] : Colors.white,
                            ),
                            onPressed: _showReminderSheet,
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
                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Eligibility'),
                      Tab(text: 'Documents'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _job == null
                ? const Center(child: Text('Job not found'))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(_job!),
                      _buildEligibilityTab(_job!),
                      _buildDocumentsTab(_job!),
                    ],
                  ),
        bottomNavigationBar: _job == null ? null : _buildApplyButton(),
      ),
    );
  }

  // ── Tab: Overview ────────────────────────────────────────────
  Widget _buildOverviewTab(Job job) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Header summary card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: _catColor.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_catColor, _catColor.withValues(alpha: 0.5)]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildUrgencyTag(),
                          const Spacer(),
                          Row(children: [
                            Icon(Icons.link_rounded, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 3),
                            Text(job.source, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(job.cleanTitle,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.35)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.account_balance_outlined, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(child: Text(job.cleanDepartment,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Quick stats 2×2
        Row(children: [
          _buildStatCard('📋', 'Vacancies', job.vacanciesText),
          const SizedBox(width: 10),
          _buildStatCard('💰', 'Fee', job.feeText, highlight: job.isFree),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _buildStatCard('📅', 'Last Date', job.lastDate),
          const SizedBox(width: 10),
          _buildStatCard('🎂', 'Age Limit', '${job.ageMin}–${job.ageMax} yrs'),
        ]),

        // Pay scale
        if (job.payScale != null && job.payScale!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💵 Pay Scale / Salary', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 5),
                Text(job.payScale!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
            ),
          ),
        const SizedBox(height: 14),

        _buildCheatsheetCard(),
        const SizedBox(height: 12),
        _buildCompareTile(),
      ],
    );
  }

  // ── Tab: Eligibility ─────────────────────────────────────────
  Widget _buildEligibilityTab(Job job) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        if (_profile != null) ...[
          _buildEligibilityCard(),
          const SizedBox(height: 14),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Profile mein details bharo to eligibility check hogi',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                )),
              ]),
            ),
          ),
        _buildSection(
          '🎓 Qualifications',
          job.qualifications.isEmpty
              ? 'As per official notification'
              : job.qualifications.map((q) {
                  final s = q.trim();
                  return '• ${s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s}';
                }).join('\n'),
        ),
      ],
    );
  }

  // ── Tab: Documents ───────────────────────────────────────────
  static const _kCommonDocs = [
    '📷 Passport size photo (JPG, <100 KB)',
    '✍️ Specimen signature (JPG, <30 KB)',
    '🎓 10th Certificate & Marksheet',
    '🎓 12th Certificate & Marksheet',
    '🎓 Graduation Degree & Marksheet (if required)',
    '🪪 Aadhaar Card',
    '🃏 PAN Card',
    '🗂️ Caste Certificate (OBC/SC/ST, if applicable)',
    '📄 Income Certificate (for fee waiver, if applicable)',
    '📜 Domicile / Residence Certificate',
    '♿ PwD Certificate (if applicable)',
    '🪖 Ex-Servicemen Certificate (if applicable)',
  ];

  Widget _buildDocumentsTab(Job job) {
    final hasSpecific = job.documentsNeeded != null && job.documentsNeeded!.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        if (!hasSpecific) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.amber[800], size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Specific list extract nahi hua. Yahan common govt exam documents hain — inhe prepare karo.',
                style: TextStyle(fontSize: 12, color: Colors.amber[900], height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          _buildDocumentsCard(docList: _kCommonDocs, title: 'Common Documents'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('Official Notification Dekho'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final url = Uri.tryParse(job.sourceUrl);
              if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
        ] else
          _buildDocumentsCard(),
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
    final job = _job!;

    final ageOk = profile.age >= job.ageMin && profile.age <= job.ageMax;

    final catLower = profile.category.toLowerCase();
    final feeWaived = catLower == 'sc' || catLower == 'st' ||
        catLower.contains('ph') || catLower.contains('pwd');
    final feeOk = job.isFree || feeWaived;
    final feeLabel = job.isFree
        ? 'Free for all'
        : feeWaived
            ? 'Waived (₹${job.fee} → ₹0)'
            : '₹${job.fee}';

    const eduLevels = {
      '8th': 1, '10th': 2, '12th': 3, 'diploma': 3,
      'graduate': 4, 'postgraduate': 5,
    };
    final userEduLevel = eduLevels[profile.education] ?? 4;
    final eduOk = job.qualifications.isEmpty ||
        job.qualifications.any((q) => userEduLevel >= (eduLevels[q] ?? 4));

    final eduLabel = profile.education.isEmpty
        ? 'Not set'
        : profile.education[0].toUpperCase() + profile.education.substring(1).toLowerCase();
    final catLabel = profile.category.isEmpty
        ? 'Not set'
        : profile.category[0].toUpperCase() + profile.category.substring(1).toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('Your Eligibility Check',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckRow('State', profile.state),
          _buildCheckRow('Education', eduLabel, isOk: eduOk),
          _buildCheckRow('Category', catLabel),
          _buildCheckRow('Age',
              '${profile.age} yrs (limit: ${job.ageMin}–${job.ageMax})',
              isOk: ageOk),
          _buildCheckRow('Fee', feeLabel, isOk: feeOk),
          if (!ageOk) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange[700], size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Age limit mein nahi ho — age relaxation check karo official notification mein (SC/ST/OBC ke liye hoti hai)',
                  style: TextStyle(fontSize: 11, color: Colors.orange[800], height: 1.4),
                )),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, String value, {bool? isOk}) {
    final Color iconColor;
    final IconData iconData;
    if (isOk == null) {
      iconColor = AppColors.primary;
      iconData  = Icons.check_circle_rounded;
    } else if (isOk) {
      iconColor = const Color(0xFF2E7D32);
      iconData  = Icons.check_circle_rounded;
    } else {
      iconColor = const Color(0xFFD32F2F);
      iconData  = Icons.cancel_rounded;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(iconData, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isOk == false ? const Color(0xFFD32F2F) : AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard({List<String>? docList, String title = 'Documents Checklist'}) {
    final docs = docList ?? _job!.documentsNeeded ?? [];
    final checkedCount = docs.where((d) => _checkedDocs[d] == true).length;
    final allDone = checkedCount == docs.length && docs.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📄', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allDone
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$checkedCount/${docs.length} ready',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: allDone ? const Color(0xFF2E7D32) : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Tap to mark documents ready',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 10),
          ...docs.map((doc) {
            final checked = _checkedDocs[doc] ?? false;
            return InkWell(
              onTap: () => _toggleDoc(doc),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: checked ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: checked ? AppColors.primary : Colors.grey[400]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: checked
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        doc,
                        style: TextStyle(
                          fontSize: 13,
                          color: checked ? AppColors.textHint : AppColors.textSecondary,
                          decoration: checked ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCheatsheetCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Form-Fill Cheat-Sheet',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    SizedBox(height: 2),
                    Text(
                      'Printable PDF — name, DOB, address, docs list. Cyber cafe le ja sako.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11.5,
                          height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateCheatsheet,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Generate PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateCheatsheet() async {
    if (_job == null) return;
    final info = await widget.api.getPersonalInfo();
    if (!mounted) return;
    if (info.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Pehle Profile -> Form Fill Details bharo, fir cheat-sheet generate hogi'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      await CheatsheetPdf.shareForJob(job: _job!, info: info);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generate nahi hua: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildCompareTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (_job == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompareJobPicker(seed: _job!, api: widget.api),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFE65100).withValues(alpha: 0.06),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.compare_arrows_rounded,
                  color: Color(0xFFE65100), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Compare with another exam',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 2),
                  Text(
                    'Side-by-side — vacancy, fee, age, last date dekho ek saath',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11.5,
                        height: 1.35),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
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
    final (applyUrl, portalName) = _resolveApply();
    final isOfficialUrl = applyUrl != _job!.sourceUrl;
    final portalLabel   = portalName != null
        ? portalName.replaceFirst('www.', '')
        : 'Official Portal';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: _isApplied
          ? _buildAppliedBar(applyUrl)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick-action icon row
                Row(
                  children: [
                    _buildQuickAction(
                      Icons.article_outlined, 'Notification', _launchSourceUrl),
                    _buildQuickAction(
                      _isReminderSet
                          ? Icons.notifications_active_rounded
                          : Icons.add_alert_outlined,
                      _isReminderSet ? 'Reminder ✓' : 'Reminder',
                      _showReminderSheet,
                      active: _isReminderSet,
                    ),
                    _buildQuickAction(
                      Icons.assignment_outlined, 'App. Card', _showApplicationCard),
                  ],
                ),
                const SizedBox(height: 6),
                // Primary apply button (full width)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _applyAndMark,
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                    label: Text(
                      isOfficialUrl ? 'Apply at $portalLabel →' : 'Apply / View →',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                if (isOfficialUrl) ...[
                  const SizedBox(height: 5),
                  Text(
                    '🔒 Details clipboard mein copy honge — form mein paste karo',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildAppliedBar(String applyUrl) {
    return Row(
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
                Text('Applied ✓',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: _launchSourceUrl,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Icon(Icons.article_outlined, color: Colors.grey, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => _launchUrl(applyUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              elevation: 0,
            ),
            child: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    return Expanded(
      child: InkWell(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22,
                  color: active ? AppColors.primary : Colors.grey[600]),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? AppColors.primary : Colors.grey[600],
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
    if (success && mounted) {
      setState(() => _isSaved = !_isSaved);
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
    await showJobShareSheet(context, _job!);
  }

  Future<void> _applyAndMark() async {
    if (!mounted) return;
    final info = await widget.api.getPersonalInfo();
    if (!mounted) return;

    final confirmed = await ProfileFillSheet.show(
      context,
      info: info,
      api: widget.api,
    );
    if (!confirmed) return;

    // Auto-copy all details to clipboard before opening browser.
    // Clipboard persists across apps on Android — user can paste
    // each field directly in the govt form without switching back.
    if (!info.isEmpty) {
      await Clipboard.setData(ClipboardData(text: _buildClipboardText(info)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.copy_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Details clipboard mein copy ho gaye! Form mein paste karo',
                style: TextStyle(fontWeight: FontWeight.w600),
              )),
            ]),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    final (applyUrl, _) = _resolveApply();
    AdService().showInterstitial();
    await _launchUrl(applyUrl);
    final success = await widget.api.saveJob(widget.userId, widget.jobId, 'applied');
    if (success && mounted) {
      setState(() { _isApplied = true; _isSaved = false; });
      _maybeRequestReview();
    }
  }

  String _buildClipboardText(PersonalInfo info) {
    final lines = <String>[];
    if (info.name.isNotEmpty) {
      lines.add('Name: ${info.name}');
      lines.add('Name (CAPS): ${info.name.toUpperCase()}');
    }
    if (info.fatherName.isNotEmpty) {
      lines.add("Father's Name: ${info.fatherName.toUpperCase()}");
    }
    if (info.motherName.isNotEmpty) lines.add("Mother's Name: ${info.motherName.toUpperCase()}");
    if (info.dob.isNotEmpty)        lines.add('Date of Birth: ${info.dob}');
    if (info.gender.isNotEmpty)     lines.add('Gender: ${info.gender}');
    if (info.category.isNotEmpty)   lines.add('Category: ${info.category}');
    if (info.phone.isNotEmpty)      lines.add('Mobile No.: ${info.phone}');
    if (info.email.isNotEmpty)      lines.add('Email: ${info.email}');
    if (info.address.isNotEmpty)    lines.add('Address: ${info.address}');
    if (info.district.isNotEmpty)   lines.add('District: ${info.district}');
    if (info.state.isNotEmpty)      lines.add('State: ${info.state}');
    if (info.pincode.isNotEmpty)    lines.add('Pincode: ${info.pincode}');
    return lines.join('\n');
  }

  // Show native in-app review after the 3rd job application.
  // Only prompts once per install (gated by SharedPrefs key).
  static const _kApplyCountKey   = 'apply_count_v1';
  static const _kRatingAskedKey  = 'rating_asked_v1';

  Future<void> _maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kRatingAskedKey) ?? false) return;
      final count = (prefs.getInt(_kApplyCountKey) ?? 0) + 1;
      await prefs.setInt(_kApplyCountKey, count);
      if (count < 3) return;
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        await prefs.setBool(_kRatingAskedKey, true);
      }
    } catch (_) {}
  }

  Future<void> _launchUrl(String rawUrl) async {
    // Three failure modes the original code silently ate:
    //  1. rawUrl is empty or malformed → Uri.parse may throw.
    //  2. canLaunchUrl returns false (no browser, intent blocked).
    //  3. launchUrl itself throws (rare, but happens with whatsapp:// etc).
    // Surface each via snackbar so the user knows their tap did *something*.
    final url = Uri.tryParse(rawUrl);
    if (url == null || rawUrl.isEmpty) {
      _showError("Couldn't open this link — URL is invalid");
      return;
    }
    try {
      if (!await canLaunchUrl(url)) {
        _showError('No app on this device can open the link');
        return;
      }
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showError("Couldn't open the link, please try again");
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _launchSourceUrl() async => _launchUrl(_job!.sourceUrl);

  // ── Local state (reminder flag + doc checkboxes) ──────────
  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final isReminder = prefs.getBool('$_kReminderPrefix${widget.jobId}') ?? false;
    final docsJson = prefs.getString('$_kDocsCheckedPfx${widget.jobId}');
    Map<String, bool> checkedDocs = {};
    if (docsJson != null) {
      try {
        final decoded = jsonDecode(docsJson) as Map<String, dynamic>;
        checkedDocs = decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }
    if (mounted) setState(() { _isReminderSet = isReminder; _checkedDocs = checkedDocs; });
  }

  Future<void> _toggleDoc(String doc) async {
    HapticFeedback.lightImpact();
    final updated = Map<String, bool>.from(_checkedDocs)..[doc] = !(_checkedDocs[doc] ?? false);
    setState(() => _checkedDocs = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kDocsCheckedPfx${widget.jobId}', jsonEncode(updated));
  }

  // ── Application Card (profile review without the apply flow) ─
  Future<void> _showApplicationCard() async {
    final info = await widget.api.getPersonalInfo();
    if (!mounted) return;
    await ProfileFillSheet.show(context, info: info, api: widget.api);
  }

  // ── Deadline Reminder sheet ───────────────────────────────
  void _showReminderSheet() {
    if (_job == null) return;
    HapticFeedback.lightImpact();
    final daysLeft = _job!.daysLeft;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Icon(Icons.notifications_outlined, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text('Deadline Reminder',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text(
              '${_job!.cleanTitle}\nLast date: ${_job!.lastDate}'
              '${daysLeft >= 0 ? " ($daysLeft din baaki)" : " (passed)"}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (daysLeft >= 3)
              _reminderOption(ctx, '3 din pehle remind karo', 'Alert 3 days before last date', 3, daysLeft),
            if (daysLeft >= 7)
              _reminderOption(ctx, '1 hafta pehle remind karo', 'Alert 7 days before last date', 7, daysLeft),
            _reminderOption(ctx, 'Last date ke din remind karo', 'Alert on the morning of last date', 0, daysLeft),
            if (_isReminderSet) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _cancelReminder();
                },
                icon: Icon(Icons.notifications_off_outlined, color: Colors.red[600], size: 16),
                label: Text('Reminder hatao', style: TextStyle(color: Colors.red[600])),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reminderOption(BuildContext ctx, String title, String sub,
      int daysBefore, int daysLeft) {
    final isDisabled = daysLeft < daysBefore || (daysLeft < 0);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withValues(alpha: 0.08)
              : AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.alarm_rounded,
            color: isDisabled ? Colors.grey[400] : AppColors.primary, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDisabled ? Colors.grey[400] : AppColors.textPrimary)),
      subtitle: Text(sub,
          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      trailing: isDisabled
          ? Text('Too late', style: TextStyle(fontSize: 11, color: Colors.grey[400]))
          : Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
      onTap: isDisabled ? null : () async {
        Navigator.pop(ctx);
        await _setReminder(daysBefore);
      },
    );
  }

  Future<void> _setReminder(int daysBefore) async {
    try {
      await NotificationService.scheduleJobReminder(
        jobId: widget.jobId,
        jobTitle: _job!.cleanTitle,
        daysLeft: _job!.daysLeft,
        daysBefore: daysBefore,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kReminderPrefix${widget.jobId}', true);
      if (mounted) {
        setState(() => _isReminderSet = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              daysBefore == 0
                  ? 'Reminder set! Last date ki subah alert aayega.'
                  : 'Reminder set! $daysBefore din pehle subah 9 baje alert aayega.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            )),
          ]),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      _showError('Reminder set nahi hua — baad mein try karo');
    }
  }

  Future<void> _cancelReminder() async {
    await NotificationService.cancelJobReminder(widget.jobId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kReminderPrefix${widget.jobId}', false);
    if (mounted) setState(() => _isReminderSet = false);
  }
}
