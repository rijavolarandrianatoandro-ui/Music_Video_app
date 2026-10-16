import 'package:flutter/material.dart';

import '../theme/maxei_theme.dart';

class MediaArtwork extends StatelessWidget {
  const MediaArtwork({super.key, required this.title, this.size = 64});

  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final variant = title.hashCode.abs() % 3;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.14),
        child: ColoredBox(
          color: variant == 1 ? aqua : ink,
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
                    color: variant == 1 ? ink : canvas,
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
                      color: variant == 2 ? aqua : canvas,
                      borderRadius: BorderRadius.circular(size * 0.2),
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: size * 0.38,
                  color: variant == 1 ? aqua : ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
