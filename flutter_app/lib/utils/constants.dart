// lib/utils/constants.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────
// API CONFIG — Google Cloud Run (asia-south1, Mumbai)
// ─────────────────────────────────────────
const String kApiBase = "https://jobmitra-api-830207301447.asia-south1.run.app";
// const String kApiBase = "https://jobmitra-api.onrender.com";  // legacy Render
// const String kApiBase = "http://localhost:8000";  // iOS simulator

// Play Store install link — appended to every outbound share so a share
// in a WhatsApp group doubles as an install funnel.
const String kPlayStoreUrl =
    "https://play.google.com/store/apps/details?id=com.jobmitra.app";

// ─────────────────────────────────────────
// SPACING TOKENS — 4-pt scale. Use these instead of bare numbers in new code;
// existing screens can migrate gradually. Keeps vertical rhythm consistent
// when we later tweak density (e.g. for tablets).
// ─────────────────────────────────────────
class Spacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}

// ─────────────────────────────────────────
// RADIUS TOKENS — three sizes cover the whole app: chip / card / sheet.
// ─────────────────────────────────────────
class Radii {
  static const double chip  = 20;
  static const double card  = 16;
  static const double cardLg = 20;
  static const double sheet = 24;
}

// ─────────────────────────────────────────
// TYPE SCALE — six steps. Pull these via AppText so a future redesign or
// dark-mode pass can override in one place. Sizes match Material's intent
// but use Poppins (set globally by appTheme()).
// ─────────────────────────────────────────
class AppText {
  static TextStyle display  ({Color? c}) => GoogleFonts.poppins(
        fontSize: 26, fontWeight: FontWeight.w800, height: 1.15,
        color: c ?? AppColors.textPrimary, letterSpacing: -0.4);
  static TextStyle h1       ({Color? c}) => GoogleFonts.poppins(
        fontSize: 20, fontWeight: FontWeight.w700, height: 1.25,
        color: c ?? AppColors.textPrimary, letterSpacing: -0.2);
  static TextStyle h2       ({Color? c}) => GoogleFonts.poppins(
        fontSize: 17, fontWeight: FontWeight.w700, height: 1.3,
        color: c ?? AppColors.textPrimary, letterSpacing: -0.15);
  static TextStyle body     ({Color? c}) => GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w500, height: 1.45,
        color: c ?? AppColors.textPrimary);
  static TextStyle caption  ({Color? c}) => GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w500, height: 1.4,
        color: c ?? AppColors.textSecondary);
  static TextStyle micro    ({Color? c}) => GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w600, height: 1.3,
        color: c ?? AppColors.textHint, letterSpacing: 0.2);
}

// ─────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────
class AppColors {
  static const primary       = Color(0xFF1A6B3C);  // Deep Green — India flag
  static const primaryLight  = Color(0xFF2E9959);
  static const accent        = Color(0xFFFF9933);  // Saffron — India flag
  static const background    = Color(0xFFF5F7F5);
  static const cardBg        = Color(0xFFFFFFFF);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF666666);
  static const textHint      = Color(0xFF999999);
  static const divider       = Color(0xFFEEEEEE);
  static const success       = Color(0xFF2E9959);
  static const warning       = Color(0xFFFFB020);
  static const danger        = Color(0xFFE53935);
  static const urgencyGreen  = Color(0xFF4CAF50);
  static const urgencyYellow = Color(0xFFFFC107);
  static const urgencyRed    = Color(0xFFE53935);
}

// ─────────────────────────────────────────
// THEME
// ─────────────────────────────────────────
ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary:   AppColors.primary,
      secondary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.background,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    // Android 12+ sparkle ripple — noticeably more premium than the flat
    // grey splash, zero layout risk.
    splashFactory: InkSparkle.splashFactory,
    // M3 fade-forwards route transition — subtle horizontal fade instead of
    // the dated zoom. Applies to every Navigator.push in the app at once.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16, color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14, color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12, color: AppColors.textHint,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
      ),
      // Every app bar in the app is dark green — force light status bar
      // icons so the clock/battery never disappear into the gradient.
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textHint),
    ),
    // ── App-wide component consistency. Screens that hand-roll their own
    // styles keep working; everything else inherits these. ──
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2B2B2B),
      contentTextStyle: GoogleFonts.poppins(
          fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white),
      actionTextColor: AppColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
      contentTextStyle: GoogleFonts.poppins(
          fontSize: 14, height: 1.45, color: AppColors.textSecondary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      labelStyle: GoogleFonts.poppins(
          fontSize: 12.5, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: AppColors.accent,
      labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.primary : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.primary),
    dividerTheme: const DividerThemeData(
        color: AppColors.divider, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.primary),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}

