// lib/screens/dept_profiles_screen.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

// ── Data model ─────────────────────────────────────────────
class _Dept {
  final String name;
  final String fullName;
  final String emoji;
  final String category;          // 'central' | 'defence' | 'banking' | 'railway' | 'research' | 'state'
  final Color  color;
  final String ministry;
  final String hq;
  final String about;
  final List<String> roles;        // common entry roles
  final String salary;             // range
  final String workLife;           // work-life balance description
  final List<String> perks;
  final String promotionPath;
  final String bestFor;
  final int    rating;             // 1-5 (overall attractiveness)

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
    about: 'India\'s most powerful bureaucrats. Become District Collector, SP, Commissioner. Control over policy, law & order, and revenue.',
    roles: ['IAS – District Collector / SDM', 'IPS – SP / DIG / Inspector General', 'IRS – Income Tax / Customs Officer'],
    salary: '₹56,100 – ₹2,50,000/month',
    workLife: 'Field postings are hectic (24x7). Better balance at senior levels.',
    perks: ['Government bungalow', 'Government car + driver', 'Z/Y security', 'Priority medical (CGHS)', 'Staff at home', 'Power & prestige'],
    promotionPath: 'SDM → ADM → DM/Collector → Commissioner → Secretary → Cabinet Secretary',
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
    about: 'SSC CGL ke through Inspector Income Tax, Excise, CBI, CAG Auditor, CSS. Stable central govt job with Grade Pay 4200-4600.',
    roles: ['Inspector Income Tax', 'Inspector Central Excise', 'Sub Inspector CBI', 'Auditor (CAG/CGDA)', 'CSS (MEA, PMO postings)'],
    salary: '₹35,000 – ₹65,000/month',
    workLife: 'IT/Excise inspection field duty, Audit 9-5. Office based stable.',
    perks: ['HRA 27% in X cities', 'LTC (hometown + abroad)', 'CGHS medical', 'Reimbursements', 'Subsidized canteen'],
    promotionPath: 'Inspector → SI → ITO (Income Tax Officer) → ACIT → DCIT',
    bestFor: 'Those who want stability and good salary without IAS-level prep',
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
    about: 'India\'s premier defence R&D body — missiles, radar, electronics, materials. 50+ labs across India. A dream for scientists and engineers.',
    roles: ['Scientist B (Graduate entry)', 'Junior Research Fellow (JRF)', 'Technician A/B (ITI/Diploma)', 'RAC entry via GATE/interview'],
    salary: '₹56,000 – ₹1,50,000/month (Scientist B)',
    workLife: 'Research lab hours 9–6. Project deadlines can be intense but no field duty.',
    perks: ['DRDO housing colony', 'Subsidized schools (Kendriya Vidyalaya priority)', 'Lab equipment budget', 'Foreign conference sponsorship', 'Patent incentives'],
    promotionPath: 'Scientist B → C → D → E → F → G → Distinguished Scientist',
    bestFor: 'Engineers / Science grads who want to work on cutting-edge research',
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
    about: 'Chandrayaan, Mangalyaan, PSLV. India\'s pride. The ultimate govt tech job for scientists and engineers.',
    roles: ['Scientist / Engineer SC (entry)', 'Technical Assistant', 'ICRB recruitment via GATE'],
    salary: '₹56,000 – ₹1,60,000/month',
    workLife: 'Intense during launch seasons. Postings in Bengaluru/Sriharikota common.',
    perks: ['ISRO housing/guest houses', 'Best-in-class labs', 'Foreign deputation', 'Canteen + creche', 'Learning culture'],
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
    about: 'India\'s largest oil & gas PSU. Exploration, drilling, refining. Remote postings but package is excellent.',
    roles: ['Assistant Executive Engineer (AEE)', 'Junior Assistant Technician (JAT)', 'Geoscientist (Type A)', 'Non-Executive (NE) Staff'],
    salary: '₹60,000 – ₹1,80,000/month',
    workLife: 'Remote offshore/onshore posting possible. 28-on/28-off rotation in field. City posting = 9-5.',
    perks: ['Offshore/field allowance (2x-3x salary)', 'Free accommodation', 'LTC + medical + children education', 'ONGC township facilities'],
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
    about: 'World\'s largest employer. 13 lakh+ employees. NTPC, Group D, ALP, JE, SE, RRB Board. Pan India posting.',
    roles: ['Group D (track maintainer, helper)', 'ALP / Technician', 'NTPC (Guard, CA, Stationmaster)', 'Junior Engineer (JE)', 'Senior Section Engineer (SSE)'],
    salary: '₹18,000 – ₹75,000/month',
    workLife: 'Shift duty for operational posts (SM, Guard). Office posts 9-5.',
    perks: ['Free railway pass (self + family)', 'Quarter allocation', 'Kendriya Vidyalaya priority', 'Railway canteen', 'Medical (CGHS equivalent)'],
    promotionPath: 'Group D → Group C → Supervisor → JE → SE → Divisional Engineer',
    bestFor: 'Those who want stability and are willing to be posted anywhere in India',
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
    about: 'India\'s largest public sector bank. SBI PO is the most prestigious banking career with the fastest promotion track.',
    roles: ['Probationary Officer (PO)', 'Clerk (JA/JAA)', 'Specialist Officer (SO)', 'Circle Based Officer (CBO)'],
    salary: '₹42,000 – ₹95,000/month',
    workLife: 'Branch: 9-5 (busy in month-end). 6-day week in branches.',
    perks: ['Subsidized home loan (2-3% below market)', 'Medical + LFC', 'Pension (old employees)', 'SBI brand weight', 'Transfer across India'],
    promotionPath: 'PO → JMGS I → MMGS II → MMGS III → SMGS IV → SMGS V (AGM) → TEG VI (DGM)',
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
    about: 'India\'s central bank. Grade B officer is one of the most coveted govt jobs. Research, regulation, monetary policy.',
    roles: ['Grade B Officer (DR)', 'Grade B DEPR / DSIM (Economics/Statistics)', 'Assistant (Grade C equivalent)', 'Office Attendant'],
    salary: '₹80,000 – ₹1,20,000/month (Grade B)',
    workLife: 'Best work-life balance in banking. 5-day week. AC offices.',
    perks: ['RBI staff quarters (prime locations)', 'Interest-free / low-rate loans', 'Excellent medical', 'Study leave for higher education', 'Global assignments (IMF, BIS)'],
    promotionPath: 'Grade B → Grade C → Grade D (DGM) → Grade E (GM) → Grade F → Deputy Governor',
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
    about: 'NDA/CDS/TES/UES se officer. Soldier GD/Clerk/Technical se jawaan. Pride, adventure, pension, canteen.',
    roles: ['Lieutenant (NDA/CDS graduate entry)', 'JCO (Junior Commissioned Officer)', 'Soldier GD / Clerk / Technical', 'Army MNS (Nursing Officer)'],
    salary: '₹56,100 – ₹2,50,000/month (Officer)',
    workLife: 'Field posting = intense. Peace station = decent. Family accommodation provided.',
    perks: ['Army canteen (40-50% discount)', 'Free medical', 'Subsidized school (Army Public School)', 'Pension (after 15 years)', 'Adventure sports'],
    promotionPath: 'Lieutenant → Captain → Major → Lt Col → Colonel → Brigadier → MG → Lt Gen → COAS',
    bestFor: '12th pass or graduates who want adventure + national service',
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
    about: 'India\'s largest CAPF. Border guarding, VIP protection, industrial security. Officer via UPSC CAPF, Constable via SSC CPO.',
    roles: ['Assistant Commandant (UPSC CAPF)', 'Sub Inspector (SSC CPO)', 'Constable (CHSL/GD)', 'Head Constable'],
    salary: '₹25,000 – ₹90,000/month',
    workLife: 'Border/conflict posting = high risk. Field allowance excellent. 60-day leave/year.',
    perks: ['Risk/hardship allowance', 'Free ration', 'Govt accommodation', 'Medical', 'CAPF canteen'],
    promotionPath: 'Constable → HC → ASI → SI → Inspector → AC → DC → IG → ADG → DG',
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
    about: 'JE, AE, AEE roles in state electricity boards — state-level govt job for engineering grads. Usually home state posting.',
    roles: ['Junior Engineer (JE) – Electrical/Civil', 'Assistant Engineer (AE/AEE)', 'Revenue Accountant / Cashier', 'Technician'],
    salary: '₹30,000 – ₹80,000/month',
    workLife: 'Field + office mix. Emergency duty during power cuts.',
    perks: ['Concessional electricity at home', 'State govt medical', 'Housing in state cities', 'Job security'],
    promotionPath: 'JE → AE → AEE → EE (Executive Engineer) → SE → CE',
    bestFor: 'Electrical/Civil engineers who want to stay in their home state',
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
    about: '18 vacancies per school, 1244 KVs. PGT, TGT, PRT. Excellent leaves, summer vacation, work-life balance.',
    roles: ['PRT (Primary Teacher)', 'TGT (Trained Graduate Teacher)', 'PGT (Post Graduate Teacher)', 'Librarian / Lab Assistant'],
    salary: '₹28,000 – ₹60,000/month',
    workLife: 'Best in any govt job. 60-day summer + winter vacation. 9-4 school hours.',
    perks: ['School holidays = your holidays', 'Free CGHS medical', 'GPF/NPS', 'Concessional school fee for own children', 'Respectful profession'],
    promotionPath: 'TGT → PGT → Vice Principal → Principal (competitive process)',
    bestFor: 'B.Ed holders who want stability and excellent work-life balance',
    rating: 4,
  ),
];

