import 'package:flutter/material.dart';

import '../theme/maxei_theme.dart';

class PixelArtistAvatar extends StatelessWidget {
  const PixelArtistAvatar({super.key, required this.artistId, this.size = 56});

  final String artistId;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(size * 0.28),
    child: CustomPaint(
      size: Size.square(size),
      painter: _PixelArtistPainter(artistId, isDark: MaxeiPalette.isDark),
    ),
  );
}

class _PixelArtistPainter extends CustomPainter {
  _PixelArtistPainter(this.seed, {required this.isDark});

  final String seed;
  final bool isDark;

  static const _darkBackgrounds = [
    Color(0xFF202020),
    Color(0xFF303030),
    Color(0xFF424242),
    Color(0xFF252525),
    Color(0xFF383838),
    Color(0xFF4A4A4A),
  ];
  static const _lightBackgrounds = [
    Color(0xFFDADADA),
    Color(0xFFC8C8C8),
    Color(0xFFB8B8B8),
    Color(0xFFE0E0E0),
    Color(0xFFCCCCCC),
    Color(0xFFB0B0B0),
  ];
  static const _darkAccents = [
    Color(0xFFE0E0E0),
    Color(0xFFBDBDBD),
    Color(0xFFF5F5F5),
    Color(0xFF9E9E9E),
    Color(0xFFD0D0D0),
    Color(0xFFAAAAAA),
  ];
  static const _lightAccents = [
    Color(0xFF222222),
    Color(0xFF444444),
    Color(0xFF111111),
    Color(0xFF666666),
    Color(0xFF333333),
    Color(0xFF555555),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final hash = seed.hashCode.abs();
    final backgrounds = isDark ? _darkBackgrounds : _lightBackgrounds;
    final accents = isDark ? _darkAccents : _lightAccents;
    final background = backgrounds[hash % backgrounds.length];
    final accent = accents[(hash ~/ 7) % accents.length];
    const cells = 11;
    final cell = size.width / cells;
    final backgroundPaint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final pixelPaint = Paint()..isAntiAlias = false;
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < (cells + 1) ~/ 2; x++) {
        final value = _cell(seed, x, y);
        final insidePortrait = y >= 2 && y <= 9 && x >= 2 && x <= 4;
        if (!insidePortrait && value % 5 != 0) continue;
        pixelPaint.color = insidePortrait
            ? (y < 6 ? accent : const Color(0xFFE0E0E0))
            : accent.withValues(alpha: 0.22 + (value % 4) * 0.12);
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        canvas.drawRect(rect, pixelPaint);
        final mirrorX = (cells - 1 - x) * cell;
        if (mirrorX != x * cell) {
          canvas.drawRect(
            Rect.fromLTWH(mirrorX, y * cell, cell, cell),
            pixelPaint,
          );
        }
      }
    }

    pixelPaint.color = const Color(0xFF101010);
    final eyeY = 6 * cell;
    canvas.drawRect(Rect.fromLTWH(4 * cell, eyeY, cell, cell), pixelPaint);
    canvas.drawRect(Rect.fromLTWH(6 * cell, eyeY, cell, cell), pixelPaint);
    pixelPaint.color = const Color(0xFF888888);
    canvas.drawRect(Rect.fromLTWH(5 * cell, 7 * cell, cell, cell), pixelPaint);
    pixelPaint.color = accent.withValues(alpha: 0.88);
    canvas.drawRect(
      Rect.fromLTWH(3 * cell, 9 * cell, 5 * cell, cell * 2),
      pixelPaint,
    );
  }

  int _cell(String value, int x, int y) =>
      (value.hashCode ^ (x * 73856093) ^ (y * 19349663)).abs();

  @override
  bool shouldRepaint(covariant _PixelArtistPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.isDark != isDark;
}
