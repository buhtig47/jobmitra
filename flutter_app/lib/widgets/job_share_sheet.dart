// lib/widgets/job_share_sheet.dart
//
// Branded share-as-image card. Text shares get skimmed past in WhatsApp
// groups; a branded image card stands out, and every share carries the
// Play Store link — turning users into an install funnel.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../utils/constants.dart';

Future<void> showJobShareSheet(BuildContext context, Job job) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _JobShareSheet(job: job),
  );
}

class _JobShareSheet extends StatefulWidget {
  final Job job;
  const _JobShareSheet({required this.job});

  @override
  State<_JobShareSheet> createState() => _JobShareSheetState();
}

class _JobShareSheetState extends State<_JobShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  String get _caption =>
      '🇮🇳 *${widget.job.cleanTitle}*\n'
      '📅 Last Date: ${widget.job.lastDate}\n\n'
      'Details: ${widget.job.sourceUrl}\n'
      '📲 Sarkari naukri alerts FREE: $kPlayStoreUrl';

  String get _textMessage =>
      '🇮🇳 *Govt Job Alert!*\n\n'
      '*${widget.job.cleanTitle}*\n'
      '${widget.job.cleanDepartment}\n\n'
      '📋 Vacancies: ${widget.job.vacanciesText}\n'
      '📅 Last Date: ${widget.job.lastDate}\n'
      '💰 Fee: ${widget.job.feeText}\n\n'
      'Details: ${widget.job.sourceUrl}\n\n'
      '📲 _JobMitra app — apni eligible sarkari naukri track karo (FREE):_\n'
      '$kPlayStoreUrl';

  Future<void> _shareAsImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/jobmitra_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: _caption);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Image capture failed (rare) — fall back to text share so the
      // user's tap still does something.
      await Share.share(_textMessage);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareAsText() async {
    final waUrl = Uri.parse(
        'whatsapp://send?text=${Uri.encodeComponent(_textMessage)}');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl);
    } else {
      await Share.share(_textMessage);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Share Job',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            // Preview — this exact widget is captured as the share image.
            RepaintBoundary(
              key: _cardKey,
              child: _ShareCard(job: widget.job),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _shareAsImage,
                    icon: _sharing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.image_rounded, size: 18),
                    label: const Text('Image Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareAsText,
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Text Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final Job job;
  const _ShareCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final urgent = job.daysLeft >= 0 && job.daysLeft <= 7;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF0D4A28)],
              ),
            ),
            child: const Row(
              children: [
                Text('🇮🇳', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text('JobMitra',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
                Spacer(),
                Text('Sarkari Naukri Alert',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.cleanTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(job.cleanDepartment,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Fact(icon: '📋', label: 'Vacancies', value: job.vacanciesText),
                    const SizedBox(width: 10),
                    _Fact(icon: '💰', label: 'Fee', value: job.feeText),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Fact(
                      icon: '📅', label: 'Last Date', value: job.lastDate,
                      valueColor: urgent ? const Color(0xFFC62828) : null,
                    ),
                    if (urgent) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            job.daysLeft == 0
                                ? '⏰ Aaj last date!'
                                : '⏰ ${job.daysLeft} din bache!',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC62828)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Install-funnel footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            color: AppColors.accent.withValues(alpha: 0.12),
            child: const Row(
              children: [
                Icon(Icons.android_rounded, size: 15, color: AppColors.primary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'JobMitra — Play Store par FREE  •  play.google.com',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String icon, label, value;
  final Color? valueColor;
  const _Fact({
    required this.icon, required this.label, required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 9.5, color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? const Color(0xFF1A1A1A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
