import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────
// ZeroWire Design Tokens
// ──────────────────────────────────────────────

class ZWColors {
  // Neon accents
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonCyanLight = Color(0xFFDBFCFF);
  static const Color neonPurple = Color(0xFFECB2FF);
  static const Color neonGreen = Color(0xFF39FF14);

  // Dark mode surfaces
  static const Color darkBackground = Color(0xFF0A0A0C);
  static const Color darkSurface = Color(0xFF131318);
  static const Color darkSurfaceContainer = Color(0xFF1F1F25);
  static const Color darkSurfaceContainerHigh = Color(0xFF2A292F);
  static const Color darkSurfaceVariant = Color(0xFF35343A);
  static const Color darkOnSurface = Color(0xFFE4E1E9);
  static const Color darkOnSurfaceVariant = Color(0xFFB9CACB);
  static const Color darkOutlineVariant = Color(0xFF3B494B);
  static const Color darkOutline = Color(0xFF849495);

  // Light mode surfaces
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFF0F2F5);
  static const Color lightSurfaceContainerHigh = Color(0xFFE8EAED);
  static const Color lightSurfaceVariant = Color(0xFFE0E3E7);
  static const Color lightOnSurface = Color(0xFF1A1C1E);
  static const Color lightOnSurfaceVariant = Color(0xFF44474F);
  static const Color lightOutlineVariant = Color(0xFFC4C6D0);
  static const Color lightOutline = Color(0xFF74777F);

  // Shared
  static const Color error = Color(0xFFFFB4AB);
  static const Color primaryDark = Color(0xFF006970);
}

class ZWTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: ZWColors.darkBackground,
      colorScheme: ColorScheme.dark(
        primary: ZWColors.neonCyan,
        primaryContainer: ZWColors.neonCyan,
        secondary: ZWColors.neonPurple,
        secondaryContainer: const Color(0xFFCF5CFF),
        surface: ZWColors.darkSurface,
        surfaceContainerHighest: ZWColors.darkSurfaceVariant,
        onSurface: ZWColors.darkOnSurface,
        onSurfaceVariant: ZWColors.darkOnSurfaceVariant,
        outline: ZWColors.darkOutline,
        outlineVariant: ZWColors.darkOutlineVariant,
        error: ZWColors.error,
      ),
      textTheme: _buildTextTheme(ZWColors.darkOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: ZWColors.neonCyan,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: ZWColors.neonCyan),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: ZWColors.neonCyan.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: ZWColors.neonCyan,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: ZWColors.darkOutline,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: ZWColors.neonCyan, size: 24);
          }
          return const IconThemeData(color: ZWColors.darkOutline, size: 24);
        }),
      ),
      dividerColor: ZWColors.darkOutlineVariant.withValues(alpha: 0.2),
      iconTheme: const IconThemeData(color: ZWColors.darkOnSurfaceVariant),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: ZWColors.lightBackground,
      colorScheme: ColorScheme.light(
        primary: ZWColors.primaryDark,
        primaryContainer: const Color(0xFF00BCD4),
        secondary: const Color(0xFF9C27B0),
        secondaryContainer: const Color(0xFFEADDFF),
        surface: ZWColors.lightSurface,
        surfaceContainerHighest: ZWColors.lightSurfaceVariant,
        onSurface: ZWColors.lightOnSurface,
        onSurfaceVariant: ZWColors.lightOnSurfaceVariant,
        outline: ZWColors.lightOutline,
        outlineVariant: ZWColors.lightOutlineVariant,
        error: const Color(0xFFBA1A1A),
      ),
      textTheme: _buildTextTheme(ZWColors.lightOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: ZWColors.primaryDark,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: ZWColors.primaryDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: ZWColors.primaryDark.withValues(alpha: 0.08),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: ZWColors.primaryDark,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: ZWColors.lightOutline,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: ZWColors.primaryDark, size: 24);
          }
          return const IconThemeData(color: ZWColors.lightOutline, size: 24);
        }),
      ),
      dividerColor: ZWColors.lightOutlineVariant.withValues(alpha: 0.3),
      iconTheme: const IconThemeData(color: ZWColors.lightOnSurfaceVariant),
    );
  }

  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 57, fontWeight: FontWeight.w700, color: textColor,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 45, fontWeight: FontWeight.w700, color: textColor,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 36, fontWeight: FontWeight.w700, color: textColor,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28, fontWeight: FontWeight.w600, color: textColor, letterSpacing: -0.5,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 24, fontWeight: FontWeight.w600, color: textColor,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 22, fontWeight: FontWeight.w700, color: textColor,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 16, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.spaceGrotesk(
        fontSize: 14, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w400, color: textColor,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w400, color: textColor,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w400, color: textColor,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 10, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 1.5,
      ),
    );
  }
}
