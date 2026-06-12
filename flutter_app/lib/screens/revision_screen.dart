// lib/screens/revision_screen.dart
//
// Revision Center — the "learn from your mistakes" loop:
//   • Galtiyan: every wrong answer from Daily Quiz / Mock Tests, practised
//     until answered correctly twice (then retired as "mastered").
//   • Bookmarks: questions the user starred, practisable the same way.
//   • Report: topic-wise accuracy, weakest first.
// Questions without explanations get a Gemini-backed "AI se samjho" button.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/practice_store.dart';
import '../utils/constants.dart';
import '../widgets/banner_ad_widget.dart';

class RevisionScreen extends StatefulWidget {
  final ApiService api;
  const RevisionScreen({super.key, required this.api});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<MistakeItem> _mistakes = [];
  List<MistakeItem> _bookmarks = [];
  List<TopicStat> _topics = [];
  int _mastered = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final mistakes = await PracticeStore.mistakes();
    final topics = await PracticeStore.topicStats();
    final mastered = await PracticeStore.masteredCount();
    final bookmarks = await _loadBookmarks();
    if (!mounted) return;
    setState(() {
      _mistakes = mistakes;
      _topics = topics;
      _mastered = mastered;
      _bookmarks = bookmarks;
      _loading = false;
    });
  }

  // Bookmarks were already being saved by quiz/mock screens — this is the
  // first UI that actually lets the user practise them.
  Future<List<MistakeItem>> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('quiz_bookmarks_data_v1') ?? const [];
    final out = <MistakeItem>[];
    for (final s in raw) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(s) as Map);
        out.add(MistakeItem(
          id: (m['id'] as String?) ?? '',
          question: (m['q'] as String?) ?? '',
          options: List<String>.from((m['opts'] as List?) ?? const []),
          answer: (m['ans'] as int?) ?? 0,
          explanation: (m['exp'] as String?) ?? '',
          source: (m['src'] as String?) ?? 'quiz',
        ));
      } catch (_) {}
    }
    return out.where((b) => b.question.isNotEmpty && b.options.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Revision Center',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Galtiyan (${_mistakes.length})'),
            Tab(text: 'Bookmarks (${_bookmarks.length})'),
            const Tab(text: 'Report'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _mistakesTab(),
                _bookmarksTab(),
                _reportTab(),
              ],
            ),
    );
  }

  // ── Tab 1: Mistakes ────────────────────────────────────────────────

  Widget _mistakesTab() {
    if (_mistakes.isEmpty) {
      return _emptyState(
        emoji: '🎯',
        title: _mastered > 0
            ? 'Saari galtiyan master ho gayi!'
            : 'Abhi koi galti nahi',
        subtitle: _mastered > 0
            ? '$_mastered questions master kiye — keep going!'
            : 'Quiz ya Mock Test mein galat jawab yahan practice ke liye aayenge',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Har question 2 baar sahi karo — master ho jayega',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              if (_mastered > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('🏆 $_mastered mastered',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _mistakes.length,
            itemBuilder: (_, i) => _PracticeCard(
              key: ValueKey(_mistakes[i].id),
              item: _mistakes[i],
              api: widget.api,
              isMistake: true,
              onResult: (id, correct) async {
                final retired =
                    await PracticeStore.recordRevisionAnswer(id, correct);
                if (retired && mounted) {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('🏆 Master ho gaya! Deck se hata diya'),
                    duration: Duration(seconds: 2),
                  ));
                  _load();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Bookmarks ───────────────────────────────────────────────

  Widget _bookmarksTab() {
    if (_bookmarks.isEmpty) {
      return _emptyState(
        emoji: '🔖',
        title: 'Koi bookmark nahi',
        subtitle:
            'Quiz ya Mock Test mein 🔖 icon dabao — question yahan practice ke liye milega',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (_, i) => _PracticeCard(
        key: ValueKey('bm_${_bookmarks[i].id}_$i'),
        item: _bookmarks[i],
        api: widget.api,
        isMistake: false,
        onResult: (_, __) async {},
      ),
    );
  }

  // ── Tab 3: Topic report ────────────────────────────────────────────

  Widget _reportTab() {
    final withSignal = _topics.where((t) => t.attempted >= 3).toList();
    if (withSignal.isEmpty) {
      return _emptyState(
        emoji: '📊',
        title: 'Abhi data nahi',
        subtitle:
            'Quiz aur Mock Tests practice karo — topic-wise report yahan banegi',
      );
    }
    final weak = withSignal.where((t) => t.accuracy < 0.6).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (weak.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Focus karo: ${weak.take(3).map((t) => t.topic).join(', ')}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8D6E63)),
                  ),
                ),
              ],
            ),
          ),
        ...withSignal.map(_topicRow),
        const SizedBox(height: 12),
        const BannerAdWidget(),
      ],
    );
  }

  Widget _topicRow(TopicStat t) {
    final pct = (t.accuracy * 100).round();
    final color = t.accuracy < 0.4
        ? const Color(0xFFD32F2F)
        : t.accuracy < 0.6
            ? const Color(0xFFE65100)
            : const Color(0xFF2E7D32);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.topic,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text('$pct%',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t.accuracy,
              minHeight: 6,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text('${t.correct}/${t.attempted} sahi',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _emptyState(
      {required String emoji, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ── Practice card: tap an option → instant feedback → explanation ──────

class _PracticeCard extends StatefulWidget {
  final MistakeItem item;
  final ApiService api;
  final bool isMistake;
  final Future<void> Function(String id, bool correct) onResult;
  const _PracticeCard({
    super.key,
    required this.item,
    required this.api,
    required this.isMistake,
    required this.onResult,
  });

  @override
  State<_PracticeCard> createState() => _PracticeCardState();
}

class _PracticeCardState extends State<_PracticeCard> {
  int _selected = -1;
  bool get _answered => _selected >= 0;
  String? _aiExplanation;
  bool _aiLoading = false;

  Future<void> _explainWithAI() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);
    final text = await widget.api.explainQuestion(
      question: widget.item.question,
      options: widget.item.options,
      answer: widget.item.answer,
    );
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiExplanation = text ?? 'AI abhi available nahi — baad mein try karo';
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final explanation =
        item.explanation.isNotEmpty ? item.explanation : _aiExplanation;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.topic.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.topic,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              const Spacer(),
              if (widget.isMistake)
                Text(
                  item.wins > 0
                      ? '✓ ${item.wins}/${PracticeStore.masteryWins}'
                      : '${item.fails}x galat',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.wins > 0
                          ? const Color(0xFF2E7D32)
                          : Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.question,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.45)),
          const SizedBox(height: 12),
          ...List.generate(item.options.length, (i) {
            final isCorrect = i == item.answer;
            Color border = const Color(0xFFE0E0E0);
            Color bg = Colors.white;
            if (_answered) {
              if (isCorrect) {
                border = const Color(0xFF2E7D32);
                bg = const Color(0xFFE8F5E9);
              } else if (i == _selected) {
                border = const Color(0xFFD32F2F);
                bg = const Color(0xFFFFEBEE);
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _answered
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() => _selected = i);
                        widget.onResult(item.id, i == item.answer);
                      },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border, width: 1.4),
                  ),
                  child: Row(
                    children: [
                      Text('${String.fromCharCode(65 + i)}. ',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Text(item.options[i],
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                      if (_answered && isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: Color(0xFF2E7D32)),
                      if (_answered && !isCorrect && i == _selected)
                        const Icon(Icons.cancel_rounded,
                            size: 18, color: Color(0xFFD32F2F)),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_answered) ...[
            const SizedBox(height: 4),
            if (explanation != null && explanation.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_aiExplanation != null ? '🤖 AI Samjhata Hai' : '💡 Explanation',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(explanation,
                        style: const TextStyle(fontSize: 12.5, height: 1.5)),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _aiLoading ? null : _explainWithAI,
                  icon: _aiLoading
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(_aiLoading ? 'AI soch raha hai…' : 'AI se samjho'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
