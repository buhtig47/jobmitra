// lib/widgets/job_card.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../utils/constants.dart';

class JobCard extends StatefulWidget {
  final Job job;
  final VoidCallback onTap;
  final UserProfile? profile; // optional — shows eligibility badge

  const JobCard({super.key, required this.job, required this.onTap, this.profile});

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
    )..value = 1.0;
    _scaleAnim = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.reverse();
  void _onTapUp(_) { _controller.forward(); widget.onTap(); }
  void _onTapCancel() => _controller.forward();

  Future<void> _shareJob(Job job) async {
    final msg =
        '🇮🇳 *Govt Job Alert!*\n\n'
        '*${job.cleanTitle}*\n'
        '${job.cleanDepartment}\n\n'
        '📋 Vacancies: ${job.vacanciesText}\n'
        '📅 Last Date: ${job.lastDate}\n'
        '💰 Fee: ${job.feeText}\n\n'
        'Details: ${job.sourceUrl}\n\n'
        '_From JobMitra — track your eligible govt jobs!_';
    final waUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl);
    } else {
      Share.share(msg);
    }
  }

  Color get _categoryColor => JobCategoryColors.colorFor(widget.job.category);

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final catColor = _categoryColor;
    final score = widget.profile != null ? job.matchScore(widget.profile!) : -1;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Radii.cardLg),
            boxShadow: [
              BoxShadow(
                color: catColor.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.cardLg),
            // Left-edge category bar feels more "premium" than the old
            // top-gradient strip; also lets the title start higher in the card.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: catColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: category pill + deadline + match badge
                          Row(
                            children: [
                              _CategoryPill(job: job, color: catColor),
                              const SizedBox(width: 6),
                              if (score >= 3)
                                _MatchBadge(score: score),
                              const Spacer(),
                              _DeadlinePill(job: job),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            job.cleanTitle,
                            style: AppText.h2(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (job.cleanDepartment.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.account_balance_outlined,
                                    size: 13, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    job.cleanDepartment,
                                    style: AppText.caption(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          const SizedBox(height: 10),
                          // Metadata grid — two facts left, two action buttons right.
                          Row(
                            children: [
                              _StatChip(
                                icon: Icons.people_outline,
                                label: job.vacanciesText,
                                color: job.vacancies > 0
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              _StatChip(
                                icon: Icons.currency_rupee,
                                label: job.feeText,
                                color: job.isFree
                                    ? const Color(0xFF2E7D32)
                                    : job.fee < 0
                                        ? Colors.grey
                                        : const Color(0xFF1565C0),
                              ),
                              const Spacer(),
                              _IconAction(
                                icon: Icons.share_rounded,
                                color: catColor,
                                onTap: () => _shareJob(job),
                                tooltip: 'Share',
                              ),
                              const SizedBox(width: 6),
                              _IconAction(
                                icon: Icons.arrow_forward_rounded,
                                color: catColor,
                                solid: true,
                                onTap: widget.onTap,
                                tooltip: 'View',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final bool solid;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = solid ? color : color.withValues(alpha: 0.10);
    final fg = solid ? Colors.white : color;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 36, height: 36,
            child: Icon(icon, size: 18, color: fg),
          ),
        ),
      ),
    );
  }
}

// ── Eligibility match badge ──────────────────────────────
class _MatchBadge extends StatelessWidget {
  final int score; // 0-4
  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    if (score == 4) {
      bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32);
      label = '✓ Perfect';
    } else {
      bg = const Color(0xFFFFF3E0); fg = const Color(0xFFE65100);
      label = '$score/4 match';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final Job job;
  final Color color;
  const _CategoryPill({required this.job, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(job.categoryEmoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            job.categoryLabel,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _DeadlinePill extends StatelessWidget {
  final Job job;
  const _DeadlinePill({required this.job});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    IconData icon;
    switch (job.urgency) {
      case 'red':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFD32F2F);
        icon = Icons.warning_amber_rounded;
        break;
      case 'yellow':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFE65100);
        icon = Icons.access_time_rounded;
        break;
      default:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(job.urgencyText,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
