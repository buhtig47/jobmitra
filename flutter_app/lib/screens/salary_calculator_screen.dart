// lib/screens/salary_calculator_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class SalaryCalculatorScreen extends StatefulWidget {
  const SalaryCalculatorScreen({super.key});
  @override
  State<SalaryCalculatorScreen> createState() => _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen> {
  int    _payLevel  = 6;
  String _cityType  = 'Y';

  // ── 7th CPC Pay Matrix — Entry basic pay ────────────────
  static const _payMatrix = {
    1: 18000,  2: 19900,  3: 21700,  4: 25500,
    5: 29200,  6: 35400,  7: 44900,  8: 47600,
    9: 53100,  10: 56100, 11: 67700, 12: 78800,
    13: 123100, 14: 144200,
  };

  static const _levelPosts = {
    1:  'MTS / Peon / Helper',
    2:  'Lower Division Clerk',
    3:  'Upper Division Clerk',
    4:  'Assistant / Steno',
    5:  'Senior Assistant',
    6:  'JSO / ASO / Inspector',
    7:  'Section Officer / JHT',
    8:  'Asst Accounts Officer',
    9:  'ASO (Central Sec.)',
    10: 'Section Officer (Gazetted)',
    11: 'Under Secretary',
    12: 'Deputy Secretary',
    13: 'Director',
    14: 'Joint Secretary',
  };

  // ── Allowance rates ──────────────────────────────────────
  static const double _daRate   = 0.55;  // 55% DA (Jan 2025 onwards)
  static const Map<String, double> _hraRate = {'X': 0.27, 'Y': 0.18, 'Z': 0.09};
  static const Map<String, String> _cityLabel = {
    'X': 'X — Metro (27% HRA)',
    'Y': 'Y — Big City (18% HRA)',
    'Z': 'Z — Small Town (9% HRA)',
  };
  static const Map<String, String> _cityEx = {
    'X': 'Mumbai, Delhi, Bengaluru, Hyderabad, Kolkata, Chennai, Pune, Ahmedabad',
    'Y': 'Lucknow, Jaipur, Patna, Chandigarh, Bhopal, Indore, Nagpur, Varanasi + 49 more',
    'Z': 'All other cities and towns',
  };

  int _ta(int level)   => level <= 2 ? 1350 : level <= 8 ? 3600 : 7200;
  int _cghs(int basic) => basic <= 25000 ? 250 : basic <= 40000 ? 450 :
                          basic <= 60000 ? 650 : basic <= 75000 ? 1000 :
                          basic <= 125000 ? 1300 : 1800;

  Map<String, int> _calc() {
    final basic  = _payMatrix[_payLevel]!;
    final da     = (basic * _daRate).round();
    final hra    = (basic * _hraRate[_cityType]!).round();
    final taBase = _ta(_payLevel);
    final ta     = taBase + (taBase * _daRate).round();
    final gross  = basic + da + hra + ta;
    final nps    = ((basic + da) * 0.10).round();
    final cghs   = _cghs(basic);
    return {
      'basic': basic, 'da': da, 'hra': hra, 'ta': ta,
      'gross': gross, 'nps': nps, 'cghs': cghs,
      'in_hand': gross - nps - cghs,
    };
  }

  String _fmt(int n) {
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(2)}L';
    final s = n.toString();
    if (s.length <= 4) return '₹$s';
    if (s.length == 5) return '₹${s[0]},${s.substring(1)}';
    return '₹${s.substring(0, s.length - 5)},${s.substring(s.length - 5, s.length - 3)},${s.substring(s.length - 3)}';
  }

  void _share() {
    final c = _calc();
    final text =
        '💰 7th CPC Salary — Pay Level $_payLevel\n'
        '📍 City: ${_cityLabel[_cityType]}\n\n'
        'Basic Pay:   ${_fmt(c['basic']!)}\n'
        'DA (55%):    +${_fmt(c['da']!)}\n'
        'HRA:         +${_fmt(c['hra']!)}\n'
        'TA (w/ DA):  +${_fmt(c['ta']!)}\n'
        '─────────────────────\n'
        'Gross:       ${_fmt(c['gross']!)}\n'
        'NPS (-10%):  -${_fmt(c['nps']!)}\n'
        'CGHS:        -${_fmt(c['cghs']!)}\n'
        '═════════════════════\n'
        '🏦 In-Hand:  ${_fmt(c['in_hand']!)}/month\n\n'
        '📌 Post: ${_levelPosts[_payLevel]}\n'
        'Calculated by JobMitra App 🇮🇳';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Salary breakdown copied — paste it on WhatsApp!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _calc();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Salary Calculator', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('7th CPC — In-hand salary estimate', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                    onPressed: _share,
                    tooltip: 'Copy & Share',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Pay Level selector ──
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💼 Pay Level', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Level $_payLevel',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _levelPosts[_payLevel] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    ),
                    child: Slider(
                      value: _payLevel.toDouble(),
                      min: 1, max: 14, divisions: 13,
                      onChanged: (v) => setState(() => _payLevel = v.round()),
                    ),
                  ),
                  // Level grid
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: List.generate(14, (i) {
                      final l = i + 1;
                      final sel = l == _payLevel;
                      return GestureDetector(
                        onTap: () => setState(() => _payLevel = l),
                        child: Container(
                          width: 38, height: 32,
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$l',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── City type selector ──
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏙️ City Type (HRA)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['X', 'Y', 'Z'].map((t) {
                      final sel = t == _cityType;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _cityType = t),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: sel ? null : Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              children: [
                                Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: sel ? Colors.white : Colors.grey[700])),
                                Text(
                                  t == 'X' ? '27%' : t == 'Y' ? '18%' : '9%',
                                  style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cityEx[_cityType]!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Salary Breakdown ──
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // In-hand hero
                  Text('In-Hand Salary / Month', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    _fmt(c['in_hand']!),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Pay Level $_payLevel • ${_levelPosts[_payLevel]}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  // Breakdown rows
                  _bRow('Basic Pay', c['basic']!, '+', Colors.white),
                  _bRow('DA (55%)', c['da']!, '+', const Color(0xFFB9F6CA)),
                  _bRow('HRA (${(_hraRate[_cityType]! * 100).round()}%)', c['hra']!, '+', const Color(0xFFB9F6CA)),
                  _bRow('TA (incl. DA)', c['ta']!, '+', const Color(0xFFB9F6CA)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.white24),
                  ),
                  _bRow('Gross Salary', c['gross']!, '=', Colors.white),
                  const SizedBox(height: 8),
                  _bRow('NPS (-10%)', c['nps']!, '−', const Color(0xFFFFCDD2)),
                  _bRow('CGHS', c['cghs']!, '−', const Color(0xFFFFCDD2)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.white24),
                  ),
                  Row(
                    children: [
                      const Text('🏦 In-Hand', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      const Spacer(),
                      Text(
                        _fmt(c['in_hand']!),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Share button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy & Share on WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Disclaimer ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DA rate 55% (Jan 2025) use ki gayi hai. Actual salary may vary slightly.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _bRow(String label, int amount, String sign, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(sign, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 13))),
          Text(_fmt(amount), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
