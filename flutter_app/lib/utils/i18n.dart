// lib/utils/i18n.dart
//
// Lightweight runtime localization. Three languages (hinglish / hi / en),
// keyed lookups via L10n.tr('home_jobs'). Adding a new string = add one
// entry to the _strings map; falls back to English when a translation is
// missing instead of crashing.
//
// Why not flutter_localizations + ARB files? — 99% of strings in this app
// are short labels. The ARB toolchain is overkill (codegen, build_runner,
// extra build time) for a ~50-entry dictionary, and the audience is
// English-comfortable bilinguals so missing keys degrade gracefully.
import 'package:shared_preferences/shared_preferences.dart';

class L10n {
  static const String kPrefKey = 'app_language';

  // 'hinglish' is the default — the app's existing copy is already Hinglish.
  static String _current = 'hinglish';
  static String get current => _current;

  static const supported = <String, String>{
    'hinglish': 'Hinglish (Default)',
    'hi':       'हिंदी',
    'en':       'English',
  };

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kPrefKey);
    if (saved != null && supported.containsKey(saved)) {
      _current = saved;
    }
  }

  static Future<void> setLanguage(String code) async {
    if (!supported.containsKey(code)) return;
    _current = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefKey, code);
  }

  static String tr(String key) {
    final row = _strings[key];
    if (row == null) return key;
    return row[_current] ?? row['en'] ?? key;
  }

  // ── Dictionary ────────────────────────────────────────────────
  //
  // Order: hinglish, hi, en. Hinglish first because it's the default and
  // matches the existing UI copy, so app stays visually consistent until
  // a user explicitly picks another language.
  static const Map<String, Map<String, String>> _strings = {
    // Bottom nav
    'nav_jobs':    {'hinglish': 'Jobs',    'hi': 'नौकरियाँ',  'en': 'Jobs'},
    'nav_search':  {'hinglish': 'Search',  'hi': 'खोज',      'en': 'Search'},
    'nav_saved':   {'hinglish': 'Saved',   'hi': 'सेव',      'en': 'Saved'},
    'nav_tools':   {'hinglish': 'Tools',   'hi': 'टूल्स',    'en': 'Tools'},
    'nav_profile': {'hinglish': 'Profile', 'hi': 'प्रोफ़ाइल', 'en': 'Profile'},

    // Common actions
    'action_apply':      {'hinglish': 'Apply',         'hi': 'आवेदन करें',  'en': 'Apply'},
    'action_save':       {'hinglish': 'Save',          'hi': 'सेव करें',     'en': 'Save'},
    'action_share':      {'hinglish': 'Share',         'hi': 'शेयर',        'en': 'Share'},
    'action_compare':    {'hinglish': 'Compare',       'hi': 'तुलना',       'en': 'Compare'},
    'action_generate':   {'hinglish': 'Generate PDF',  'hi': 'PDF बनाएँ',    'en': 'Generate PDF'},

    // Profile section labels
    'profile_personal':  {'hinglish': 'Personal Info', 'hi': 'व्यक्तिगत जानकारी', 'en': 'Personal Info'},
    'profile_prefs':     {'hinglish': 'Job Preferences','hi': 'नौकरी प्राथमिकताएँ', 'en': 'Job Preferences'},
    'profile_form_fill': {'hinglish': 'Form Fill Details', 'hi': 'फ़ॉर्म भरने की जानकारी', 'en': 'Form Fill Details'},
    'profile_notifs':    {'hinglish': 'Notifications', 'hi': 'सूचनाएँ',     'en': 'Notifications'},
    'profile_language':  {'hinglish': 'Language',      'hi': 'भाषा',        'en': 'Language'},

    // Empty / loading states
    'empty_jobs':        {'hinglish': 'Koi job nahi mili',  'hi': 'कोई नौकरी नहीं मिली',   'en': 'No jobs found'},
    'empty_announcements':{'hinglish': 'Koi update abhi nahi','hi': 'अभी कोई अपडेट नहीं', 'en': 'No updates yet'},
    'loading':           {'hinglish': 'Load ho raha hai…',  'hi': 'लोड हो रहा है…',       'en': 'Loading…'},
  };
}
