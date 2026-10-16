import 'package:flutter/material.dart';

const ink = Color(0xFF123B43);
const canvas = Color(0xFFEDF8F6);
const aqua = Color(0xFFA3E5D7);

ThemeData buildMaxeiTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: canvas,
  colorScheme: const ColorScheme.light(
    primary: ink,
    onPrimary: canvas,
    secondary: aqua,
    tertiary: aqua,
    surface: canvas,
    onSurface: ink,
  ),
  fontFamily: 'Roboto',
  appBarTheme: AppBarTheme(
    backgroundColor: canvas.withValues(alpha: 0.62),
    foregroundColor: ink,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    height: 68,
    elevation: 0,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  ),
  splashColor: aqua.withValues(alpha: 0.18),
  highlightColor: aqua.withValues(alpha: 0.08),
);
