// lib/models/job_model.dart

class Job {
  final int    id;
  final String title;
  final String department;
  final String source;
  final String sourceUrl;
  final String category;
  final int    vacancies;
  final String lastDate;
  final int    daysLeft;
  final String urgency;   // green / yellow / red
  final int    fee;
  final bool   isFree;
  final List<String> qualifications;
  final List<String> states;
  final int    ageMin;
  final int    ageMax;
  final List<String>? documentsNeeded;
  final String? jobStatus; // 'saved' | 'applied' | null
  final String? payScale;

  const Job({
    required this.id,
    required this.title,
    required this.department,
    required this.source,
    required this.sourceUrl,
    required this.category,
    required this.vacancies,
    required this.lastDate,
    required this.daysLeft,
    required this.urgency,
    required this.fee,
    required this.isFree,
    required this.qualifications,
    required this.states,
    required this.ageMin,
    required this.ageMax,
    this.documentsNeeded,
    this.jobStatus,
    this.payScale,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id:             json['id']         ?? 0,
      title:          json['title']      ?? '',
      department:     json['department'] ?? '',
      source:         json['source']     ?? '',
      sourceUrl:      json['source_url'] ?? '',
      category:       json['category']   ?? 'others',
      vacancies:      json['vacancies']  ?? 0,
      lastDate:       json['last_date']  ?? '',
      daysLeft:       json['days_left']  ?? 30,
      urgency:        json['urgency']    ?? 'green',
      fee:            json['fee']        ?? 0,
      isFree:         json['is_free']    ?? false,
      qualifications: List<String>.from(json['qualifications'] ?? []),
      states:         List<String>.from(json['states'] ?? ['all']),
      ageMin:         json['age_min']    ?? 18,
      ageMax:         json['age_max']    ?? 40,
      documentsNeeded: json['documents_needed'] != null
          ? List<String>.from(json['documents_needed'])
          : null,
      jobStatus: json['job_status'] as String?,
      payScale: json['pay_scale'] as String?,
    );
  }

  Job copyWith({String? jobStatus}) => Job(
    id: id, title: title, department: department, source: source,
    sourceUrl: sourceUrl, category: category, vacancies: vacancies,
    lastDate: lastDate, daysLeft: daysLeft, urgency: urgency,
    fee: fee, isFree: isFree, qualifications: qualifications,
    states: states, ageMin: ageMin, ageMax: ageMax,
    documentsNeeded: documentsNeeded,
    jobStatus: jobStatus ?? this.jobStatus,
    payScale: payScale,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'department': department,
    'source': source, 'source_url': sourceUrl, 'category': category,
    'vacancies': vacancies, 'last_date': lastDate, 'days_left': daysLeft,
    'urgency': urgency, 'fee': fee, 'is_free': isFree,
    'qualifications': qualifications, 'states': states,
    'age_min': ageMin, 'age_max': ageMax,
    'pay_scale': payScale,
  };

  // ── Eligibility match score (0-4) against user profile ──
  // Criteria: state, education, age, job-type preference
  int matchScore(UserProfile profile) {
    int score = 0;
    const eduLevels = {
      '8th': 1, '10th': 2, '12th': 3, 'diploma': 3,
      'graduate': 4, 'postgraduate': 5,
    };
    // 1. State
    final statesLower = states.map((s) => s.toLowerCase()).toList();
    if (statesLower.contains('all') || statesLower.isEmpty ||
        profile.state.toLowerCase() == 'all india' ||
        statesLower.contains(profile.state.toLowerCase())) {
      score++;
    }
    // 2. Education
    final userLevel = eduLevels[profile.education] ?? 4;
    if (qualifications.isEmpty ||
        qualifications.any((q) => userLevel >= (eduLevels[q] ?? 4))) {
      score++;
    }
    // 3. Age
    if (profile.age >= ageMin && profile.age <= ageMax) score++;
    // 4. Job type preference
    if (profile.jobTypes.isEmpty || profile.jobTypes.contains(category)) {
      score++;
    }
    return score;
  }

