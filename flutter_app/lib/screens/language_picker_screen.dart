// lib/screens/language_picker_screen.dart
//
// Three-option picker for app UI language. Hinglish is the default and
// matches the existing copy, Hindi for users who prefer Devanagari labels,
// English for power users.
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/i18n.dart';

class LanguagePickerScreen extends StatefulWidget {
  const LanguagePickerScreen({super.key});

  @override
  State<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}

class _LanguagePickerScreenState extends State<LanguagePickerScreen> {
  String _selected = L10n.current;

  Future<void> _pick(String code) async {
    setState(() => _selected = code);
    await L10n.setLanguage(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Language updated. Restart app to fully apply.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(L10n.tr('profile_language'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RadioGroup<String>(
        groupValue: _selected,
        onChanged: (v) => _pick(v ?? 'hinglish'),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: L10n.supported.entries.map((e) {
          final selected = _selected == e.key;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: RadioListTile<String>(
              value: e.key,
              activeColor: AppColors.primary,
              title: Text(e.value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text(_subtitleFor(e.key),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }

  String _subtitleFor(String code) {
    switch (code) {
      case 'hi':       return 'Devanagari labels — fully Hindi UI';
      case 'en':       return 'English-only labels';
      default:         return 'Mixed Hindi + English (current default)';
    }
  }
}
