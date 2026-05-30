import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFFF6B35);
  static const primaryLight = Color(0xFFFF8C5A);
  static const primaryDark = Color(0xFFE5541E);
  static const secondary = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const danger = Color(0xFFF44336);
  static const background = Color(0xFFFAFAF8);
  static const surface = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFF5F5F0);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF666666);
  static const textHint = Color(0xFFAAAAAA);
  static const divider = Color(0xFFEEEEEE);
  static const streakGold = Color(0xFFFFB300);
}

/// 이모지 전용 TextStyle.
/// GoogleFonts(Noto Sans KR)가 전역 폰트로 설정되면 이모지 글리프가 없어
/// 엉뚱한 그림으로 렌더링될 수 있다. fontFamilyFallback에 OS 컬러 이모지
/// 폰트를 지정하면 Primary 폰트에 글리프가 없을 때 컬러 이모지로 fallback된다.
TextStyle emojiStyle(double fontSize) => TextStyle(
      fontSize: fontSize,
      fontFamilyFallback: const [
        'Apple Color Emoji',   // macOS / iOS
        'Segoe UI Emoji',      // Windows
        'Noto Color Emoji',    // Android / Linux
        'Noto Emoji',          // 최후 fallback
      ],
    );

class AppTheme {
  static ThemeData get light {
    final base = GoogleFonts.notoSansKrTextTheme();
    return ThemeData(
        useMaterial3: true,
        textTheme: base,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.divider),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.cardBg,
          selectedColor: AppColors.primary.withOpacity(0.15),
          labelStyle: const TextStyle(fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: AppColors.textHint),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
  }
}