  // ── Text cleaning — remove HTML junk from scraped data ──
  static String _clean(String raw) {
    if (raw.isEmpty) return raw;
    var t = raw
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'&#\d+;'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = t.split(' ');
    final upperCount = words.where((w) =>
        w.length > 2 && w == w.toUpperCase() &&
        RegExp(r'^[A-Z]+$').hasMatch(w)).length;
    if (upperCount > words.length ~/ 2) {
      t = words.map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()
      ).join(' ');
    }
    return t;
  }

  String get cleanTitle      => _clean(title);
  String get cleanDepartment => _clean(department);

  String get categoryEmoji {
    const map = {
      'railway': '🚂', 'banking': '🏦', 'ssc': '📋',
      'teaching': '📚', 'police': '👮', 'defence': '⭐',
      'upsc': '🏛️', 'anganwadi': '🌸', 'psu': '🏭',
      'medical': '🏥', 'research': '🔬', 'engineering': '⚙️',
      'legal': '⚖️', 'postal': '📮', 'admin': '🗂️',
      'it_tech': '💻', 'accounts': '💰', 'forest': '🌳',
    };
    return map[category] ?? '💼';
  }

  String get categoryLabel {
    const map = {
      'railway': 'Railway', 'banking': 'Banking', 'ssc': 'SSC',
      'teaching': 'Teaching', 'police': 'Police', 'defence': 'Defence',
      'upsc': 'UPSC/IAS', 'anganwadi': 'Anganwadi', 'psu': 'PSU',
      'medical': 'Medical', 'research': 'Research', 'engineering': 'Engineering',
      'legal': 'Legal', 'postal': 'Postal', 'admin': 'Admin',
      'it_tech': 'IT/Tech', 'accounts': 'Accounts', 'forest': 'Forest',
    };
    return map[category] ?? 'Others';
  }

  String get urgencyText {
    if (daysLeft <= 0)  return 'Expired';
    if (daysLeft == 1)  return 'Kal last date!';
    if (daysLeft <= 3)  return '$daysLeft din bacha hai!';
    if (daysLeft <= 7)  return '$daysLeft din bache hain';
    if (daysLeft <= 14) return '$daysLeft din bacha hai';
    return '$daysLeft din bache hain';
  }

  String get feeText => isFree ? 'Free' : '₹$fee';

  String get vacanciesText {
    if (vacancies == 0) return 'N/A';
    if (vacancies >= 1000) return '${(vacancies / 1000).toStringAsFixed(1)}K+';
    return '$vacancies posts';
  }
}


// ── Personal info — stored locally only, never sent to backend ──────────────
class PersonalInfo {
  final String name;
  final String fatherName;
  final String motherName;
  final String dob;          // DD/MM/YYYY
  final String gender;       // Male / Female / Other
  final String category;     // General / OBC / SC / ST / EWS
  final String phone;
  final String email;
  final String address;
  final String district;
  final String state;
  final String pincode;
  final String aadharLast4;  // Only last 4 digits for reference

  const PersonalInfo({
    this.name          = '',
    this.fatherName    = '',
    this.motherName    = '',
    this.dob           = '',
    this.gender        = '',
    this.category      = '',
    this.phone         = '',
    this.email         = '',
    this.address       = '',
    this.district      = '',
    this.state         = '',
    this.pincode       = '',
    this.aadharLast4   = '',
  });

  bool get isEmpty => name.isEmpty && phone.isEmpty && email.isEmpty;

  int get filledCount => [
    name, fatherName, dob, gender, category,
    phone, email, address, district, state, pincode,
  ].where((f) => f.isNotEmpty).length;

  factory PersonalInfo.fromJson(Map<String, dynamic> j) => PersonalInfo(
    name:         j['name']         as String? ?? '',
    fatherName:   j['father_name']  as String? ?? '',
    motherName:   j['mother_name']  as String? ?? '',
    dob:          j['dob']          as String? ?? '',
    gender:       j['gender']       as String? ?? '',
    category:     j['category']     as String? ?? '',
    phone:        j['phone']        as String? ?? '',
    email:        j['email']        as String? ?? '',
    address:      j['address']      as String? ?? '',
    district:     j['district']     as String? ?? '',
    state:        j['state']        as String? ?? '',
    pincode:      j['pincode']      as String? ?? '',
    aadharLast4:  j['aadhar_last4'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name':         name,
    'father_name':  fatherName,
    'mother_name':  motherName,
    'dob':          dob,
    'gender':       gender,
    'category':     category,
    'phone':        phone,
    'email':        email,
    'address':      address,
    'district':     district,
    'state':        state,
    'pincode':      pincode,
    'aadhar_last4': aadharLast4,
  };
}


// ── Alert Rule — stored locally, never sent to backend ───────────────────────
class AlertRule {
  final String id;        // timestamp-based unique ID
  final String keyword;   // '' = any keyword
  final String state;     // '' = any state
  final String category;  // '' = any category
  final bool   freeOnly;
  final bool   isActive;