// ── Main Screen ─────────────────────────────────────────────
class DeptProfilesScreen extends StatefulWidget {
  const DeptProfilesScreen({super.key});

  @override
  State<DeptProfilesScreen> createState() => _DeptProfilesScreenState();
}

class _DeptProfilesScreenState extends State<DeptProfilesScreen> {
  String _filter = 'all';

  static const _cats = [
    ('all',     'All'),
    ('central', 'Central'),
    ('defence', 'Defence'),
    ('banking', 'Banking'),
    ('railway', 'Railway'),
    ('research','Research'),
    ('state',   'State'),
  ];

  List<_Dept> get _filtered =>
      _filter == 'all' ? _depts : _depts.where((d) => d.category == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
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
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 4),
                        const Text('🏢 Department Profiles',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Text('Salary, perks, promotion — sab kuch ek jagah',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                    ),
                    // Filter chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _cats.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final (key, label) = _cats[i];
                          final sel = _filter == key;
                          return GestureDetector(
                            onTap: () => setState(() => _filter = key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel ? Colors.white : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? const Color(0xFF1A237E) : Colors.white,
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
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final dept = _filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DeptCard(dept: dept, onTap: () => _showDetail(context, dept)),
                  );
                },
                childCount: _filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, _Dept dept) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeptSheet(dept: dept),
    );
  }
}

