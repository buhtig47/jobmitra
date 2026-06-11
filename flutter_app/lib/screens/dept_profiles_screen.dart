// lib/screens/dept_profiles_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

// ── Top-level helpers ─────────────────────────────────────────

String _formatSalaryShort(String salary) {
  final nums = RegExp(r'[\d,]+')
      .allMatches(salary)
      .map((m) => int.tryParse(m.group(0)!.replaceAll(',', '')))
      .whereType<int>()
      .toList();
  if (nums.isEmpty) return salary;
  String fmt(int n) {
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(0)}K';
    return '₹$n';
  }
  if (nums.length >= 2) return '${fmt(nums[0])}–${fmt(nums[1])}';
  return fmt(nums[0]);
}

int _parseSalaryMax(String salary) {
  final nums = RegExp(r'[\d,]+')
      .allMatches(salary)
      .map((m) => int.tryParse(m.group(0)!.replaceAll(',', '')))
      .whereType<int>()
      .toList();
  if (nums.isEmpty) return 0;
  return nums.reduce((a, b) => a > b ? a : b);
}

LinearGradient _categoryGradient(String category) {
  switch (category) {
    case 'defence':
      return const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF33691E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    case 'banking':
      return const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    case 'railway':
      return const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    case 'research':
      return const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    case 'state':
      return const LinearGradient(
          colors: [Color(0xFFBF360C), Color(0xFFE65100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    default:
      return const LinearGradient(
          colors: [Color(0xFF1A6B3C), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
  }
}

class _DiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.5;
    const step = 22.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Data model ────────────────────────────────────────────────
class _Dept {
  final String name;
  final String fullName;
  final String emoji;
  final String category;
  final Color color;
  final String ministry;
  final String hq;
  final String about;
  final List<String> roles;
  final String salary;
  final String workLife;
  final List<String> perks;
  final String promotionPath;
  final String bestFor;
  final int rating;

  const _Dept({
    required this.name,
    required this.fullName,
    required this.emoji,
    required this.category,
    required this.color,
    required this.ministry,
    required this.hq,
    required this.about,
    required this.roles,
    required this.salary,
    required this.workLife,
    required this.perks,
    required this.promotionPath,
    required this.bestFor,
    required this.rating,
  });
}

const _depts = <_Dept>[
  // ── Central / Ministries ──
  _Dept(
    name: 'IAS / IPS / IRS',
    fullName: 'Indian Administrative / Police / Revenue Service',
    emoji: '🇮🇳',
    category: 'central',
    color: Color(0xFF1A237E),
    ministry: 'Ministry of Personnel, DoPT',
    hq: 'North Block, New Delhi',
    about:
        'India\'s most powerful bureaucrats. Become District Collector, SP, Commissioner. Control over policy, law & order, and revenue.',
    roles: [
      'IAS – District Collector / SDM',
      'IPS – SP / DIG / Inspector General',
      'IRS – Income Tax / Customs Officer'
    ],
    salary: '₹56,100 – ₹2,50,000/month',
    workLife:
        'Field postings are hectic (24x7). Better balance at senior levels.',
    perks: [
      'Government bungalow',
      'Government car + driver',
      'Z/Y security',
      'Priority medical (CGHS)',
      'Staff at home',
      'Power & prestige'
    ],
    promotionPath:
        'SDM → ADM → DM/Collector → Commissioner → Secretary → Cabinet Secretary',
    bestFor: 'Those who want both power and public service',
    rating: 5,
  ),
  _Dept(
    name: 'SSC CGL Posts',
    fullName: 'Income Tax / Excise / CBI / Audit',
    emoji: '🏛️',
    category: 'central',
    color: Color(0xFF1565C0),
    ministry: 'Various Central Ministries',
    hq: 'Pan India',
    about:
        'SSC CGL ke through Inspector Income Tax, Excise, CBI, CAG Auditor, CSS. Stable central govt job with Grade Pay 4200-4600.',
    roles: [
      'Inspector Income Tax',
      'Inspector Central Excise',
      'Sub Inspector CBI',
      'Auditor (CAG/CGDA)',
      'CSS (MEA, PMO postings)'
    ],
    salary: '₹35,000 – ₹65,000/month',
    workLife:
        'IT/Excise inspection field duty, Audit 9-5. Office based stable.',
    perks: [
      'HRA 27% in X cities',
      'LTC (hometown + abroad)',
      'CGHS medical',
      'Reimbursements',
      'Subsidized canteen'
    ],
    promotionPath: 'Inspector → SI → ITO (Income Tax Officer) → ACIT → DCIT',
    bestFor:
        'Those who want stability and good salary without IAS-level prep',
    rating: 4,
  ),
  _Dept(
    name: 'DRDO',
    fullName: 'Defence Research and Development Organisation',
    emoji: '🔬',
    category: 'research',
    color: Color(0xFF004D40),
    ministry: 'Ministry of Defence',
    hq: 'DRDO Bhawan, New Delhi',
    about:
        'India\'s premier defence R&D body — missiles, radar, electronics, materials. 50+ labs across India. A dream for scientists and engineers.',
    roles: [
      'Scientist B (Graduate entry)',
      'Junior Research Fellow (JRF)',
      'Technician A/B (ITI/Diploma)',
      'RAC entry via GATE/interview'
    ],
    salary: '₹56,000 – ₹1,50,000/month (Scientist B)',
    workLife:
        'Research lab hours 9–6. Project deadlines can be intense but no field duty.',
    perks: [
      'DRDO housing colony',
      'Subsidized schools (Kendriya Vidyalaya priority)',
      'Lab equipment budget',
      'Foreign conference sponsorship',
      'Patent incentives'
    ],
    promotionPath:
        'Scientist B → C → D → E → F → G → Distinguished Scientist',
    bestFor:
        'Engineers / Science grads who want to work on cutting-edge research',
    rating: 4,
  ),
  _Dept(
    name: 'ISRO',
    fullName: 'Indian Space Research Organisation',
    emoji: '🚀',
    category: 'research',
    color: Color(0xFF01579B),
    ministry: 'Dept. of Space, GoI',
    hq: 'Antariksh Bhawan, Bengaluru',
    about:
        'Chandrayaan, Mangalyaan, PSLV. India\'s pride. The ultimate govt tech job for scientists and engineers.',
    roles: [
      'Scientist / Engineer SC (entry)',
      'Technical Assistant',
      'ICRB recruitment via GATE'
    ],
    salary: '₹56,000 – ₹1,60,000/month',
    workLife:
        'Intense during launch seasons. Postings in Bengaluru/Sriharikota common.',
    perks: [
      'ISRO housing/guest houses',
      'Best-in-class labs',
      'Foreign deputation',
      'Canteen + creche',
      'Learning culture'
    ],
    promotionPath: 'SC → SD → SE → SF → SG → Outstanding Scientist',
    bestFor: 'B.Tech/M.Tech grads with GATE score (ECE/CS/ME/AE)',
    rating: 5,
  ),
  _Dept(
    name: 'ONGC',
    fullName: 'Oil and Natural Gas Corporation',
    emoji: '🛢️',
    category: 'central',
    color: Color(0xFFE65100),
    ministry: 'Ministry of Petroleum & Natural Gas',
    hq: 'Deendayal Urja Bhawan, New Delhi',
    about:
        'India\'s largest oil & gas PSU. Exploration, drilling, refining. Remote postings but package is excellent.',
    roles: [
      'Assistant Executive Engineer (AEE)',
      'Junior Assistant Technician (JAT)',
      'Geoscientist (Type A)',
      'Non-Executive (NE) Staff'
    ],
    salary: '₹60,000 – ₹1,80,000/month',
    workLife:
        'Remote offshore/onshore posting possible. 28-on/28-off rotation in field. City posting = 9-5.',
    perks: [
      'Offshore/field allowance (2x-3x salary)',
      'Free accommodation',
      'LTC + medical + children education',
      'ONGC township facilities'
    ],
    promotionPath: 'E1 → E2 → E3 → E4 (Manager) → E5 (DGM) → E6 (GM)',
    bestFor: 'Petroleum/Mechanical/Chemical/Geo engineers',
    rating: 4,
  ),

  // ── Railways ──
  _Dept(
    name: 'Indian Railways',
    fullName: 'Ministry of Railways — All Departments',
    emoji: '🚂',
    category: 'railway',
    color: Color(0xFF4527A0),
    ministry: 'Ministry of Railways',
    hq: 'Rail Bhawan, New Delhi',
    about:
        'World\'s largest employer. 13 lakh+ employees. NTPC, Group D, ALP, JE, SE, RRB Board. Pan India posting.',
    roles: [
      'Group D (track maintainer, helper)',
      'ALP / Technician',
      'NTPC (Guard, CA, Stationmaster)',
      'Junior Engineer (JE)',
      'Senior Section Engineer (SSE)'
    ],
    salary: '₹18,000 – ₹75,000/month',
    workLife:
        'Shift duty for operational posts (SM, Guard). Office posts 9-5.',
    perks: [
      'Free railway pass (self + family)',
      'Quarter allocation',
      'Kendriya Vidyalaya priority',
      'Railway canteen',
      'Medical (CGHS equivalent)'
    ],
    promotionPath:
        'Group D → Group C → Supervisor → JE → SE → Divisional Engineer',
    bestFor:
        'Those who want stability and are willing to be posted anywhere in India',
    rating: 4,
  ),

  // ── Banking ──
  _Dept(
    name: 'SBI',
    fullName: 'State Bank of India',
    emoji: '🏦',
    category: 'banking',
    color: Color(0xFF1B5E20),
    ministry: 'Ministry of Finance',
    hq: 'SBI Bhavan, Mumbai',
    about:
        'India\'s largest public sector bank. SBI PO is the most prestigious banking career with the fastest promotion track.',
    roles: [
      'Probationary Officer (PO)',
      'Clerk (JA/JAA)',
      'Specialist Officer (SO)',
      'Circle Based Officer (CBO)'
    ],
    salary: '₹42,000 – ₹95,000/month',
    workLife: 'Branch: 9-5 (busy in month-end). 6-day week in branches.',
    perks: [
      'Subsidized home loan (2-3% below market)',
      'Medical + LFC',
      'Pension (old employees)',
      'SBI brand weight',
      'Transfer across India'
    ],
    promotionPath:
        'PO → JMGS I → MMGS II → MMGS III → SMGS IV → SMGS V (AGM) → TEG VI (DGM)',
    bestFor: 'Those who want a banking career with fast promotions',
    rating: 4,
  ),
  _Dept(
    name: 'RBI',
    fullName: 'Reserve Bank of India',
    emoji: '💰',
    category: 'banking',
    color: Color(0xFF004D40),
    ministry: 'Ministry of Finance (autonomous)',
    hq: 'Mint Road, Mumbai',
    about:
        'India\'s central bank. Grade B officer is one of the most coveted govt jobs. Research, regulation, monetary policy.',
    roles: [
      'Grade B Officer (DR)',
      'Grade B DEPR / DSIM (Economics/Statistics)',
      'Assistant (Grade C equivalent)',
      'Office Attendant'
    ],
    salary: '₹80,000 – ₹1,20,000/month (Grade B)',
    workLife: 'Best work-life balance in banking. 5-day week. AC offices.',
    perks: [
      'RBI staff quarters (prime locations)',
      'Interest-free / low-rate loans',
      'Excellent medical',
      'Study leave for higher education',
      'Global assignments (IMF, BIS)'
    ],
    promotionPath:
        'Grade B → Grade C → Grade D (DGM) → Grade E (GM) → Grade F → Deputy Governor',
    bestFor: 'High-achievers in banking — worth 2+ years of prep',
    rating: 5,
  ),

  // ── Defence ──
  _Dept(
    name: 'Indian Army',
    fullName: 'Indian Army — Officer & Other Ranks',
    emoji: '🪖',
    category: 'defence',
    color: Color(0xFF33691E),
    ministry: 'Ministry of Defence',
    hq: 'South Block, New Delhi',
    about:
        'NDA/CDS/TES/UES se officer. Soldier GD/Clerk/Technical se jawaan. Pride, adventure, pension, canteen.',
    roles: [
      'Lieutenant (NDA/CDS graduate entry)',
      'JCO (Junior Commissioned Officer)',
      'Soldier GD / Clerk / Technical',
      'Army MNS (Nursing Officer)'
    ],
    salary: '₹56,100 – ₹2,50,000/month (Officer)',
    workLife:
        'Field posting = intense. Peace station = decent. Family accommodation provided.',
    perks: [
      'Army canteen (40-50% discount)',
      'Free medical',
      'Subsidized school (Army Public School)',
      'Pension (after 15 years)',
      'Adventure sports'
    ],
    promotionPath:
        'Lieutenant → Captain → Major → Lt Col → Colonel → Brigadier → MG → Lt Gen → COAS',
    bestFor:
        '12th pass or graduates who want adventure + national service',
    rating: 4,
  ),
  _Dept(
    name: 'CRPF / BSF / CISF',
    fullName: 'Central Armed Police Forces',
    emoji: '🛡️',
    category: 'defence',
    color: Color(0xFF827717),
    ministry: 'Ministry of Home Affairs',
    hq: 'CGO Complex, New Delhi',
    about:
        'India\'s largest CAPF. Border guarding, VIP protection, industrial security. Officer via UPSC CAPF, Constable via SSC CPO.',
    roles: [
      'Assistant Commandant (UPSC CAPF)',
      'Sub Inspector (SSC CPO)',
      'Constable (CHSL/GD)',
      'Head Constable'
    ],
    salary: '₹25,000 – ₹90,000/month',
    workLife:
        'Border/conflict posting = high risk. Field allowance excellent. 60-day leave/year.',
    perks: [
      'Risk/hardship allowance',
      'Free ration',
      'Govt accommodation',
      'Medical',
      'CAPF canteen'
    ],
    promotionPath:
        'Constable → HC → ASI → SI → Inspector → AC → DC → IG → ADG → DG',
    bestFor: 'Those who want challenging field service with good pay',
    rating: 3,
  ),

  // ── State PSU ──
  _Dept(
    name: 'State Electricity Boards',
    fullName: 'UPPCL / MPPKVVCL / HPSEBL etc.',
    emoji: '⚡',
    category: 'state',
    color: Color(0xFFF57F17),
    ministry: 'State Power Departments',
    hq: 'State capitals',
    about:
        'JE, AE, AEE roles in state electricity boards — state-level govt job for engineering grads. Usually home state posting.',
    roles: [
      'Junior Engineer (JE) – Electrical/Civil',
      'Assistant Engineer (AE/AEE)',
      'Revenue Accountant / Cashier',
      'Technician'
    ],
    salary: '₹30,000 – ₹80,000/month',
    workLife: 'Field + office mix. Emergency duty during power cuts.',
    perks: [
      'Concessional electricity at home',
      'State govt medical',
      'Housing in state cities',
      'Job security'
    ],
    promotionPath: 'JE → AE → AEE → EE (Executive Engineer) → SE → CE',
    bestFor:
        'Electrical/Civil engineers who want to stay in their home state',
    rating: 3,
  ),
  _Dept(
    name: 'Teaching (KVS / NVS / DSSSB)',
    fullName: 'Kendriya / Navodaya / Delhi Govt Teachers',
    emoji: '📚',
    category: 'central',
    color: Color(0xFF880E4F),
    ministry: 'Ministry of Education',
    hq: 'Pan India',
    about:
        '18 vacancies per school, 1244 KVs. PGT, TGT, PRT. Excellent leaves, summer vacation, work-life balance.',
    roles: [
      'PRT (Primary Teacher)',
      'TGT (Trained Graduate Teacher)',
      'PGT (Post Graduate Teacher)',
      'Librarian / Lab Assistant'
    ],
    salary: '₹28,000 – ₹60,000/month',
    workLife:
        'Best in any govt job. 60-day summer + winter vacation. 9-4 school hours.',
    perks: [
      'School holidays = your holidays',
      'Free CGHS medical',
      'GPF/NPS',
      'Concessional school fee for own children',
      'Respectful profession'
    ],
    promotionPath:
        'TGT → PGT → Vice Principal → Principal (competitive process)',
    bestFor: 'B.Ed holders who want stability and excellent work-life balance',
    rating: 4,
  ),
];

_Dept? _deptFromApi(Map<String, dynamic> d) {
  try {
    final rawColor = d['color_hex'] as String? ?? '#1565C0';
    final colorVal =
        int.tryParse(rawColor.replaceFirst('#', '0xFF')) ?? 0xFF1565C0;
    return _Dept(
      name: d['name'] as String,
      fullName: d['full_name'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '🏛️',
      category: d['category'] as String? ?? 'central',
      color: Color(colorVal),
      ministry: d['ministry'] as String? ?? '',
      hq: d['hq'] as String? ?? '',
      about: d['about'] as String? ?? '',
      roles: List<String>.from((d['roles'] as List?) ?? []),
      salary: d['salary'] as String? ?? '',
      workLife: d['work_life'] as String? ?? '',
      perks: List<String>.from((d['perks'] as List?) ?? []),
      promotionPath: d['promotion_path'] as String? ?? '',
      bestFor: d['best_for'] as String? ?? '',
      rating: (d['rating'] as num?)?.toInt() ?? 3,
    );
  } catch (_) {
    return null;
  }
}

// ── Main Screen ───────────────────────────────────────────────
class DeptProfilesScreen extends StatefulWidget {
  final ApiService? api;
  const DeptProfilesScreen({super.key, this.api});

  @override
  State<DeptProfilesScreen> createState() => _DeptProfilesScreenState();
}

class _DeptProfilesScreenState extends State<DeptProfilesScreen> {
  String _filter = 'all';
  List<_Dept> _deptList = _depts;
  final List<_Dept> _compareList = [];

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  Future<void> _loadFromBackend() async {
    if (widget.api == null) return;
    try {
      final raw = await widget.api!.getDeptProfiles();
      if (raw.isNotEmpty) {
        final parsed = raw.map(_deptFromApi).whereType<_Dept>().toList();
        if (parsed.isNotEmpty && mounted) {
          setState(() => _deptList = parsed);
        }
      }
    } catch (_) {}
  }

  static const _cats = [
    ('all', 'All'),
    ('central', 'Central'),
    ('defence', 'Defence'),
    ('banking', 'Banking'),
    ('railway', 'Railway'),
    ('research', 'Research'),
    ('state', 'State'),
  ];

  List<_Dept> get _filtered =>
      _filter == 'all' ? _deptList : _deptList.where((d) => d.category == _filter).toList();

  void _onCompareToggle(_Dept dept) {
    setState(() {
      if (_compareList.contains(dept)) {
        _compareList.remove(dept);
      } else if (_compareList.length < 2) {
        _compareList.add(dept);
      }
    });
  }

  void _showDetail(BuildContext context, _Dept dept) {
    final list = _filtered;
    final idx = list.indexOf(dept);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeptSheet(depts: list, initialIndex: idx < 0 ? 0 : idx),
    );
  }

  void _showCompareSheet(BuildContext context) {
    if (_compareList.length < 2) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompareSheet(
        a: _compareList[0],
        b: _compareList[1],
        onClear: () {
          Navigator.pop(context);
          setState(() => _compareList.clear());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF0D1B6E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                          child: Row(children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 4),
                            const Text('🏢 Department Profiles',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                          child: Text(
                              'Salary, perks, promotion — sab kuch ek jagah',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13)),
                        ),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _cats.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final (key, label) = _cats[i];
                              final sel = _filter == key;
                              return GestureDetector(
                                onTap: () => setState(() => _filter = key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? const Color(0xFF1A237E)
                                            : Colors.white,
                                      )),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // Dept cards
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, _compareList.isNotEmpty ? 80 : 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final dept = _filtered[i];
                      final inCompare = _compareList.contains(dept);
                      final showCompare =
                          _compareList.length < 2 || inCompare;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DeptCard(
                          dept: dept,
                          onTap: () => _showDetail(context, dept),
                          onCompare: () => _onCompareToggle(dept),
                          inCompare: inCompare,
                          showCompareButton: showCompare,
                        ),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
            ],
          ),

          // Compare banner
          if (_compareList.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(children: [
                    Text(
                      '${_compareList.length}/2 selected',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    if (_compareList.length == 2) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showCompareSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9933),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Compare Now',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _compareList.clear()),
                      child: const Icon(Icons.close,
                          color: Colors.white70, size: 20),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Dept card ─────────────────────────────────────────────────
class _DeptCard extends StatelessWidget {
  final _Dept dept;
  final VoidCallback onTap;
  final VoidCallback? onCompare;
  final bool inCompare;
  final bool showCompareButton;

  const _DeptCard({
    required this.dept,
    required this.onTap,
    this.onCompare,
    this.inCompare = false,
    this.showCompareButton = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: inCompare
                    ? dept.color.withValues(alpha: 0.6)
                    : dept.color.withValues(alpha: 0.15),
                width: inCompare ? 2 : 1),
            boxShadow: [
              BoxShadow(
                  color: dept.color.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: dept.color.withValues(alpha: 0.06),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: dept.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                          child: Text(dept.emoji,
                              style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(dept.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: dept.color)),
                          const SizedBox(height: 2),
                          // Task 6: maxLines 2, font 10
                          Text(dept.fullName,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                              children: List.generate(
                                  5,
                                  (i) => Icon(
                                        i < dept.rating
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 14,
                                        color: i < dept.rating
                                            ? const Color(0xFFFFB300)
                                            : Colors.grey[300],
                                      ))),
                          const SizedBox(height: 2),
                          Text(dept.ministry.split('–').first,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary)),
                        ]),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(dept.about,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(children: [
                    // Task 5: formatted salary
                    _chip(Icons.currency_rupee_rounded,
                        _formatSalaryShort(dept.salary), dept.color),
                    const SizedBox(width: 8),
                    _chip(Icons.work_outline_rounded, dept.roles.first,
                        dept.color),
                    const Spacer(),
                    // Task 7: compare button
                    if (showCompareButton) ...[
                      GestureDetector(
                        onTap: onCompare,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: inCompare
                                ? dept.color.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: dept.color.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            inCompare ? '✓ Added' : '+ Compare',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: dept.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.chevron_right_rounded,
                        color: dept.color.withValues(alpha: 0.5)),
                  ]),
                ),
              ]),
        ),
      );

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

// ── Detail bottom sheet (with swipe nav) ─────────────────────
class _DeptSheet extends StatefulWidget {
  final List<_Dept> depts;
  final int initialIndex;
  const _DeptSheet({required this.depts, required this.initialIndex});

  @override
  State<_DeptSheet> createState() => _DeptSheetState();
}

class _DeptSheetState extends State<_DeptSheet> {
  late PageController _pc;
  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _pc = PageController(initialPage: _idx);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Column(children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            // Counter
            Text(
              '${_idx + 1} of ${widget.depts.length}',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600),
            ),
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: widget.depts.length,
                onPageChanged: (i) => setState(() => _idx = i),
                itemBuilder: (_, i) =>
                    _buildPage(widget.depts[i], context),
              ),
            ),
          ]),
          // Left arrow
          if (_idx > 0)
            const Positioned(
              left: 4,
              top: 60,
              bottom: 80,
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.chevron_left_rounded,
                        size: 36, color: Colors.black54),
                  ),
                ),
              ),
            ),
          // Right arrow
          if (_idx < widget.depts.length - 1)
            const Positioned(
              right: 4,
              top: 60,
              bottom: 80,
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.chevron_right_rounded,
                        size: 36, color: Colors.black54),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(_Dept dept, BuildContext context) {
    return Column(children: [
      // Task 4: category-specific gradient header + diagonal pattern
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _categoryGradient(dept.category),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(painter: _DiagonalPainter()),
            ),
          ),
          Row(children: [
            // Task 4: bigger emoji (48)
            Text(dept.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(dept.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                  // Task 1: maxLines 2 instead of 1
                  Text(dept.fullName,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11),
                      maxLines: 2),
                  const SizedBox(height: 4),
                  Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                                i < dept.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 14,
                                color: i < dept.rating
                                    ? const Color(0xFFFFB300)
                                    : Colors.white.withValues(alpha: 0.3),
                              ))),
                ])),
          ]),
        ]),
      ),
      // Scrollable content
      Expanded(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _section('ℹ️ About', dept.about),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _infoBox('💰 Salary', dept.salary, dept.color)),
            const SizedBox(width: 10),
            Expanded(
                child:
                    _infoBox('🏛️ Ministry', dept.ministry, dept.color)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _infoBox('📍 HQ', dept.hq, dept.color)),
            const SizedBox(width: 10),
            Expanded(
                child: _infoBox(
                    '⚖️ Work-Life', dept.workLife, dept.color)),
          ]),
          const SizedBox(height: 16),
          _sectionLabel('👔 Entry Roles'),
          const SizedBox(height: 8),
          ...dept.roles.map((r) => _bullet(r, dept.color)),
          const SizedBox(height: 16),
          _sectionLabel('🎁 Perks & Benefits'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dept.perks
                .map((p) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: dept.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: dept.color.withValues(alpha: 0.2)),
                      ),
                      child: Text(p,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: dept.color)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _sectionLabel('📈 Promotion Path'),
          const SizedBox(height: 8),
          _PromotionBar(path: dept.promotionPath, color: dept.color),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dept.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: dept.color.withValues(alpha: 0.2)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Best For',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: dept.color)),
                  const SizedBox(height: 4),
                  Text(dept.bestFor,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                ]),
          ),
          const SizedBox(height: 8),
        ]),
      )),
      // Close button
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: dept.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Close',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ),
    ]);
  }

  Widget _section(String title, String body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        Text(body,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45)),
      ]);

  Widget _sectionLabel(String t) => Text(t,
      style:
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 14));

  // Task 1: removed maxLines from val text
  Widget _infoBox(String label, String val, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 4),
              Text(val,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3)),
            ]),
      );

  Widget _bullet(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary))),
            ]),
      );
}

