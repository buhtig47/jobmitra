// lib/widgets/profile_fill_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../screens/personal_info_screen.dart';

class ProfileFillSheet extends StatelessWidget {
  final PersonalInfo info;
  final ApiService   api;

  const ProfileFillSheet({super.key, required this.info, required this.api});

  // Returns true when user taps "Open Form"
  static Future<bool> show(
    BuildContext context, {
    required PersonalInfo info,
    required ApiService api,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileFillSheet(info: info, api: api),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: info.isEmpty ? 0.45 : 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.35,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Drag handle ──
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),

            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Application Card',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('Tap Copy → paste in govt form fields',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Progress badge
                  if (!info.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${info.filledCount}/11 filled',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: info.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        _buildGroup(context, '👤 Personal', [
                          if (info.name.isNotEmpty) ...[
                            _row(context, 'Name',         info.name),
                            _row(context, 'Name (CAPS)',  info.name.toUpperCase()),
                          ],
                          if (info.fatherName.isNotEmpty) ...[
                            _row(context, 'Father',       info.fatherName),
                            _row(context, 'Father (CAPS)',info.fatherName.toUpperCase()),
                          ],
                          if (info.motherName.isNotEmpty)
                            _row(context, 'Mother',       info.motherName),
                          if (info.dob.isNotEmpty)
                            _row(context, 'DOB',          info.dob),
                          if (info.gender.isNotEmpty)
                            _row(context, 'Gender',       info.gender),
                          if (info.category.isNotEmpty) ...[
                            _row(context, 'Category',     info.category),
                            // OBC-NCL is also written as OBC on some portals
                            if (info.category == 'OBC-NCL')
                              _row(context, 'Category (alt)', 'OBC'),
                          ],
                        ]),
                        _buildGroup(context, '📞 Contact', [
                          if (info.phone.isNotEmpty) _row(context, 'Mobile', info.phone),
                          if (info.email.isNotEmpty) _row(context, 'Email',  info.email),
                        ]),
                        _buildGroup(context, '🏠 Address', [
                          if (info.address.isNotEmpty)  _row(context, 'Address', info.address),
                          if (info.district.isNotEmpty) _row(context, 'District', info.district),
                          if (info.state.isNotEmpty)    _row(context, 'State',    info.state),
                          if (info.pincode.isNotEmpty)  _row(context, 'Pincode',  info.pincode),
                        ]),
                        if (info.aadharLast4.isNotEmpty)
                          _buildGroup(context, '🪪 Identity', [
                            _row(context, 'Aadhar (last 4)', info.aadharLast4),
                          ]),
                        const SizedBox(height: 8),
                        // Clipboard hint
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A6B3C).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1A6B3C).withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            children: [
                              Text('💡', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '"Portal Kholo" tap karte hi saari details clipboard mein copy ho jaayengi. Form mein field touch karo → Paste',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Edit details link
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PersonalInfoScreen(api: api),
                            ));
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit Details'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
            ),

            // ── Bottom buttons ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  // Dismiss button
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Baad Mein', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  // Open form button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                      label: const Text('Portal Kholo →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // SingleChildScrollView prevents RenderFlex overflow on small screens
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📝', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Form Details Nahi Hain',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Apna naam, DOB, category aadi fill karo. Fir ek tap se copy karke form bhar sakte ho.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PersonalInfoScreen(api: api),
                ));
                Navigator.pop(context, false);
              },
              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
              label: const Text('Fill Details', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$label" copy ho gaya!',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Copy',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
