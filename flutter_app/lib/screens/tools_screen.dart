// lib/screens/tools_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'salary_calculator_screen.dart';
import 'exam_calendar_screen.dart';
import 'competition_screen.dart';
import 'career_roadmap_screen.dart';
import 'dept_profiles_screen.dart';
import 'current_affairs_screen.dart';
import 'mock_test_screen.dart';
import 'age_calculator_screen.dart';
import 'daily_quiz_screen.dart';

class ToolsScreen extends StatelessWidget {
  final ApiService api;
  const ToolsScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🛠️ Tools', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Salary, GK Quiz, eligibility, roadmap — all in one place', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Tool cards ──
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 4),
                _buildSectionLabel('💰 Finance'),
                const SizedBox(height: 10),
                _ToolCard(
                  emoji: '💰',
                  title: 'Salary Calculator',
                  subtitle: '7th CPC in-hand salary — levels 1–18, tax, DA, 5-yr growth',
                  color: const Color(0xFF2E7D32),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SalaryCalculatorScreen())),
                ),
                const SizedBox(height: 12),
                _ToolCard(
                  emoji: '🎂',
                  title: 'Age Eligibility Calculator',
                  subtitle: 'Check if you qualify — UPSC, SSC, RRB, Banking by category',
                  color: const Color(0xFF6A1B9A),
                  tag: 'New!',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AgeCalculatorScreen())),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel('📚 Practice'),
                const SizedBox(height: 10),
                _ToolCard(
                  emoji: '🧠',
                  title: 'Daily GK Quiz',
                  subtitle: '5 questions every day — streak, score, 60-day rotation',
                  color: const Color(0xFF4A148C),
                  tag: 'Daily!',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DailyQuizScreen(api: api))),
                ),
                const SizedBox(height: 12),
                _ToolCard(
                  emoji: '📝',
                  title: 'Mock Tests',
                  subtitle: 'SSC, RRB, Banking, UPSC — 185 PYQ-based questions',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => MockTestScreen(api: api))),
                ),
                const SizedBox(height: 12),
                _ToolCard(
                  emoji: '📰',
                  title: 'Daily Current Affairs',
                  subtitle: 'Auto-updated twice daily — polity, economy, science',
                  color: const Color(0xFFE65100),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CurrentAffairsScreen(api: api))),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel('📅 Planning'),
                const SizedBox(height: 10),
                _ToolCard(
                  emoji: '🗓️',
                  title: 'Exam Calendar',
                  subtitle: 'UPSC, SSC, Banking, Railway — 2025-26 important dates',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ExamCalendarScreen())),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel('📊 Analysis'),
                const SizedBox(height: 10),
                _ToolCard(
                  emoji: '⚔️',
                  title: 'Competition Analysis',
                  subtitle: 'How many candidates per post? See your real odds',
                  color: const Color(0xFFB71C1C),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CompetitionScreen())),
                ),
                const SizedBox(height: 12),
                _ToolCard(
                  emoji: '🗺️',
                  title: 'Career Roadmap',
                  subtitle: 'Best exam path based on your age & qualification',
                  color: const Color(0xFF4A148C),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CareerRoadmapScreen(api: api))),
                ),
                const SizedBox(height: 12),
                _ToolCard(
                  emoji: '🏢',
                  title: 'Department Profiles',
                  subtitle: 'DRDO, ISRO, Railways, Banks — salary & perks',
                  color: const Color(0xFF1A237E),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DeptProfilesScreen())),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel('🚀 Coming Soon'),
                const SizedBox(height: 10),
                _ToolCard(
                  emoji: '🤖',
                  title: 'AI Job Match',
                  subtitle: 'AI tells you which jobs fit your profile best',
                  color: const Color(0xFF00695C),
                  comingSoon: true,
                  onTap: () => _showComingSoon(context, 'AI Job Match'),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSecondary));
  }

  void _showComingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name — coming soon!', style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String       emoji;
  final String       title;
  final String       subtitle;
  final Color        color;
  final String?      tag;
  final bool         comingSoon;
  final VoidCallback onTap;

  const _ToolCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.tag,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              // Color side bar
              Container(
                width: 6,
                height: 80,
                color: comingSoon ? Colors.grey[300] : color,
              ),
              const SizedBox(width: 16),
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: (comingSoon ? Colors.grey : color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: comingSoon ? Colors.grey[400] : AppColors.textPrimary)),
                          if (tag != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                              child: Text(tag!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ],
                          if (comingSoon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                              child: Text('Soon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: comingSoon ? Colors.grey[400] : AppColors.textSecondary, height: 1.3)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.chevron_right_rounded, color: comingSoon ? Colors.grey[300] : color.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
