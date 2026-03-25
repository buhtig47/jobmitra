// lib/screens/profile_edit_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ProfileEditScreen extends StatefulWidget {
  final ApiService api;
  final int userId;

  const ProfileEditScreen({
    super.key,
    required this.api,
    required this.userId,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedState;
  String? _selectedEducation;
  String? _selectedCategory;
  int _selectedAge = 25;
  final Set<String> _selectedJobTypes = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.api.getSavedProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedState     = profile.state.isNotEmpty     ? profile.state     : null;
        _selectedEducation = profile.education.isNotEmpty ? profile.education : null;
        _selectedCategory  = profile.category.isNotEmpty  ? profile.category  : null;
        _selectedAge       = profile.age;
        _selectedJobTypes
          ..clear()
          ..addAll(profile.jobTypes);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_selectedState == null ||
        _selectedEducation == null ||
        _selectedCategory == null ||
        _selectedJobTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields first!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Build the updated profile
    final prefs = await SharedPreferences.getInstance();
    final existingStr = prefs.getString('user_profile');
    final existingFcmToken = existingStr != null
        ? (jsonDecode(existingStr)['fcm_token'] as String? ?? '')
        : '';

    final newProfile = UserProfile(
      fcmToken:  existingFcmToken,
      state:     _selectedState!,
      education: _selectedEducation!,
      category:  _selectedCategory!,
      age:       _selectedAge,
      jobTypes:  _selectedJobTypes.toList(),
    );

    // updateProfile calls API and saves to SharedPreferences
    final success = await widget.api.updateProfile(widget.userId, newProfile);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated! ✅'),
          backgroundColor: AppColors.primary,
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Save failed — check your network'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text(
                'Edit Profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── State Section ──
          _buildSectionHeader('Where are you from?', 'Jobs will be filtered by your state'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: IndianStates.all.map((state) => _buildSelectChip(
              label: state,
              isSelected: _selectedState == state,
              onTap: () => setState(() => _selectedState = state),
            )).toList(),
          ),

          const SizedBox(height: 32),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 24),

          // ── Education Section ──
          _buildSectionHeader('Your Education', 'We\'ll filter eligible jobs based on this'),
          const SizedBox(height: 16),
          ...EducationLevels.all.map((edu) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _selectedEducation = edu['key']),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedEducation == edu['key']
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.cardBg,
                  border: Border.all(
                    color: _selectedEducation == edu['key']
                        ? AppColors.primary
                        : AppColors.divider,
                    width: _selectedEducation == edu['key'] ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(edu['label']!, style: Theme.of(context).textTheme.bodyLarge),
                    const Spacer(),
                    if (_selectedEducation == edu['key'])
                      const Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          )),

          const SizedBox(height: 8),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 24),

          // ── Age Slider ──
          _buildSectionHeader('A Little More', ''),
          const SizedBox(height: 16),
          Text(
            'Your age: $_selectedAge years',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Slider(
            value: _selectedAge.toDouble(),
            min: 18,
            max: 45,
            divisions: 27,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _selectedAge = v.round()),
          ),

          const SizedBox(height: 24),

          // ── Category ──
          Text(
            'Your category:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCategoryOption('general', 'General'),
              const SizedBox(width: 8),
              _buildCategoryOption('obc', 'OBC'),
              const SizedBox(width: 8),
              _buildCategoryOption('sc', 'SC'),
              const SizedBox(width: 8),
              _buildCategoryOption('st', 'ST'),
              const SizedBox(width: 8),
              _buildCategoryOption('ews', 'EWS'),
            ],
          ),

          if (_selectedCategory != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _selectedCategory == 'sc' || _selectedCategory == 'st'
                    ? '✅ No application fee in most jobs for you!'
                    : _selectedCategory == 'obc'
                        ? '✅ You are eligible for fee relaxation'
                        : 'ℹ️ Age relaxation is available for OBC/SC/ST',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 24),

          // ── Job Types ──
          _buildSectionHeader(
            'Which job types interest you?',
            'Choose one or more (you can select all)',
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: JobCategories.all.map((cat) {
              final selected = _selectedJobTypes.contains(cat['key']);
              return InkWell(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedJobTypes.remove(cat['key']);
                  } else {
                    _selectedJobTypes.add(cat['key'] as String);
                  }
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.cardBg,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cat['icon'] as String,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        cat['label'] as String,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.normal,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // ── Save Button ──
          ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppColors.primary,
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildSelectChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBg,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOption(String key, String label) {
    final selected = _selectedCategory == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.cardBg,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
