import 'package:flutter/material.dart';

class MediaArtwork extends StatelessWidget {
  const MediaArtwork({super.key, required this.title, this.size = 64});

  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final variant = title.hashCode.abs() % 3;
    final palettes = [
      (const Color(0xFFFF7442), const Color(0xFF792A37), const Color(0xFFFFC18C)),
      (const Color(0xFF5272B8), const Color(0xFF253456), const Color(0xFFB4C8FF)),
      (const Color(0xFFB84B68), const Color(0xFF5E2D49), const Color(0xFFFFB2C7)),
    ];
    final (primary, secondary, detail) = palettes[variant];
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primary, secondary],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -size * 0.2,
                top: -size * 0.22,
                child: Container(
                  width: size * 0.82,
                  height: size * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: detail.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Positioned(
                left: -size * 0.14,
                bottom: -size * 0.28,
                child: Transform.rotate(
                  angle: variant * 0.4,
                  child: Container(
                    width: size * 0.68,
                    height: size * 0.68,
                    decoration: BoxDecoration(
                      color: detail.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(size * 0.28),
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  variant == 0 ? Icons.music_note_rounded : Icons.graphic_eq_rounded,
                  size: size * 0.4,
                  color: detail,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
