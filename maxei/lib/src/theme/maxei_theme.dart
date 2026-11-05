import 'package:flutter/material.dart';

import '../media/app_settings.dart';

class MaxeiPalette {
  static AppThemeMode _mode = AppThemeMode.dark;

  static void setMode(AppThemeMode mode) {
    _mode = mode;
  }

  static bool get isDark => _mode == AppThemeMode.dark;
  static Color get ink => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF151515);
  static Color get canvas => isDark ? const Color(0xFF080808) : const Color(0xFFF4F4F4);
  static Color get aqua => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF111111);
  static Color get surface => isDark ? const Color(0xFF191919) : const Color(0xFFFFFFFF);
  static Color get mutedInk => isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
}

Color get ink => MaxeiPalette.ink;
Color get canvas => MaxeiPalette.canvas;
Color get aqua => MaxeiPalette.aqua;
Color get surface => MaxeiPalette.surface;
Color get mutedInk => MaxeiPalette.mutedInk;

const maxeiSurfaceRadius = 28.0;
const maxeiControlRadius = 24.0;

ThemeData buildMaxeiTheme({required bool isDark}) {
  final themeInk = isDark
      ? const Color(0xFFF2F2F2)
      : const Color(0xFF151515);
  final themeCanvas = isDark
      ? const Color(0xFF080808)
      : const Color(0xFFF4F4F4);
  final themeAccent = isDark
      ? const Color(0xFFF2F2F2)
      : const Color(0xFF111111);
  final themeSurface = isDark
      ? const Color(0xFF191919)
      : const Color(0xFFFFFFFF);
  final themeMuted = isDark
      ? const Color(0xFFAAAAAA)
      : const Color(0xFF666666);
  final colorScheme = ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: themeAccent,
    onPrimary: isDark ? themeCanvas : const Color(0xFFFFFFFF),
    secondary: themeAccent,
    onSecondary: isDark ? themeCanvas : const Color(0xFFFFFFFF),
    surface: themeSurface,
    onSurface: themeInk,
    error: const Color(0xFF777777),
    onError: isDark ? themeCanvas : const Color(0xFFFFFFFF),
    surfaceContainerHighest: isDark
        ? const Color(0xFF242424)
        : const Color(0xFFE8E8E8),
  );

  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: themeCanvas,
    colorScheme: colorScheme,
    canvasColor: themeSurface,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: themeInk,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(themeMuted),
        backgroundColor: WidgetStatePropertyAll(
          themeSurface.withValues(alpha: 0.62),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: themeInk.withValues(alpha: 0.08)),
        ),
        shape: const WidgetStatePropertyAll(CircleBorder()),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(9)),
      ),
    ),
    cardTheme: CardThemeData(
      color: themeSurface,
      elevation: 0,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(maxeiSurfaceRadius)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: themeSurface,
      selectedColor: themeAccent,
      labelStyle: TextStyle(color: themeInk),
      side: BorderSide(color: themeInk.withValues(alpha: 0.12)),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: themeSurface,
      hintStyle: TextStyle(color: themeMuted.withValues(alpha: 0.8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(maxeiControlRadius),
        borderSide: BorderSide(color: themeInk.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(maxeiControlRadius),
        borderSide: BorderSide(color: themeInk.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(maxeiControlRadius),
        borderSide: BorderSide(color: themeAccent, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: themeAccent.withValues(alpha: 0.16),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? themeAccent : themeMuted,
          size: selected ? 24 : 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? themeAccent : themeMuted,
          fontSize: 10,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: themeSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(maxeiSurfaceRadius),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: themeSurface,
      surfaceTintColor: Colors.transparent,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(maxeiSurfaceRadius)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: themeSurface,
      contentTextStyle: TextStyle(color: themeInk),
      behavior: SnackBarBehavior.floating,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(maxeiControlRadius)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: themeAccent,
      thumbColor: themeInk,
      inactiveTrackColor: themeInk.withValues(alpha: 0.18),
      overlayColor: themeAccent.withValues(alpha: 0.14),
    ),
    splashColor: themeAccent.withValues(alpha: 0.16),
    highlightColor: themeAccent.withValues(alpha: 0.07),
  );
}
