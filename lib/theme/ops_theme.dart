import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brutal industrial + orange tokens from Figma (TTLock Ops).
abstract final class OpsColors {
  static const background = Color(0xFFE8E6E1);
  static const ink = Color(0xFF121212);
  static const muted = Color(0xFF6B6860);
  static const line = Color(0xFFB8B4AC);
  static const field = Color(0xFFF2F2F2);
  static const orange = Color(0xFFFF5A00);
  static const orangeDeep = Color(0xFFC84400);
  static const orangeWash = Color(0x1AFF5A00);
  static const warn = Color(0xFFF5A623);
  static const danger = Color(0xFFE10600);
  static const success = Color(0xFF3D7C2E);
  static const darkPanel = Color(0xFF1E1E1E);
  static const switchTrackOff = Color(0xFFD4D1CA);
  static const steel = Color(0xFF2A2A2A);
}

ThemeData buildOpsTheme() {
  final base = GoogleFonts.ibmPlexSansTextTheme();
  final text = base.apply(
    bodyColor: OpsColors.ink,
    displayColor: OpsColors.ink,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(2),
    borderSide: const BorderSide(color: OpsColors.line, width: 1),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: OpsColors.background,
    colorScheme: const ColorScheme.light(
      primary: OpsColors.orange,
      onPrimary: OpsColors.ink,
      secondary: OpsColors.ink,
      onSecondary: OpsColors.field,
      surface: OpsColors.background,
      onSurface: OpsColors.ink,
      error: OpsColors.danger,
      onError: OpsColors.field,
      outline: OpsColors.line,
    ),
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: OpsColors.background,
      foregroundColor: OpsColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: OpsColors.ink,
        height: 1.25,
      ),
      shape: const Border(
        bottom: BorderSide(color: OpsColors.ink, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OpsColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: OpsColors.ink, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: OpsColors.danger, width: 1),
      ),
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: OpsColors.muted,
      ),
      hintStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        color: OpsColors.muted,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return OpsColors.field;
        return OpsColors.ink;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return OpsColors.orange;
        return OpsColors.switchTrackOff;
      }),
      trackOutlineColor: WidgetStateProperty.all(OpsColors.ink),
      trackOutlineWidth: WidgetStateProperty.all(1),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: OpsColors.ink,
      unselectedLabelColor: OpsColors.muted,
      indicatorColor: OpsColors.orange,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      dividerColor: OpsColors.ink,
      dividerHeight: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: OpsColors.darkPanel,
      contentTextStyle: GoogleFonts.ibmPlexSans(
        color: OpsColors.field,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: OpsColors.ink, width: 2),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
      color: OpsColors.ink,
      thickness: 1,
      space: 32,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: OpsColors.orange,
      linearTrackColor: OpsColors.line,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: OpsColors.background,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: OpsColors.ink, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: OpsColors.ink,
      ),
    ),
    cardTheme: const CardThemeData(
      color: OpsColors.field,
      elevation: 0,
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: OpsColors.ink, width: 1),
        borderRadius: BorderRadius.zero,
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: OpsColors.ink,
      ),
      subtitleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: OpsColors.muted,
        height: 1.3,
      ),
      iconColor: OpsColors.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OpsColors.orange,
        foregroundColor: OpsColors.ink,
        disabledBackgroundColor: OpsColors.line,
        disabledForegroundColor: OpsColors.muted,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: OpsColors.ink, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: OpsColors.ink,
        side: const BorderSide(color: OpsColors.ink, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size.fromHeight(44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: OpsColors.orangeDeep,
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    ),
  );
}
