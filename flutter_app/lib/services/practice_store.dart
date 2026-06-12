// lib/services/practice_store.dart
//
// Local learning engine behind the Revision Center.
//
// Two stores, both SharedPreferences-backed:
//  1. Mistakes deck — every wrongly-answered question (quiz + mock) lands
//     here. Answering it correctly TWICE in revision retires it ("mastered").
//     Lightweight spaced repetition: fails push a question back to the front,
//     wins push it toward retirement.
//  2. Topic stats — attempted/correct per topic across all practice, powering
//     the weak-area report ("Polity 40% — focus karo").
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MistakeItem {
  final String id;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  final String topic;
  final String source; // 'quiz' | 'mock'
  int fails;
  int wins;

  MistakeItem({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
    this.explanation = '',
    this.topic = '',
    this.source = 'quiz',
    this.fails = 1,
    this.wins = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'q': question, 'opts': options, 'ans': answer,
        'exp': explanation, 'topic': topic, 'src': source,
        'fails': fails, 'wins': wins,
      };

  static MistakeItem? fromJson(Map<String, dynamic> m) {
    try {
      return MistakeItem(
        id: m['id'] as String,
        question: m['q'] as String,
        options: List<String>.from(m['opts'] as List),
        answer: m['ans'] as int,
        explanation: (m['exp'] as String?) ?? '',
        topic: (m['topic'] as String?) ?? '',
        source: (m['src'] as String?) ?? 'quiz',
        fails: (m['fails'] as int?) ?? 1,
        wins: (m['wins'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class TopicStat {
  final String topic;
  final int attempted;
  final int correct;
  const TopicStat(this.topic, this.attempted, this.correct);
  double get accuracy => attempted == 0 ? 0 : correct / attempted;
}

class PracticeStore {
  static const _kMistakes = 'prep_mistakes_v1';
  static const _kTopics   = 'prep_topic_stats_v1';
  static const _kMastered = 'prep_mastered_count_v1';
  // Wins needed in revision before a mistake is retired.
  static const masteryWins = 2;
  // Deck cap — oldest retired first so storage can't grow unbounded.
  static const _maxDeck = 200;

  // ── Recording (called from quiz / mock answer handlers) ─────────────

  /// Record an answer given during a NORMAL quiz/mock session.
  /// Wrong → question joins the mistakes deck. Topic stats always update.
  static Future<void> recordAnswer({
    required String id,
    required String question,
    required List<String> options,
    required int answer,
    required bool correct,
    String explanation = '',
    String topic = '',
    String source = 'quiz',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _bumpTopic(prefs, topic, correct);
    if (correct) return;

    final deck = await _loadDeck(prefs);
    final key = id.isNotEmpty ? id : 'h${question.hashCode}';
    final existing = deck.indexWhere((m) => m.id == key);
    if (existing >= 0) {
      deck[existing].fails++;
      deck[existing].wins = 0; // wrong again — restart mastery
      // Move repeated offenders to the front of the deck.
      final item = deck.removeAt(existing);
      deck.insert(0, item);
    } else {
      deck.insert(
        0,
        MistakeItem(
          id: key, question: question, options: options, answer: answer,
          explanation: explanation, topic: topic, source: source,
        ),
      );
      if (deck.length > _maxDeck) deck.removeRange(_maxDeck, deck.length);
    }
    await _saveDeck(prefs, deck);
  }

  /// Record an answer given inside REVISION practice.
  /// Two consecutive wins retire the question. Returns true if retired now.
  static Future<bool> recordRevisionAnswer(String id, bool correct) async {
    final prefs = await SharedPreferences.getInstance();
    final deck = await _loadDeck(prefs);
    final i = deck.indexWhere((m) => m.id == id);
    if (i < 0) return false;
    await _bumpTopic(prefs, deck[i].topic, correct);
    bool retired = false;
    if (correct) {
      deck[i].wins++;
      if (deck[i].wins >= masteryWins) {
        deck.removeAt(i);
        retired = true;
        await prefs.setInt(
            _kMastered, (prefs.getInt(_kMastered) ?? 0) + 1);
      }
    } else {
      deck[i].fails++;
      deck[i].wins = 0;
      final item = deck.removeAt(i);
      deck.insert(0, item);
    }
    await _saveDeck(prefs, deck);
    return retired;
  }

  // ── Reads ────────────────────────────────────────────────────────────

  static Future<List<MistakeItem>> mistakes() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadDeck(prefs);
  }

  static Future<int> masteredCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMastered) ?? 0;
  }

  /// Topic stats sorted weakest-first (min 3 attempts to count as a signal).
  static Future<List<TopicStat>> topicStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTopics);
    if (raw == null) return const [];
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final stats = <TopicStat>[];
      map.forEach((topic, v) {
        final m = Map<String, dynamic>.from(v as Map);
        stats.add(TopicStat(topic, (m['a'] as int?) ?? 0, (m['c'] as int?) ?? 0));
      });
      stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));
      return stats;
    } catch (_) {
      return const [];
    }
  }

  // ── Internals ────────────────────────────────────────────────────────

  static Future<void> _bumpTopic(
      SharedPreferences prefs, String topic, bool correct) async {
    final t = topic.trim().isEmpty ? 'General' : topic.trim();
    Map<String, dynamic> map = {};
    final raw = prefs.getString(_kTopics);
    if (raw != null) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    final cur = Map<String, dynamic>.from((map[t] as Map?) ?? {});
    cur['a'] = ((cur['a'] as int?) ?? 0) + 1;
    cur['c'] = ((cur['c'] as int?) ?? 0) + (correct ? 1 : 0);
    map[t] = cur;
    await prefs.setString(_kTopics, jsonEncode(map));
  }

  static Future<List<MistakeItem>> _loadDeck(SharedPreferences prefs) async {
    final raw = prefs.getStringList(_kMistakes) ?? const <String>[];
    final out = <MistakeItem>[];
    for (final s in raw) {
      try {
        final item =
            MistakeItem.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
        if (item != null) out.add(item);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> _saveDeck(
      SharedPreferences prefs, List<MistakeItem> deck) async {
    await prefs.setStringList(
        _kMistakes, deck.map((m) => jsonEncode(m.toJson())).toList());
  }
}
