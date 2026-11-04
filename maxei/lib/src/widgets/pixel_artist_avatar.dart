import 'package:flutter/material.dart';

class PixelArtistAvatar extends StatelessWidget {
  const PixelArtistAvatar({super.key, required this.artistId, this.size = 56});

  final String artistId;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(size * 0.28),
    child: CustomPaint(
      size: Size.square(size),
      painter: _PixelArtistPainter(artistId),
    ),
  );
}

class _PixelArtistPainter extends CustomPainter {
  _PixelArtistPainter(this.seed);

  final String seed;

  static const _backgrounds = [
    Color(0xFF203746),
    Color(0xFF3A2851),
    Color(0xFF57342C),
    Color(0xFF244438),
    Color(0xFF48314A),
    Color(0xFF45502A),
  ];
  static const _accents = [
    Color(0xFFFF9A62),
    Color(0xFF71D9CF),
    Color(0xFFFFC857),
    Color(0xFFB6A0FF),
    Color(0xFFFF779A),
    Color(0xFF9CD96D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final hash = seed.hashCode.abs();
    final background = _backgrounds[hash % _backgrounds.length];
    final accent = _accents[(hash ~/ 7) % _accents.length];
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
            ? (y < 6 ? accent : const Color(0xFFF1C7A5))
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

    pixelPaint.color = const Color(0xFF141719);
    final eyeY = 6 * cell;
    canvas.drawRect(Rect.fromLTWH(4 * cell, eyeY, cell, cell), pixelPaint);
    canvas.drawRect(Rect.fromLTWH(6 * cell, eyeY, cell, cell), pixelPaint);
    pixelPaint.color = const Color(0xFFDA8D7D);
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
      oldDelegate.seed != seed;
}
