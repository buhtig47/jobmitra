// lib/utils/constants.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────
// API CONFIG — Change this to your Render URL
// ─────────────────────────────────────────
// const String kApiBase = "https://jobmitra-api.onrender.com";
// For local testing:
const String kApiBase = "https://jobmitra-api.onrender.com";  // Android emulator
// const String kApiBase = "http://localhost:8000";  // iOS simulator

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
