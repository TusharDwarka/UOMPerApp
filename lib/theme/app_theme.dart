import 'package:flutter/material.dart';

/// Design tokens. The layout language follows `designIdeas/` (soft off-white
/// canvas, big rounded white cards, black pills, oversized light headings)
/// with the lime accent swapped for the app's existing blue.
class AppColors {
  // Brand (unchanged from the original palette)
  static const indigo = Color(0xFF1A237E);
  static const accent = Color(0xFF2962FF);
  static const accentDark = Color(0xFF5B7CFA);
  static const accentSoft = Color(0xFFE3EBFF);
  static const success = Color(0xFF00C853);
  static const danger = Color(0xFFFF3D00);

  // Surfaces
  static const canvasLight = Color(0xFFF5F5F7);
  static const surfaceLight = Colors.white;
  static const inkLight = Color(0xFF111318);
  static const canvasDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const inkDark = Color(0xFFF2F3F5);

  /// Event palette offered in the Academic Hub colour picker.
  static const eventPalette = <Color>[
    Color(0xFF2962FF), // blue
    Color(0xFF7C4DFF), // violet
    Color(0xFF00BFA5), // teal
    Color(0xFF00C853), // green
    Color(0xFFFFAB00), // amber
    Color(0xFFFF6D00), // orange
    Color(0xFFFF1744), // red
    Color(0xFFF50057), // pink
    Color(0xFF546E7A), // slate
  ];

  static Color forType(String type) {
    switch (type) {
      case 'Exam':
        return const Color(0xFFFF1744);
      case 'Test':
        return const Color(0xFFFF6D00);
      case 'Assignment':
        return const Color(0xFF2962FF);
      case 'Homework':
        return const Color(0xFF00BFA5);
      case 'Project':
        return const Color(0xFF7C4DFF);
      case 'Event':
        return const Color(0xFFF50057);
      case 'Note':
        return const Color(0xFF00C853);
      default:
        return const Color(0xFF546E7A);
    }
  }
}

/// Theme-aware accessors so widgets don't repeat `isDark ? ... : ...`.
class Palette {
  final bool isDark;
  const Palette(this.isDark);

  factory Palette.of(BuildContext context) => Palette(Theme.of(context).brightness == Brightness.dark);

  Color get canvas => isDark ? AppColors.canvasDark : AppColors.canvasLight;
  Color get surface => isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get surfaceAlt => isDark ? const Color(0xFF262626) : const Color(0xFFF0F1F4);
  Color get ink => isDark ? AppColors.inkDark : AppColors.inkLight;
  Color get onInk => isDark ? Colors.black : Colors.white;
  Color get accent => isDark ? AppColors.accentDark : AppColors.accent;
  Color get accentSoft => isDark ? AppColors.accentDark.withValues(alpha: 0.18) : AppColors.accentSoft;
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1D1E);
  Color get textSecondary => isDark ? const Color(0xFFA3A6AD) : const Color(0xFF6B6F76);
  Color get textMuted => isDark ? const Color(0xFF6E7179) : const Color(0xFFA6A9B0);
  Color get border => isDark ? Colors.white10 : const Color(0xFFE9EAEE);
  List<BoxShadow> get softShadow => isDark
      ? const []
      : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 10))];
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.indigo,
      scaffoldBackgroundColor: AppColors.canvasLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        secondary: AppColors.success,
        error: AppColors.danger,
        surface: AppColors.surfaceLight,
        brightness: Brightness.light,
      ),
      cardColor: Colors.white,
    );
    return _shared(base, const Palette(false));
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF3949AB),
      scaffoldBackgroundColor: AppColors.canvasDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentDark,
        secondary: Color(0xFF00E676),
        error: Color(0xFFFF5252),
        surface: AppColors.surfaceDark,
      ),
      cardColor: AppColors.surfaceDark,
    );
    return _shared(base, const Palette(true));
  }

  static ThemeData _shared(ThemeData base, Palette p) {
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: p.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(color: p.onInk, fontWeight: FontWeight.w600),
        actionTextColor: p.isDark ? AppColors.accent : const Color(0xFF8FB0FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.ink,
        foregroundColor: p.onInk,
        shape: const StadiumBorder(),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : null),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: p.border, space: 1),
      // Calendar pickers: black selected day, blue "today", rounded sheet.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.canvas,
        headerForegroundColor: p.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : null),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return p.onInk;
          if (s.contains(WidgetState.disabled)) return p.textMuted;
          return p.textPrimary;
        }),
        todayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : null),
        todayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onInk : p.accent),
        todayBorder: BorderSide(color: p.accent, width: 1.5),
        yearBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : null),
        yearForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onInk : p.textPrimary),
        rangeSelectionBackgroundColor: p.accentSoft,
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: p.textPrimary, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.textSecondary),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        dialBackgroundColor: p.surfaceAlt,
        dialHandColor: p.ink,
        hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // Menus: rounded, soft, never the old square boxes.
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w500),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : p.surfaceAlt),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onInk : p.textPrimary),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : null),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: p.ink, foregroundColor: p.onInk, shape: const StadiumBorder()),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.textPrimary, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      sliderTheme: SliderThemeData(activeTrackColor: p.accent, thumbColor: p.ink, inactiveTrackColor: p.surfaceAlt),
    );
  }
}
