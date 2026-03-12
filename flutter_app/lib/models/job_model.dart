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
    );
  }

  // Category display info
  String get categoryEmoji {
    const map = {
      'railway': '🚂', 'banking': '🏦', 'ssc': '📋',
      'teaching': '📚', 'police': '👮', 'defence': '⭐',
      'upsc': '🏛️', 'anganwadi': '🌸', 'psu': '🏭',
    };
    return map[category] ?? '💼';
  }

  String get categoryLabel {
    const map = {
      'railway': 'Railway', 'banking': 'Banking', 'ssc': 'SSC',
      'teaching': 'Teaching', 'police': 'Police', 'defence': 'Defence',
      'upsc': 'UPSC/IAS', 'anganwadi': 'Anganwadi', 'psu': 'PSU',
    };
    return map[category] ?? 'Others';
  }

  // Urgency label in Hinglish
  String get urgencyText {
    if (daysLeft <= 0)  return 'Expired';
    if (daysLeft == 1)  return 'Kal last date!';
    if (daysLeft <= 3)  return '$daysLeft din bacha hai!';
    if (daysLeft <= 7)  return '$daysLeft din bache hain';
    if (daysLeft <= 14) return '$daysLeft din bacha hai';
    return '$daysLeft din bache hain';
  }

  // Fee display
  String get feeText => isFree ? 'Free' : '₹$fee';

  // Vacancies display
  String get vacanciesText {
    if (vacancies == 0) return 'N/A';
    if (vacancies >= 1000) return '${(vacancies / 1000).toStringAsFixed(1)}K+ posts';
    return '$vacancies posts';
  }
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
