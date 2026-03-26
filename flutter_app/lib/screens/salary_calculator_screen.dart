// lib/screens/salary_calculator_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class SalaryCalculatorScreen extends StatefulWidget {
  const SalaryCalculatorScreen({super.key});
  @override
  State<SalaryCalculatorScreen> createState() => _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen>
    with SingleTickerProviderStateMixin {
  int    _payLevel   = 6;
  String _cityType   = 'Y';
  double _daRate     = 0.55;
  bool   _showAnnual = false;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  // ── 7th CPC Pay Matrix — entry basic pay (all 18 levels) ─────────────────
  static const _payMatrix = {
    1:  18000,  2:  19900,  3:  21700,  4:  25500,
    5:  29200,  6:  35400,  7:  44900,  8:  47600,
    9:  53100,  10: 56100,  11: 67700,  12: 78800,
    13: 123100, 14: 144200, 15: 182200, 16: 205400,
    17: 225000, 18: 250000,
  };

  static const _gradePay = {
    1: 1800, 2: 1900, 3: 2000, 4: 2400, 5: 2800,
    6: 4200, 7: 4600, 8: 4800, 9: 5400, 10: 5400,
    11: 6600, 12: 7600, 13: 8700, 14: 10000,
    15: null, 16: null, 17: null, 18: null,
  };

  static const _levelPosts = {
    1:  'MTS / Peon / Helper (Group C)',
    2:  'Lower Division Clerk (LDC)',
    3:  'Upper Division Clerk (UDC)',
    4:  'Stenographer Gr III / Assistant',
    5:  'Junior Accountant / PA',
    6:  'JSO / ASO / Sub-Inspector',
    7:  'Section Officer / JHT',
    8:  'Asst Accounts Officer (AAO)',
    9:  'ASO — Central Secretariat',
    10: 'Section Officer (Gazetted)',
    11: 'Under Secretary / Dy SP',
    12: 'Deputy Secretary / SP',
    13: 'Director / DIG of Police',
    14: 'Joint Secretary / IG (SAG)',
    15: 'Additional Secretary (HAG)',
    16: 'Special Secretary (HAG+)',
    17: 'Secretary to Govt of India',
    18: 'Cabinet Secretary',
  };

  static const _hraRate  = {'X': 0.27, 'Y': 0.18, 'Z': 0.09};
  static const _cityLabel = {
    'X': 'X — Metro (27% HRA)',
    'Y': 'Y — Big City (18% HRA)',
    'Z': 'Z — Small Town (9% HRA)',
  };
  static const _cityEx = {
    'X': 'Delhi, Mumbai, Kolkata, Chennai, Bengaluru, Hyderabad, Ahmedabad, Pune',
    'Y': 'Lucknow, Jaipur, Patna, Chandigarh, Bhopal, Indore, Nagpur + 49 more cities',
    'Z': 'All other cities and towns',
  };

  int _taBase(int level) => level <= 2 ? 1350 : level <= 8 ? 3600 : 7200;

  int _cghs(int basic) {
    if (basic <= 25000)  return 250;
    if (basic <= 40000)  return 450;
    if (basic <= 60000)  return 650;
    if (basic <= 75000)  return 1000;
    if (basic <= 125000) return 1300;
    return 1800;
  }

  // New Tax Regime FY 2025-26 | Std Deduction ₹75,000 | Rebate 87A ≤ ₹7L
  int _yearlyTax(int grossAnnual) {
    final taxable = (grossAnnual - 75000).clamp(0, 999999999);
    int tax = 0;
    if (taxable <= 300000) {
      tax = 0;
    } else if (taxable <= 700000) {
      tax = (taxable - 300000) * 5 ~/ 100;
      if (tax <= 25000) tax = 0;
    } else if (taxable <= 1000000) {
      tax = 20000 + (taxable - 700000) * 10 ~/ 100;
    } else if (taxable <= 1200000) {
      tax = 50000 + (taxable - 1000000) * 15 ~/ 100;
    } else if (taxable <= 1500000) {
      tax = 80000 + (taxable - 1200000) * 20 ~/ 100;
    } else {
      tax = 140000 + (taxable - 1500000) * 30 ~/ 100;
    }
    return (tax * 1.04).round(); // 4% Health & Education cess
  }

  Map<String, int> _calc({int? level}) {
    final l     = level ?? _payLevel;
    final basic = _payMatrix[l]!;
    final da    = (basic * _daRate).round();
    final hra   = (basic * _hraRate[_cityType]!).round();
    final taB   = _taBase(l);
    final ta    = taB + (taB * _daRate).round();
    final gross = basic + da + hra + ta;
    final nps   = ((basic + da) * 0.10).round();
    final npsE  = ((basic + da) * 0.14).round();
    final cghs  = _cghs(basic);
    final tax   = _yearlyTax(gross * 12) ~/ 12;
    return {
      'basic': basic, 'da': da, 'hra': hra, 'ta': ta,
      'gross': gross, 'nps': nps, 'nps_emp': npsE,
      'cghs': cghs, 'tax': tax,
      'in_hand': gross - nps - cghs - tax,
      'ctc': gross + npsE,
    };
  }

  // Indian numeral format: 1,23,456
  String _fmt(int n, {bool annual = false}) {
    final v = annual ? n * 12 : n;
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000)   return '₹${(v / 100000).toStringAsFixed(2)}L';
    final s = v.toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    final rest  = s.substring(0, s.length - 3);
    final buf   = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '₹$buf,$last3';
  }

  void _copyShare() {
    final c   = _calc();
    final da  = (_daRate * 100).round();
    final txt =
        '💰 7th CPC Salary — Pay Level $_payLevel\n'
        '📍 ${_cityLabel[_cityType]}\n\n'
        'Basic Pay:        ${_fmt(c['basic']!)}\n'
        'DA ($da%):        +${_fmt(c['da']!)}\n'
        'HRA:              +${_fmt(c['hra']!)}\n'
        'TA (incl. DA):    +${_fmt(c['ta']!)}\n'
        '──────────────────────────────\n'
        'Gross:            ${_fmt(c['gross']!)}\n'
        'NPS (your 10%):   -${_fmt(c['nps']!)}\n'
        'CGHS:             -${_fmt(c['cghs']!)}\n'
        'Income Tax (est): -${_fmt(c['tax']!)}\n'
        '══════════════════════════════\n'
        '🏦 In-Hand:       ${_fmt(c['in_hand']!)}/month\n\n'
        '📌 ${_levelPosts[_payLevel]}\n'
        '🏛 Govt NPS (14%):+${_fmt(c['nps_emp']!)}/month\n\n'
        'Calculated by JobMitra App 🇮🇳';
    Clipboard.setData(ClipboardData(text: txt));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Salary breakdown copied — paste on WhatsApp!'),
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
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                            Text('Salary Calculator',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text('7th CPC — In-hand & Tax estimate',
                                style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white),
                        onPressed: _copyShare,
                        tooltip: 'Copy & Share',
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabCtrl,
                  tabs: const [Tab(text: 'Calculator'), Tab(text: '5-Year Growth')],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Color(0xFFFF9933),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildCalculatorTab(c), _buildGrowthTab()],
      ),
    );
  }

  Widget _buildCalculatorTab(Map<String, int> c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _card(child: _buildLevelSelector()),
          const SizedBox(height: 12),
          _card(child: _buildCitySelector()),
          const SizedBox(height: 12),
          _card(child: _buildDaSlider()),
          const SizedBox(height: 16),
          Row(children: [
            const Text('View:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            _toggleBtn('Monthly', !_showAnnual, () => setState(() => _showAnnual = false)),
            const SizedBox(width: 8),
            _toggleBtn('Annual', _showAnnual, () => setState(() => _showAnnual = true)),
          ]),
          const SizedBox(height: 12),
          _buildBreakdownCard(c),
          const SizedBox(height: 12),
          _buildNpsCard(c),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyShare,
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
          _buildDisclaimer(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLevelSelector() {
    final gp = _gradePay[_payLevel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('💼 Pay Level', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Level $_payLevel',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(_levelPosts[_payLevel] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        if (gp != null)
          Text('6th CPC Grade Pay: ₹$gp',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _payLevel.toDouble(), min: 1, max: 18, divisions: 17,
            onChanged: (v) => setState(() => _payLevel = v.round()),
          ),
        ),
        Wrap(
          spacing: 5, runSpacing: 5,
          children: List.generate(18, (i) {
            final l = i + 1;
            final sel = l == _payLevel;
            return GestureDetector(
              onTap: () => setState(() => _payLevel = l),
              child: Container(
                width: 36, height: 30,
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('$l',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : Colors.grey[600])),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCitySelector() {
    return Column(
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
                  child: Column(children: [
                    Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                        color: sel ? Colors.white : Colors.grey[700])),
                    Text(t == 'X' ? '27%' : t == 'Y' ? '18%' : '9%',
                        style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : Colors.grey[500])),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(_cityEx[_cityType]!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildDaSlider() {
    final daPct = (_daRate * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('📊 DA Rate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9933).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$daPct%',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFFE65100))),
          ),
        ]),
        Text('Revised every 6 months — update when Govt announces',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: const Color(0xFFFF9933),
            activeTrackColor: const Color(0xFFFF9933),
            inactiveTrackColor: const Color(0xFFFF9933).withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            value: _daRate, min: 0.40, max: 0.80, divisions: 40,
            onChanged: (v) => setState(() => _daRate = v),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [50, 53, 55, 58, 61].map((pct) {
            final sel = (_daRate * 100).round() == pct;
            return GestureDetector(
              onTap: () => setState(() => _daRate = pct / 100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFFF9933) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$pct%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : Colors.grey[600])),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(Map<String, int> c) {
    final annual  = _showAnnual;
    final hraRate = (_hraRate[_cityType]! * 100).round();
    final daPct   = (_daRate * 100).round();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text(annual ? 'Annual In-Hand' : 'In-Hand / Month',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        const SizedBox(height: 4),
        Text(_fmt(c['in_hand']!, annual: annual),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
        Text('Level $_payLevel • ${_levelPosts[_payLevel]}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        const Divider(color: Colors.white24),
        const SizedBox(height: 12),
        _bRow('Basic Pay', c['basic']!, '+', Colors.white, annual: annual),
        _bRow('DA ($daPct%)', c['da']!, '+', const Color(0xFFB9F6CA), annual: annual),
        _bRow('HRA ($hraRate%)', c['hra']!, '+', const Color(0xFFB9F6CA), annual: annual),
        _bRow('TA (incl. DA)', c['ta']!, '+', const Color(0xFFB9F6CA), annual: annual),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white24)),
        _bRow('Gross Salary', c['gross']!, '=', Colors.white, annual: annual),
        const SizedBox(height: 8),
        _bRow('NPS (your 10%)', c['nps']!, '−', const Color(0xFFFFCDD2), annual: annual),
        _bRow('CGHS', c['cghs']!, '−', const Color(0xFFFFCDD2), annual: annual),
        _bRow('Income Tax (est.)', c['tax']!, '−', const Color(0xFFFFCDD2), annual: annual),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white24)),
        Row(children: [
          const Text('🏦 In-Hand',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const Spacer(),
          Text(_fmt(c['in_hand']!, annual: annual),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
      ]),
    );
  }

  Widget _buildNpsCard(Map<String, int> c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance_rounded, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Text('NPS Benefit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.blue[800])),
        ]),
        const SizedBox(height: 10),
        _infoRow('Your NPS (10%)', _fmt(c['nps']!), Colors.blue[700]!),
        _infoRow('Govt NPS (14%)', _fmt(c['nps_emp']!), Colors.green[700]!),
        const Divider(height: 16),
        _infoRow('Total NPS / month', _fmt(c['nps']! + c['nps_emp']!), Colors.blue[900]!),
        const SizedBox(height: 4),
        Text('Government contributes 14% — retirement corpus grows faster than private sector.',
            style: TextStyle(fontSize: 11, color: Colors.blue[600])),
      ]),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: Colors.amber[700], size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Estimate only. DA revised every 6 months — use slider above. '
            'Tax uses New Regime FY 2025-26 (Std. Deduction ₹75,000). '
            'Professional tax, uniform & posting allowances not included.',
            style: TextStyle(fontSize: 11, color: Colors.amber[800]),
          ),
        ),
      ]),
    );
  }

  Widget _buildGrowthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Level $_payLevel • ${_levelPosts[_payLevel]}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text('3% annual increment on basic pay (1st July each year)',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 16),
          ...List.generate(11, _buildYearRow),
          const SizedBox(height: 16),
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📌 Key facts about annual increment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            _bullet('Increment is 3% of basic pay, added every 1st July'),
            _bullet('DA, HRA, TA all increase proportionally with basic'),
            _bullet('MACP promotion: after 10 & 20 years if no regular promotion'),
            _bullet('NPS corpus: 24% of (basic+DA) per month — govt + employee combined'),
          ])),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildYearRow(int year) {
    double b = _payMatrix[_payLevel]!.toDouble();
    for (int i = 0; i < year; i++) b = ((b * 1.03 / 100).ceil()) * 100.0;
    final basic = b.toInt();
    final da    = (basic * _daRate).round();
    final hra   = (basic * _hraRate[_cityType]!).round();
    final taB   = _taBase(_payLevel);
    final ta    = taB + (taB * _daRate).round();
    final gross = basic + da + hra + ta;
    final nps   = ((basic + da) * 0.10).round();
    final cghs  = _cghs(basic);
    final tax   = _yearlyTax(gross * 12) ~/ 12;
    final inH   = gross - nps - cghs - tax;
    final isNow = year == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNow ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isNow ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey[200]!),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isNow ? AppColors.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(year == 0 ? 'Now' : 'Y$year',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: isNow ? Colors.white : Colors.grey[600])),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Basic: ${_fmt(basic)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('Gross: ${_fmt(gross)}  •  In-Hand: ${_fmt(inH)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ])),
        Text(_fmt(inH),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                color: isNow ? AppColors.primary : AppColors.textSecondary)),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _toggleBtn(String label, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: sel ? AppColors.primary : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : Colors.grey[600])),
    ),
  );

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );

  Widget _bRow(String label, int amount, String sign, Color color, {bool annual = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(sign, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 13))),
        Text(_fmt(amount, annual: annual), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );

  Widget _infoRow(String label, String value, Color color) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.blue[800]))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
      ]),
    );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
    ]),
  );
}
