import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/maxei_theme.dart';

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 24,
    this.tint,
    this.padding,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: tint ?? surface.withValues(alpha: 0.84),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ink.withValues(alpha: tint == null ? 0.08 : 0.04),
              (tint ?? surface).withValues(alpha: tint == null ? 0.82 : 0.88),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: ink.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class LiquidBackdrop extends StatelessWidget {
  const LiquidBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF171717), const Color(0xFF0D0D0D), canvas]
                  : [const Color(0xFFFFFFFF), const Color(0xFFF8F8F8), canvas],
              stops: const [0, 0.48, 1],
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -90,
          child: _AmbientGlow(
            color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
            size: 360,
          ),
        ),
        Positioned(
          bottom: 70,
          left: -150,
          child: _AmbientGlow(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0x10000000),
            size: 340,
          ),
        ),
        CustomPaint(painter: _AtmospherePainter(isDark: isDark)),
        child,
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final radius = size.width * (0.38 + index * 0.11);
      canvas.drawCircle(
        Offset(size.width * 0.92, size.height * 0.12),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}
