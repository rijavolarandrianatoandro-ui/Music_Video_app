import 'package:flutter/material.dart';

const ink = Color(0xFFF5F0E8);
const canvas = Color(0xFF090C0D);
const aqua = Color(0xFFFF783F);
const surface = Color(0xFF171C1F);
const mutedInk = Color(0xFFABB1B3);
const maxeiSurfaceRadius = 28.0;
const maxeiControlRadius = 24.0;

ThemeData buildMaxeiTheme() {
  final colorScheme = ColorScheme.dark(
    primary: aqua,
    onPrimary: canvas,
    secondary: aqua,
    onSecondary: canvas,
    surface: surface,
    onSurface: ink,
    error: const Color(0xFFFF6B6B),
    onError: canvas,
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    colorScheme: colorScheme,
    canvasColor: surface,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(mutedInk),
        backgroundColor: WidgetStatePropertyAll(
          surface.withValues(alpha: 0.62),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: ink.withValues(alpha: 0.08)),
        ),
        shape: const WidgetStatePropertyAll(CircleBorder()),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(9)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
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
      backgroundColor: surface,
      selectedColor: aqua,
      labelStyle: const TextStyle(color: ink),
      side: BorderSide(color: ink.withValues(alpha: 0.12)),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: mutedInk.withValues(alpha: 0.8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(maxeiControlRadius),
        borderSide: BorderSide(color: ink.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(maxeiControlRadius),
        borderSide: BorderSide(color: ink.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(maxeiControlRadius),
        borderSide: const BorderSide(color: aqua, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: aqua.withValues(alpha: 0.16),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? aqua : mutedInk,
          size: selected ? 24 : 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? aqua : mutedInk,
          fontSize: 10,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(maxeiSurfaceRadius),
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(maxeiSurfaceRadius)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: const TextStyle(color: ink),
      behavior: SnackBarBehavior.floating,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(maxeiControlRadius)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: aqua,
      thumbColor: ink,
      inactiveTrackColor: ink.withValues(alpha: 0.18),
      overlayColor: aqua.withValues(alpha: 0.14),
    ),
    splashColor: aqua.withValues(alpha: 0.16),
    highlightColor: aqua.withValues(alpha: 0.07),
  );
}
