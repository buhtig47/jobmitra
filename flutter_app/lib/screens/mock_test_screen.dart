// lib/screens/mock_test_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

// ── Data Models ───────────────────────────────────────────────────────────────

class _Q {
  final String q;
  final List<String> opts;
  final int ans; // 0-indexed
  const _Q(this.q, this.opts, this.ans);
}

class _Pack {
  final String title, subtitle, emoji;
  final Color color;
  final List<_Q> questions;
  const _Pack({
    required this.title, required this.subtitle,
    required this.emoji, required this.color,
    required this.questions,
  });
}

// ── Question Banks ────────────────────────────────────────────────────────────

const _packs = [
  _Pack(
    title: 'SSC General Knowledge',
    subtitle: 'Static GK for SSC CGL, CHSL, MTS',
    emoji: '🏛️',
    color: Color(0xFF1A6B3C),
    questions: [
      _Q('Who wrote the book "Discovery of India"?',
          ['Mahatma Gandhi', 'Jawaharlal Nehru', 'B.R. Ambedkar', 'Rabindranath Tagore'], 1),
      _Q('Which Article of the Indian Constitution abolishes untouchability?',
          ['Article 14', 'Article 15', 'Article 17', 'Article 21'], 2),
      _Q('The headquarters of ISRO is located in?',
          ['Mumbai', 'New Delhi', 'Hyderabad', 'Bengaluru'], 3),
      _Q('Which river is called the "Sorrow of Bihar"?',
          ['Gandak', 'Ganga', 'Kosi', 'Son'], 2),
      _Q('Who was the first woman IPS officer of India?',
          ['Sonia Gandhi', 'Pratibha Patil', 'Kiran Bedi', 'Bachendri Pal'], 2),
      _Q('Mt. K2 is also known as?',
          ['Godwin-Austen', 'Everest II', 'Black Mountain', 'Nanda Peak'], 0),
      _Q('Who composed the national song "Vande Mataram"?',
          ['Rabindranath Tagore', 'Sri Aurobindo', 'Sarojini Naidu', 'Bankim Chandra Chatterjee'], 3),
      _Q('Which state has the longest coastline in India?',
          ['Maharashtra', 'Andhra Pradesh', 'Tamil Nadu', 'Gujarat'], 3),
      _Q('"Operation Flood" was related to?',
          ['Flood management', 'Milk production', 'Wheat production', 'Fisheries'], 1),
      _Q('The Dandi March (Salt March) took place in which year?',
          ['1928', '1942', '1930', '1935'], 2),
      _Q('Which is the largest freshwater lake in India?',
          ['Chilika Lake', 'Wular Lake', 'Dal Lake', 'Loktak Lake'], 1),
      _Q('Project Tiger was launched in?',
          ['1970', '1972', '1973', '1975'], 2),
      _Q('Who is called the "Father of the Indian Constitution"?',
          ['Mahatma Gandhi', 'Jawaharlal Nehru', 'B.R. Ambedkar', 'Sardar Patel'], 2),
      _Q('Which is the smallest state of India by area?',
          ['Sikkim', 'Tripura', 'Goa', 'Manipur'], 2),
      _Q('Pradhan Mantri Awas Yojana (Urban) aims to provide?',
          ['Employment', 'Food security', 'Housing for all', 'Free education'], 2),
    ],
  ),
  _Pack(
    title: 'Banking & Finance',
    subtitle: 'For SBI PO, IBPS PO, RBI Grade B',
    emoji: '🏦',
    color: Color(0xFF1565C0),
    questions: [
      _Q('RBI was established in which year?',
          ['1930', '1935', '1947', '1950'], 1),
      _Q('NEFT stands for?',
          ['National Electronic Funds Transfer', 'National Economy Finance Transfer',
           'Net Electronic Fund Transfer', 'National Exchange Finance Transfer'], 0),
      _Q('Who is called the "Father of White Revolution" in India?',
          ['M.S. Swaminathan', 'Verghese Kurien', 'Norman Borlaug', 'C. Subramaniam'], 1),
      _Q('The minimum lock-in period for a Tax Saving FD is?',
          ['3 years', '7 years', '10 years', '5 years'], 3),
      _Q('PMJDY stands for?',
          ['Pradhan Mantri Jan Dhan Yojana', 'Pradhan Mantri Jan Desh Yojana',
           'Prime Minister Jan Dhani Yojana', 'None of these'], 0),
      _Q('Which is the largest public sector bank in India?',
          ['Punjab National Bank', 'Bank of Baroda', 'Canara Bank', 'State Bank of India'], 3),
      _Q('SEBI regulates which market in India?',
          ['Commodity market only', 'Money market only',
           'Securities / Stock market', 'Foreign exchange market'], 2),
      _Q('CRR stands for?',
          ['Credit Reserve Ratio', 'Cash Reserve Ratio',
           'Capital Reserve Requirement', 'Currency Ratio Reserve'], 1),
      _Q('NABARD was established to provide credit for?',
          ['Industries', 'Agriculture & rural development', 'Housing sector', 'Export'], 1),
      _Q('Repo rate is the rate at which?',
          ['Banks borrow from each other', 'RBI lends to commercial banks',
           'Banks lend to customers', 'Government borrows from RBI'], 1),
      _Q('UPI was launched by which organization?',
          ['RBI', 'SBI', 'NPCI', 'SEBI'], 2),
      _Q('Which instrument is used to transfer funds without physical cash?',
          ['Cheque', 'Demand Draft', 'NEFT / RTGS', 'All of these'], 3),
      _Q('The base rate system of lending was replaced by?',
          ['Prime Lending Rate', 'MCLR (Marginal Cost of Funds based Lending Rate)',
           'Repo Linked Lending Rate', 'Bank Rate'], 1),
      _Q('Priority sector lending target for domestic banks is what % of ANBC?',
          ['30%', '35%', '40%', '45%'], 2),
      _Q('Which is NOT a function of RBI?',
          ['Issuing currency notes', 'Banker to government',
           'Granting retail loans to public', 'Regulating banking sector'], 2),
    ],
  ),
  _Pack(
    title: 'Railway GK',
    subtitle: 'For RRB NTPC, Group D, ALP',
    emoji: '🚂',
    color: Color(0xFFB71C1C),
    questions: [
      _Q('Indian Railways was nationalized in which year?',
          ['1947', '1948', '1950', '1951'], 3),
      _Q('The first railway in India ran between?',
          ['Delhi to Agra', 'Kolkata to Howrah',
           'Mumbai (Bombay) to Thane', 'Chennai to Madurai'], 2),
      _Q('Which station has the longest railway platform in India?',
          ['Gorakhpur', 'Kharagpur', 'Agra Cantt', 'Allahabad'], 0),
      _Q('IRCTC stands for?',
          ['Indian Railway Cargo & Travel Corporation',
           'Indian Railway Catering and Tourism Corporation',
           'Indian Rail Catering & Transport Company', 'None of these'], 1),
      _Q('Vande Bharat Express is classified as?',
          ['Bullet train', 'Freight train', 'Semi-high speed train', 'Metro train'], 2),
      _Q('The headquarters of Indian Railways is in?',
          ['Mumbai', 'Kolkata', 'Chennai', 'New Delhi'], 3),
      _Q('Lifeline Express is also known as?',
          ['Train of Hope', 'Hospital on Wheels', 'Mobile Medical Unit', 'Health Train'], 1),
      _Q('Which zone of Indian Railways is the largest by route km?',
          ['Central Railway', 'Western Railway', 'Northern Railway', 'South Central Railway'], 2),
      _Q('Rail Kaushal Vikas Yojana is related to?',
          ['Railway infrastructure', 'Skill development for youth',
           'Railway employee training', 'Station modernization'], 1),
      _Q('The first Metro rail in India started in which city?',
          ['Delhi', 'Mumbai', 'Chennai', 'Kolkata'], 3),
      _Q('Indian Railways mainly uses which gauge for broad gauge tracks?',
          ['762 mm', '1000 mm', '1676 mm', '1435 mm'], 2),
      _Q('Mission Raftaar was launched by Indian Railways to?',
          ['Reduce accidents', 'Double freight and passenger speed',
           'Build new stations', 'Electrify all routes'], 1),
      _Q('The Konkan Railway connects Roha (Maharashtra) to?',
          ['Goa', 'Thivim', 'Mangaluru (Karnataka)', 'Kochi'], 2),
      _Q('Rail Vikas Nigam Limited (RVNL) is under which ministry?',
          ['Finance Ministry', 'Commerce Ministry',
           'Ministry of Railways', 'Ministry of Transport'], 2),
      _Q('PM Gati Shakti National Master Plan is related to?',
          ['Agricultural supply chains', 'Integrated multimodal connectivity infrastructure',
           'Digital connectivity', 'Rural electrification'], 1),
    ],
  ),
  _Pack(
    title: 'Reasoning Ability',
    subtitle: 'Logical & verbal reasoning basics',
    emoji: '🧠',
    color: Color(0xFF6A1B9A),
    questions: [
      _Q('Complete the series: 2, 4, 8, 16, ?',
          ['24', '32', '36', '28'], 1),
      _Q('If BOOK is coded as CPPL (each letter +1), how is FISH coded?',
          ['GJTI', 'GHTJ', 'GITH', 'GJTH'], 0),
      _Q('Find the odd one out: Apple, Mango, Potato, Banana',
          ['Apple', 'Mango', 'Potato', 'Banana'], 2),
      _Q('Dog is to Kennel as Bird is to?',
          ['Hole', 'Cage', 'Nest', 'Tree'], 2),
      _Q('Complete the series: 3, 6, 11, 18, 27, ?\n(Hint: differences are 3, 5, 7, 9, 11)',
          ['36', '38', '35', '40'], 1),
      _Q('Which number does NOT belong: 1, 4, 9, 16, 24, 36?',
          ['4', '9', '24', '36'], 2),
      _Q('Pointing to a boy, a girl says "His mother is the only daughter of my mother." '
         'How is the girl related to the boy?',
          ['Grandmother', 'Sister', 'Aunt', 'Mother'], 3),
      _Q('ACEG : BDFH :: IKMO : ?',
          ['JLNP', 'JLNO', 'ILNP', 'KLMP'], 0),
      _Q('Complete the Fibonacci series: 1, 1, 2, 3, 5, 8, ?',
          ['11', '12', '13', '14'], 2),
      _Q('If + means ×, − means +, ÷ means −, × means ÷\n'
         'Find: 15 + 3 − 20 ÷ 5',
          ['55', '60', '65', '70'], 1),
      _Q('Missing number: 8, 27, 64, 125, ?  (cubes: 2³, 3³, 4³, 5³...)',
          ['196', '216', '225', '243'], 1),
      _Q('A is 3 ranks above C in class. B is 2 ranks below A. '
         'If C is 15th from the bottom and there are 40 students, what is B\'s rank from top?',
          ['16', '17', '15', '14'], 0),
      _Q('Find the odd one out: January, March, June, August',
          ['January', 'March', 'June', 'August'], 2),
      _Q('If ZONE is coded by position values: Z=26, O=15, N=14, E=5; '
         'what is the total?',
          ['55', '58', '60', '62'], 2),
      _Q('In a row of boys, Ravi is 7th from left and 13th from right. '
         'How many boys are in the row?',
          ['18', '19', '20', '21'], 1),
    ],
  ),
  _Pack(
    title: 'Indian Polity',
    subtitle: 'Constitution & governance — UPSC / SSC',
    emoji: '⚖️',
    color: Color(0xFF00695C),
    questions: [
      _Q('The Constitution of India came into force on?',
          ['15 August 1947', '26 November 1949', '26 January 1950', '30 January 1948'], 2),
      _Q('How many Fundamental Rights are guaranteed by the Indian Constitution?',
          ['7', '6', '5', '8'], 1),
      _Q('Which article grants the Right to Constitutional Remedies?',
          ['Article 19', 'Article 21', 'Article 32', 'Article 44'], 2),
      _Q('The President of India is elected by?',
          ['Direct election by citizens', 'Lok Sabha members only',
           'Elected members of Parliament and State Legislative Assemblies',
           'Rajya Sabha members only'], 2),
      _Q('Which Schedule of the Constitution lists the Official Languages?',
          ['Sixth Schedule', 'Seventh Schedule', 'Eighth Schedule', 'Ninth Schedule'], 2),
      _Q('The term "Secular" was added to the Preamble by which Amendment?',
          ['42nd Amendment, 1976', '44th Amendment, 1978',
           '52nd Amendment, 1985', '61st Amendment, 1988'], 0),
      _Q('Which writ is issued for the release of a person illegally detained?',
          ['Mandamus', 'Certiorari', 'Habeas Corpus', 'Quo Warranto'], 2),
      _Q('Zero Hour in Parliament begins at?',
          ['9:00 AM', '11:00 AM', '12:00 Noon', '2:00 PM'], 2),
      _Q('The concept of "Directive Principles of State Policy" was borrowed from?',
          ['USA', 'UK', 'Ireland', 'Canada'], 2),
      _Q('Under which Article can the President declare National Emergency?',
          ['Article 352', 'Article 356', 'Article 360', 'Article 370'], 0),
      _Q('The Election Commission of India is a/an?',
          ['Statutory body', 'Constitutional body', 'Executive body', 'Advisory body'], 1),
      _Q('How many members can the President nominate to the Rajya Sabha?',
          ['10', '14', '12', '16'], 2),
      _Q('Which part of the Constitution deals with Fundamental Duties?',
          ['Part III', 'Part IV', 'Part IVA', 'Part V'], 2),
      _Q('The minimum age to become a member of Rajya Sabha is?',
          ['21 years', '25 years', '30 years', '35 years'], 2),
      _Q('Which committee examines the estimates of expenditure of the Government?',
          ['Public Accounts Committee', 'Estimates Committee',
           'Committee on Public Undertakings', 'Finance Committee'], 1),
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

enum _Stage { list, quiz, result }

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key});
  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  _Stage _stage   = _Stage.list;
  late _Pack _pack;

  // quiz state
  int  _qIndex    = 0;
  int  _selected  = -1;  // chosen option (-1 = none)
  bool _answered  = false;
  int  _score     = 0;
  List<int> _userAnswers = [];

  // timer
  static const _secsPerQ = 30;
  int  _secsLeft  = _secsLeft0;
  static const _secsLeft0 = _secsPerQ;
  Timer? _timer;

  void _startPack(_Pack pack) {
    setState(() {
      _pack      = pack;
      _qIndex    = 0;
      _selected  = -1;
      _answered  = false;
      _score     = 0;
      _secsLeft  = _secsLeft0;
      _userAnswers = [];
      _stage     = _Stage.quiz;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secsLeft <= 1) {
        _timer?.cancel();
        if (!_answered) _submitAnswer(-1); // auto-submit as wrong
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  void _submitAnswer(int chosen) {
    if (_answered) return;
    _timer?.cancel();
    final correct = _pack.questions[_qIndex].ans;
    setState(() {
      _selected  = chosen;
      _answered  = true;
      if (chosen == correct) _score++;
      _userAnswers.add(chosen);
    });
  }

  void _nextQuestion() {
    if (_qIndex + 1 >= _pack.questions.length) {
      setState(() => _stage = _Stage.result);
      return;
    }
    setState(() {
      _qIndex++;
      _selected  = -1;
      _answered  = false;
      _secsLeft  = _secsLeft0;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: switch (_stage) {
        _Stage.list   => _buildList(),
        _Stage.quiz   => _buildQuiz(),
        _Stage.result => _buildResult(),
      },
    );
  }

  // ── Test List ─────────────────────────────────────────────────────────────

  Widget _buildList() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PackCard(pack: _packs[i], onTap: () => _startPack(_packs[i])),
              ),
              childCount: _packs.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📝 Mock Tests',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('SSC · Banking · Railway · Polity — free practice',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quiz ──────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final q = _pack.questions[_qIndex];
    final total = _pack.questions.length;
    final progress = (_qIndex + 1) / total;
    final timeProgress = _secsLeft / _secsLeft0;
    final timerColor = _secsLeft <= 10
        ? Colors.red
        : _secsLeft <= 20 ? Colors.orange : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => setState(() {
                          _timer?.cancel();
                          _stage = _Stage.list;
                        }),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pack.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('Q${_qIndex + 1} of $total',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: timerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: timerColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: timerColor),
                            const SizedBox(width: 4),
                            Text('${_secsLeft}s',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: timerColor)),
                          ],
                        ),
                      ),
                      // Score
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_score ✓',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bars
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(_pack.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: timeProgress,
                            minHeight: 3,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation(timerColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Question
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number badge + text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Text(q.q,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.45)),
                    ),
                    const SizedBox(height: 16),
                    // Options
                    ...List.generate(4, (i) => _OptionTile(
                      label: String.fromCharCode(65 + i), // A, B, C, D
                      text: q.opts[i],
                      state: !_answered
                          ? _OptionState.normal
                          : i == q.ans
                              ? _OptionState.correct
                              : i == _selected
                                  ? _OptionState.wrong
                                  : _OptionState.normal,
                      selected: _selected == i,
                      onTap: _answered ? null : () => _submitAnswer(i),
                    )),
                    // Explanation area when answered
                    if (_answered) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selected == q.ans
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selected == q.ans
                                ? const Color(0xFF81C784)
                                : const Color(0xFFFFB74D),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selected == q.ans ? '🎉' : (_selected == -1 ? '⏰' : '❌'),
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selected == q.ans
                                    ? 'Correct! Well done.'
                                    : _selected == -1
                                        ? 'Time up! Correct answer: ${q.opts[q.ans]}'
                                        : 'Wrong. Correct answer: ${q.opts[q.ans]}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Next button
            if (_answered)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pack.color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _qIndex + 1 < _pack.questions.length ? 'Next Question →' : 'See Results',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Result ────────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final total = _pack.questions.length;
    final pct = _score / total;
    final (grade, msg, gradeColor) = pct >= 0.8
        ? ('Excellent!', 'Outstanding performance! You are exam-ready.', const Color(0xFF1A6B3C))
        : pct >= 0.6
            ? ('Good', 'Nice work! Review the ones you missed.', const Color(0xFF1565C0))
            : pct >= 0.4
                ? ('Average', 'Keep practicing — you\'re improving.', const Color(0xFFE65100))
                : ('Needs Work', 'Don\'t give up — practice makes perfect!', const Color(0xFFB71C1C));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Result header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradeColor, gradeColor.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(grade,
                      style: const TextStyle(color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(msg,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                  const SizedBox(height: 20),
                  // Score circle
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$_score/$total',
                            style: const TextStyle(color: Colors.white, fontSize: 28,
                                fontWeight: FontWeight.w900)),
                        Text('${(pct * 100).round()}%',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Review list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _pack.questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final q = _pack.questions[i];
                  final userAns = i < _userAnswers.length ? _userAnswers[i] : -1;
                  final correct = userAns == q.ans;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: correct
                            ? const Color(0xFF81C784)
                            : const Color(0xFFEF9A9A),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: correct ? const Color(0xFF1A6B3C) : const Color(0xFFB71C1C),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              correct ? Icons.check_rounded : Icons.close_rounded,
                              color: Colors.white, size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Q${i + 1}. ${q.q}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                                      height: 1.4)),
                              const SizedBox(height: 4),
                              if (!correct) ...[
                                Text('Your answer: ${userAns == -1 ? "Skipped (time up)" : q.opts[userAns]}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFB71C1C))),
                              ],
                              Text('Correct: ${q.opts[q.ans]}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A6B3C),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _stage = _Stage.list),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        side: BorderSide(color: _pack.color),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('All Tests',
                          style: TextStyle(color: _pack.color, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startPack(_pack),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: _pack.color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Retry', style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700)),
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
}

// ── Pack Card ─────────────────────────────────────────────────────────────────

class _PackCard extends StatelessWidget {
  final _Pack pack;
  final VoidCallback onTap;
  const _PackCard({required this.pack, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pack.color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(
              color: pack.color.withValues(alpha: 0.08),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              Container(width: 6, height: 90, color: pack.color),
              const SizedBox(width: 16),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: pack.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(pack.emoji, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(pack.subtitle,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.quiz_outlined, size: 13, color: pack.color),
                          const SizedBox(width: 3),
                          Text('${pack.questions.length} questions',
                              style: TextStyle(fontSize: 11, color: pack.color,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Icon(Icons.timer_outlined, size: 13, color: pack.color),
                          const SizedBox(width: 3),
                          Text('30s/question',
                              style: TextStyle(fontSize: 11, color: pack.color)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.play_circle_fill_rounded, color: pack.color, size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Option Tile ───────────────────────────────────────────────────────────────

enum _OptionState { normal, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String label, text;
  final _OptionState state;
  final bool selected;
  final VoidCallback? onTap;
  const _OptionTile({
    required this.label, required this.text,
    required this.state, required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, textColor, labelBg) = switch (state) {
      _OptionState.correct => (
          const Color(0xFFE8F5E9), const Color(0xFF81C784),
          const Color(0xFF1A6B3C), const Color(0xFF1A6B3C)),
      _OptionState.wrong => (
          const Color(0xFFFFEBEE), const Color(0xFFEF9A9A),
          const Color(0xFFB71C1C), const Color(0xFFB71C1C)),
      _OptionState.normal => selected
          ? (const Color(0xFFE3F2FD), const Color(0xFF1565C0),
             const Color(0xFF1565C0), const Color(0xFF1565C0))
          : (Colors.white, const Color(0xFFE0E0E0),
             AppColors.textPrimary, Colors.grey),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: labelBg, shape: BoxShape.circle),
              child: Center(
                child: Text(label,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
            ),
            if (state == _OptionState.correct)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF1A6B3C), size: 20),
            if (state == _OptionState.wrong)
              const Icon(Icons.cancel_rounded, color: Color(0xFFB71C1C), size: 20),
          ],
        ),
      ),
    );
  }
}