  const AlertRule({
    required this.id,
    this.keyword  = '',
    this.state    = '',
    this.category = '',
    this.freeOnly = false,
    this.isActive = true,
  });

  bool get isEmpty => keyword.isEmpty && state.isEmpty && category.isEmpty;

  String get label {
    final parts = <String>[];
    if (keyword.isNotEmpty)  parts.add('"$keyword"');
    if (state.isNotEmpty)    parts.add(state);
    if (category.isNotEmpty) parts.add(category);
    if (freeOnly)            parts.add('Free');
    return parts.isEmpty ? 'All Jobs' : parts.join(' + ');
  }

  bool matches(Job job) {
    if (!isActive) return false;
    if (freeOnly && !job.isFree) return false;
    if (keyword.isNotEmpty &&
        !job.title.toLowerCase().contains(keyword.toLowerCase()) &&
        !job.department.toLowerCase().contains(keyword.toLowerCase())) return false;
    if (state.isNotEmpty) {
      final jobStates = job.states.map((s) => s.toLowerCase()).toList();
      if (!jobStates.contains('all') && !jobStates.contains(state.toLowerCase())) return false;
    }
    if (category.isNotEmpty && job.category != category) return false;
    return true;
  }

  factory AlertRule.fromJson(Map<String, dynamic> j) => AlertRule(
    id:       j['id']       as String? ?? '',
    keyword:  j['keyword']  as String? ?? '',
    state:    j['state']    as String? ?? '',
    category: j['category'] as String? ?? '',
    freeOnly: j['free_only'] as bool?  ?? false,
    isActive: j['is_active'] as bool?  ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'keyword': keyword, 'state': state,
    'category': category, 'free_only': freeOnly, 'is_active': isActive,
  };

  AlertRule copyWith({
    String? keyword, String? state, String? category,
    bool? freeOnly, bool? isActive,
  }) => AlertRule(
    id:       id,
    keyword:  keyword  ?? this.keyword,
    state:    state    ?? this.state,
    category: category ?? this.category,
    freeOnly: freeOnly ?? this.freeOnly,
    isActive: isActive ?? this.isActive,
  );
}


class UserProfile {
  final int?   id;
  final String fcmToken;
  final String state;
  final String education;
  final String category;
  final int    age;
  final List<String> jobTypes;
  final String language;

  const UserProfile({
    this.id,
    required this.fcmToken,
    required this.state,
    required this.education,
    required this.category,
    required this.age,
    required this.jobTypes,
    this.language = 'hinglish',
  });

  Map<String, dynamic> toJson() => {
    'fcm_token': fcmToken,
    'state':     state,
    'education': education,
    'category':  category,
    'age':       age,
    'job_types': jobTypes,
    'language':  language,
  };

  UserProfile copyWith({
    int? id, String? fcmToken, String? state, String? education,
    String? category, int? age, List<String>? jobTypes, String? language,
  }) {
    return UserProfile(
      id:        id        ?? this.id,
      fcmToken:  fcmToken  ?? this.fcmToken,
      state:     state     ?? this.state,
      education: education ?? this.education,
      category:  category  ?? this.category,
      age:       age       ?? this.age,
      jobTypes:  jobTypes  ?? this.jobTypes,
      language:  language  ?? this.language,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CurrentAffair
// ─────────────────────────────────────────────────────────────
class CurrentAffair {
  final int    id;
  final String title;
  final String summary;
  final String category;   // national / international / economy / science / sports / misc
  final String pubDate;
  final String sourceName;
  final String sourceUrl;

  const CurrentAffair({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.pubDate,
    required this.sourceName,
    required this.sourceUrl,
  });

  factory CurrentAffair.fromJson(Map<String, dynamic> j) => CurrentAffair(
    id:         j['id']          ?? 0,
    title:      j['title']       ?? '',
    summary:    j['summary']     ?? '',
    category:   j['category']    ?? 'misc',
    pubDate:    j['pub_date']    ?? '',
    sourceName: j['source_name'] ?? '',
    sourceUrl:  j['source_url']  ?? '',
  );
}