// ── Dept card ───────────────────────────────────────────────
class _DeptCard extends StatelessWidget {
  final _Dept dept;
  final VoidCallback onTap;
  const _DeptCard({required this.dept, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dept.color.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: dept.color.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top colored bar + header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: dept.color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: dept.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(dept.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dept.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: dept.color)),
              const SizedBox(height: 2),
              Text(dept.fullName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            // Rating stars
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: List.generate(5, (i) => Icon(
                i < dept.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: i < dept.rating ? const Color(0xFFFFB300) : Colors.grey[300],
              ))),
              const SizedBox(height: 2),
              Text(dept.ministry.split('–').first, style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
        // About
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(dept.about, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(children: [
            _chip(Icons.currency_rupee_rounded, dept.salary.split('–').first + '…', dept.color),
            const SizedBox(width: 8),
            _chip(Icons.work_outline_rounded, dept.roles.first, dept.color),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: dept.color.withValues(alpha: 0.5)),
          ]),
        ),
      ]),
    ),
  );

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 90),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ]),
  );
}

// ── Detail bottom sheet ─────────────────────────────────────
class _DeptSheet extends StatelessWidget {
  final _Dept dept;
  const _DeptSheet({required this.dept});

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(children: [
      // Handle
      const SizedBox(height: 12),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      // Header
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [dept.color, dept.color.withValues(alpha: 0.75)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Text(dept.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dept.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            Text(dept.fullName, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: List.generate(5, (i) => Icon(
              i < dept.rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 14,
              color: i < dept.rating ? const Color(0xFFFFB300) : Colors.white.withValues(alpha: 0.3),
            ))),
          ])),
        ]),
      ),
      // Content
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // About
          _section('ℹ️ About', dept.about),
          // Key info grid
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _infoBox('💰 Salary', dept.salary, dept.color)),
            const SizedBox(width: 10),
            Expanded(child: _infoBox('🏛️ Ministry', dept.ministry, dept.color)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _infoBox('📍 HQ', dept.hq, dept.color)),
            const SizedBox(width: 10),
            Expanded(child: _infoBox('⚖️ Work-Life', dept.workLife, dept.color)),
          ]),
          // Entry roles
          const SizedBox(height: 16),
          _sectionLabel('👔 Entry Roles'),
          const SizedBox(height: 8),
          ...dept.roles.map((r) => _bullet(r)),
          // Perks
          const SizedBox(height: 16),
          _sectionLabel('🎁 Perks & Benefits'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: dept.perks.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: dept.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: dept.color.withValues(alpha: 0.2)),
              ),
              child: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: dept.color)),
            )).toList(),
          ),
          // Promotion path
          const SizedBox(height: 16),
          _sectionLabel('📈 Promotion Path'),
          const SizedBox(height: 8),
          _PromotionBar(path: dept.promotionPath, color: dept.color),
          // Best for
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dept.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dept.color.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✅ Best For', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: dept.color)),
              const SizedBox(height: 4),
              Text(dept.bestFor, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ),
    ]),
  );

  Widget _section(String title, String body) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    const SizedBox(height: 6),
    Text(body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
  ]);

  Widget _sectionLabel(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14));

  Widget _infoBox(String label, String val, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
    ]),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(margin: const EdgeInsets.only(top: 5), width: 6, height: 6,
          decoration: BoxDecoration(color: dept.color, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
    ]),
  );
}

// ── Promotion path bar ──────────────────────────────────────
class _PromotionBar extends StatelessWidget {
  final String path;
  final Color  color;
  const _PromotionBar({required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    final steps = path.split('→').map((s) => s.trim()).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (int i = 0; i < steps.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: i == 0 ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(steps[i],
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: i == 0 ? Colors.white : color,
                )),
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_forward_rounded, size: 14, color: color.withValues(alpha: 0.5)),
            ),
        ],
      ]),
    );
  }
}