// ── Promotion path bar ────────────────────────────────────────
class _PromotionBar extends StatelessWidget {
  final String path;
  final Color color;
  const _PromotionBar({required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    final steps = path.split('→').map((s) => s.trim()).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (int i = 0; i < steps.length; i++) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: i == 0 ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(steps[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: i == 0 ? Colors.white : color,
                )),
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 14, color: color.withValues(alpha: 0.5)),
            ),
        ],
      ]),
    );
  }
}

// ── Compare sheet ─────────────────────────────────────────────
class _CompareSheet extends StatelessWidget {
  final _Dept a;
  final _Dept b;
  final VoidCallback onClear;
  const _CompareSheet(
      {required this.a, required this.b, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final aSalary = _parseSalaryMax(a.salary);
    final bSalary = _parseSalaryMax(b.salary);

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        const Text('Department Comparison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              // Dept headers
              Row(children: [
                Expanded(child: _deptHeader(a)),
                const SizedBox(width: 10),
                Expanded(child: _deptHeader(b)),
              ]),
              const SizedBox(height: 12),
              // Comparison rows
              _row('💰 Salary', _formatSalaryShort(a.salary),
                  _formatSalaryShort(b.salary),
                  better: aSalary >= bSalary ? 0 : 1),
              _row('⭐ Rating', '${a.rating}/5', '${b.rating}/5',
                  better: a.rating >= b.rating ? 0 : 1),
              _row('👔 Roles', '${a.roles.length} roles',
                  '${b.roles.length} roles',
                  better: a.roles.length >= b.roles.length ? 0 : 1),
              _row('🎁 Perks', '${a.perks.length} perks',
                  '${b.perks.length} perks',
                  better: a.perks.length >= b.perks.length ? 0 : 1),
              _row('📍 HQ', a.hq, b.hq, better: -1),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Clear Comparison',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _deptHeader(_Dept d) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: _categoryGradient(d.category),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(d.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(d.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ]),
      );

  Widget _row(String label, String valA, String valB, {required int better}) {
    const goodBg = Color(0xFFE8F5E9);
    const goodText = Color(0xFF1A6B3C);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: better == 0 ? goodBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(valA,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: better == 0 ? goodText : AppColors.textSecondary)),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: better == 1 ? goodBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(valB,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: better == 1 ? goodText : AppColors.textSecondary)),
          ),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }
}
