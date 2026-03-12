// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // User data being collected
  String? _selectedState;
  String? _selectedEducation;
  String? _selectedCategory;
  int     _selectedAge = 25;
  final   Set<String> _selectedJobTypes = {};
  bool    _isLoading = false;

  final _api = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressBar(),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildStatePage(),
                  _buildEducationPage(),
                  _buildAgeCategoryPage(),
                  _buildJobTypesPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(5, (i) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i <= _currentPage ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
    );
  }

  // ─── PAGE 1: Welcome ───
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🇮🇳', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          Text(
            'JobMitra',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sirf aapke liye waali\nSarkari Naukri alerts',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary, height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          _buildFeatureRow('🎯', 'Sirf eligible jobs dikhayega'),
          const SizedBox(height: 16),
          _buildFeatureRow('⏰', 'Deadline pe remind karega'),
          const SizedBox(height: 16),
          _buildFeatureRow('📋', 'Documents checklist bhi dega'),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Shuru Karein →'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  // ─── PAGE 2: State ───
  Widget _buildStatePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Aap kahan se hain?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text('State ke hisab se state jobs dikhayenge',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
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
          ElevatedButton(
            onPressed: _selectedState != null ? _nextPage : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: const Text('Aage →'),
          ),
        ],
      ),
    );
  }

  // ─── PAGE 3: Education ───
  Widget _buildEducationPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Aapki padhai?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text('Iske hisab se eligible jobs filter karenge',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          ...EducationLevels.all.map((edu) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _selectedEducation = edu['key']),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedEducation == edu['key']
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.cardBg,
                  border: Border.all(
                    color: _selectedEducation == edu['key']
                        ? AppColors.primary : AppColors.divider,
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
          const Spacer(),
          ElevatedButton(
            onPressed: _selectedEducation != null ? _nextPage : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: const Text('Aage →'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── PAGE 4: Age + Category ───
  Widget _buildAgeCategoryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Thoda aur batao',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),

          // Age Slider
          Text('Aapki umar: $_selectedAge saal',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            value: _selectedAge.toDouble(),
            min: 18, max: 45, divisions: 27,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _selectedAge = v.round()),
          ),
          const SizedBox(height: 24),

          // Category
          Text('Aapki category:',
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
            ],
          ),

          // Info box
          if (_selectedCategory != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _selectedCategory == 'sc' || _selectedCategory == 'st'
                    ? '✅ Aapko most jobs mein fee nahi lagegi!'
                    : _selectedCategory == 'obc'
                    ? '✅ Aapko fees mein relaxation milega'
                    : 'ℹ️ Age relaxation OBC/SC/ST ko milta hai',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _selectedCategory != null ? _nextPage : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: const Text('Aage →'),
          ),
        ],
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

  // ─── PAGE 5: Job Types ───
  Widget _buildJobTypesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Kaunsi jobs chahiye?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text('Ek ya zyada choose karo (sab bhi le sakte ho)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
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
                  if (selected) _selectedJobTypes.remove(cat['key']);
                  else          _selectedJobTypes.add(cat['key']!);
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.12) : AppColors.cardBg,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cat['icon']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        cat['label']!,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                          color: selected ? AppColors.primary : AppColors.textPrimary,
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
          ElevatedButton(
            onPressed: _selectedJobTypes.isNotEmpty ? _submitProfile : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: _isLoading ? AppColors.textHint : AppColors.primary,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('JobMitra Start Karo! 🚀'),
          ),
          const SizedBox(height: 16),
        ],
      ),
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

  // ─── NAVIGATION ───
  void _nextPage() {
    setState(() => _currentPage++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);

    final profile = UserProfile(
      fcmToken:  'token_${DateTime.now().millisecondsSinceEpoch}', // Replace with real FCM token
      state:     _selectedState!,
      education: _selectedEducation!,
      category:  _selectedCategory!,
      age:       _selectedAge,
      jobTypes:  _selectedJobTypes.toList(),
    );

    final userId = await _api.registerUser(profile);

    if (userId != null && mounted) {
      // Mark onboarding done
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(userId: userId)),
      );
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error hua, dobara try karo')),
        );
      }
    }
  }
}
