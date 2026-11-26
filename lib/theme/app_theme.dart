import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Windows / macOS / Linux builds. Everything desktop-only (sidebar shell,
/// warmer neutrals, tighter radii, serif headings) is gated on this, so the
/// Android and iOS apps, and `flutter test` (which runs as Android), keep the
/// phone design exactly as it was.
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Editorial serif for desktop headings (Georgia ships with Windows and macOS).
const desktopSerif = TextStyle(fontFamily: 'Georgia', fontFamilyFallback: ['Cambria', 'Times New Roman', 'serif']);

/// Corners of a modal sheet: a top-rounded slab on phones, a centred
/// dialog card (all corners, tighter) on desktop.
BorderRadius get sheetRadius =>
    isDesktopPlatform ? BorderRadius.circular(14) : const BorderRadius.vertical(top: Radius.circular(32));

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

  /// Finished tasks/events turn this green on calendars and the board.
  static const done = Color(0xFF00B84A);
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

  /// Desktop uses warm, paper-like neutrals with hairline rings instead of
  /// the phone's cool grey canvas and floating shadows.
  bool get _desk => isDesktopPlatform;

  Color get canvas => _desk
      ? (isDark ? const Color(0xFF1F1F1E) : const Color(0xFFFCFCFB))
      : (isDark ? AppColors.canvasDark : AppColors.canvasLight);
  Color get surface =>
      _desk ? (isDark ? const Color(0xFF262625) : Colors.white) : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
  Color get surfaceAlt => _desk
      ? (isDark ? const Color(0xFF2E2E2C) : const Color(0xFFF3F2EF))
      : (isDark ? const Color(0xFF262626) : const Color(0xFFF0F1F4));

  /// Desktop sidebar background and its selected / hovered rows.
  Color get sidebar => isDark ? const Color(0xFF191918) : const Color(0xFFF7F6F3);
  Color get sidebarSelected => isDark ? const Color(0xFF2C2C2A) : const Color(0xFFEBEAE6);
  Color get sidebarHover => isDark ? const Color(0xFF242423) : const Color(0xFFF0EFEB);

  Color get ink => isDark ? AppColors.inkDark : AppColors.inkLight;
  Color get onInk => isDark ? Colors.black : Colors.white;
  Color get accent => isDark ? AppColors.accentDark : AppColors.accent;
  Color get accentSoft => isDark ? AppColors.accentDark.withValues(alpha: 0.18) : AppColors.accentSoft;
  Color get textPrimary => _desk
      ? (isDark ? const Color(0xFFEDECE9) : const Color(0xFF1F1F1D))
      : (isDark ? Colors.white : const Color(0xFF1A1D1E));
  Color get textSecondary => _desk
      ? (isDark ? const Color(0xFFA19F9A) : const Color(0xFF6B6963))
      : (isDark ? const Color(0xFFA3A6AD) : const Color(0xFF6B6F76));
  Color get textMuted => _desk
      ? (isDark ? const Color(0xFF6F6D69) : const Color(0xFFA5A39D))
      : (isDark ? const Color(0xFF6E7179) : const Color(0xFFA6A9B0));
  Color get border => _desk
      ? (isDark ? const Color(0xFF33332F) : const Color(0xFFE9E8E4))
      : (isDark ? Colors.white10 : const Color(0xFFE9EAEE));

  /// Phone: soft floating shadow. Desktop: a 1px ring (drawn as a shadow so
  /// it never changes layout) plus a barely-there lift.
  List<BoxShadow> get softShadow {
    if (_desk) {
      return [
        BoxShadow(color: border, spreadRadius: 1),
        if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
      ];
    }
    return isDark
        ? const []
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 10))];
  }
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
    final t = _shared(base, const Palette(false));
    return isDesktopPlatform ? _desktop(t, const Palette(false)) : t;
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
    final t = _shared(base, const Palette(true));
    return isDesktopPlatform ? _desktop(t, const Palette(true)) : t;
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

  /// PC refinements layered on top of the shared theme: no ink ripples
  /// (hover states do that job with a mouse), tighter radii, compact
  /// snackbars and quick, quiet tooltips. Never used on Android/iOS.
  static ThemeData _desktop(ThemeData t, Palette p) {
    final r8 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final r10 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final r12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final r16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    OutlineInputBorder field([Color? c]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: c == null ? BorderSide.none : BorderSide(color: c));
    return t.copyWith(
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      cardColor: p.surface,
      splashFactory: NoSplash.splashFactory,
      hoverColor: p.textPrimary.withValues(alpha: 0.04),
      highlightColor: p.textPrimary.withValues(alpha: 0.06),
      colorScheme: t.colorScheme.copyWith(surface: p.surface),
      appBarTheme: t.appBarTheme.copyWith(
        backgroundColor: p.canvas,
        titleTextStyle: desktopSerif.copyWith(color: p.textPrimary, fontSize: 22, fontWeight: FontWeight.w400),
      ),
      dialogTheme: t.dialogTheme.copyWith(backgroundColor: p.surface, surfaceTintColor: Colors.transparent, shape: r16),
      bottomSheetTheme: t.bottomSheetTheme.copyWith(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      snackBarTheme: t.snackBarTheme.copyWith(width: 420, shape: r10, elevation: 4),
      inputDecorationTheme: t.inputDecorationTheme.copyWith(
        fillColor: p.surfaceAlt,
        border: field(),
        enabledBorder: field(),
        focusedBorder: field(p.textSecondary.withValues(alpha: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      popupMenuTheme: t.popupMenuTheme.copyWith(color: p.surface, elevation: 6, shape: r12, menuPadding: const EdgeInsets.all(4)),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(r12),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(p.surface), shape: WidgetStatePropertyAll(r12)),
      ),
      datePickerTheme: t.datePickerTheme.copyWith(shape: r16),
      timePickerTheme: t.timePickerTheme.copyWith(shape: r16),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        exitDuration: Duration.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        textStyle: TextStyle(color: p.onInk, fontSize: 12, fontWeight: FontWeight.w500),
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(6)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(6),
        thumbColor: WidgetStatePropertyAll(p.textMuted.withValues(alpha: 0.45)),
      ),
      dividerTheme: DividerThemeData(color: p.border, space: 1),
      // Buttons: compact rounded rectangles, not phone stadium pills.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.onInk,
          shape: r8,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          shape: r8,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.textPrimary,
          shape: r8,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: r8, iconSize: 20, minimumSize: const Size(34, 34), padding: const EdgeInsets.all(7)),
      ),
      floatingActionButtonTheme: t.floatingActionButtonTheme.copyWith(shape: r12, elevation: 1),
      chipTheme: t.chipTheme.copyWith(
        shape: r8,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(fontSize: 13, color: p.textPrimary, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.surface : p.surfaceAlt),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.textPrimary : p.textSecondary),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          shape: WidgetStatePropertyAll(r8),
          visualDensity: VisualDensity.compact,
        ),
      ),
      checkboxTheme: t.checkboxTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
      listTileTheme: ListTileThemeData(shape: r8, dense: true, horizontalTitleGap: 12),
      visualDensity: VisualDensity.compact,
    );
  }
}
