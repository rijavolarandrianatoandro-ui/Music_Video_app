import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/maxei_theme.dart';

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 18,
    this.tint,
    this.padding,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: tint ?? canvas.withValues(alpha: 0.62),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              canvas.withValues(alpha: tint == null ? 0.44 : 0.12),
              (tint ?? aqua).withValues(alpha: tint == null ? 0.22 : 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: canvas.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 8),
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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [canvas, aqua.withValues(alpha: 0.36), canvas],
            stops: [0, 0.52, 1],
          ),
        ),
      ),
      const CustomPaint(painter: _RipplePainter()),
      child,
    ],
  );
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < 5; index++) {
      final y = size.height * (0.60 + index * 0.055);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * 0.22,
          y - 18,
          size.width * 0.32,
          y + 18,
          size.width * 0.55,
          y,
        )
        ..cubicTo(
          size.width * 0.77,
          y - 16,
          size.width * 0.86,
          y + 14,
          size.width,
          y - 2,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => false;
}
