import 'package:flutter/material.dart';

/// Dark-Mastermind Farb- und Theme-Definitionen.
/// Prinzip: fast-schwarze Buehne, EINE kuehle Akzentfarbe (Aura), viel Leere.
class AppColors {
  static const Color bg = Color(0xFF0A0A0F); // near-black Buehne
  static const Color surface = Color(0xFF13131A); // Karten
  static const Color surfaceAlt = Color(0xFF1A1A24); // Felder / Tracks
  static const Color border = Color(0xFF23232F);
  static const Color borderAura = Color(0xFF2F2A4A);

  static const Color aura = Color(0xFF7F77DD); // Violett-Akzent
  static const Color auraSoft = Color(0xFFAFA9EC);
  static const Color auraDeep = Color(0xFF534AB7);
  static const Color auraBlue = Color(0xFF378ADD);
  static const Color streak = Color(0xFF5DCAA5); // kuehles Cyan fuer Streak

  static const Color textPrimary = Color(0xFFE8E8F0);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color textTertiary = Color(0xFF5A5A6A);

  static const Color danger = Color(0xFFE24B4A);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.surface,
        primary: AppColors.aura,
        secondary: AppColors.streak,
        error: AppColors.danger,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: AppColors.border,
    );
  }

  // Wiederverwendbare Textstile mit "Mastermind"-Anmutung (Letter-Spacing).
  static const TextStyle label = TextStyle(
    fontSize: 11,
    color: AppColors.textTertiary,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle heroNumber = TextStyle(
    fontSize: 22,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );
}