// ─────────────────────────────────────────
// CATEGORIES DATA
// ─────────────────────────────────────────
class JobCategories {
  static const List<Map<String, dynamic>> all = [
    {"key": "railway",  "label": "Railway",   "icon": "🚂", "color": Color(0xFF1565C0)},
    {"key": "banking",  "label": "Banking",   "icon": "🏦", "color": Color(0xFF2E7D32)},
    {"key": "ssc",      "label": "SSC",       "icon": "📋", "color": Color(0xFF6A1B9A)},
    {"key": "teaching", "label": "Teaching",  "icon": "📚", "color": Color(0xFFE65100)},
    {"key": "police",   "label": "Police",    "icon": "👮", "color": Color(0xFF1A237E)},
    {"key": "defence",  "label": "Defence",   "icon": "⭐", "color": Color(0xFF37474F)},
    {"key": "upsc",     "label": "UPSC/IAS",  "icon": "🏛️", "color": Color(0xFFB71C1C)},
    {"key": "anganwadi","label": "Anganwadi", "icon": "🌸", "color": Color(0xFFAD1457)},
    {"key": "psu",      "label": "PSU",       "icon": "🏭", "color": Color(0xFF00695C)},
    {"key": "others",   "label": "Others",    "icon": "💼", "color": Color(0xFF5D4037)},
  ];
}

// Single source of truth for category accent colors used by job cards, job
// detail screen, and anywhere else a job key needs a tint. Includes finer-
// grained scraper categories (medical, research, postal, etc.) that aren't
// in the top-level JobCategories list.
class JobCategoryColors {
  static const Map<String, Color> _map = {
    'railway':     Color(0xFF1565C0),
    'banking':     Color(0xFF2E7D32),
    'ssc':         Color(0xFF6A1B9A),
    'teaching':    Color(0xFF00838F),
    'police':      Color(0xFF283593),
    'defence':     Color(0xFF558B2F),
    'upsc':        Color(0xFF4E342E),
    'anganwadi':   Color(0xFFAD1457),
    'psu':         Color(0xFF00695C),
    'medical':     Color(0xFFC62828),
    'research':    Color(0xFF4527A0),
    'engineering': Color(0xFF1565C0),
    'legal':       Color(0xFF37474F),
    'postal':      Color(0xFF6D4C41),
    'admin':       Color(0xFF546E7A),
    'it_tech':     Color(0xFF0277BD),
    'accounts':    Color(0xFF558B2F),
    'forest':      Color(0xFF2E7D32),
  };

  static const Color fallback = Color(0xFF546E7A);

  static Color colorFor(String? key) => _map[key] ?? fallback;
}

class IndianStates {
  static const List<String> all = [
    "All India", "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar",
    "Chhattisgarh", "Delhi", "Goa", "Gujarat", "Haryana", "Himachal Pradesh",
    "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra",
    "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab",
    "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura",
    "Uttar Pradesh", "Uttarakhand", "West Bengal",
  ];
}

class EducationLevels {
  static const List<Map<String, String>> all = [
    {"key": "8th",          "label": "8th Pass"},
    {"key": "10th",         "label": "10th Pass"},
    {"key": "12th",         "label": "12th Pass"},
    {"key": "diploma",      "label": "Diploma / ITI"},
    {"key": "graduate",     "label": "Graduate (BA/BSc/BCom/BTech)"},
    {"key": "postgraduate", "label": "Post Graduate (MA/MSc/MBA)"},
  ];
}
