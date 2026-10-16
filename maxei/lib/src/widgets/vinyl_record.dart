import 'package:flutter/material.dart';

import '../theme/maxei_theme.dart';
import 'media_artwork.dart';

class VinylRecord extends StatefulWidget {
  const VinylRecord({
    super.key,
    required this.title,
    required this.isPlaying,
    this.size = 292,
  });

  final String title;
  final bool isPlaying;
  final double size;

  @override
  State<VinylRecord> createState() => _VinylRecordState();
}

class _VinylRecordState extends State<VinylRecord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant VinylRecord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _syncRotation();
  }

  void _syncRotation() {
    if (widget.isPlaying && !_reduceMotion) {
      _rotation.repeat();
    } else {
      _rotation.stop();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) => Transform.rotate(
        angle: _rotation.value * 6.283185307179586,
        child: child,
      ),
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ink,
            shape: BoxShape.circle,
            border: Border.all(color: aqua.withValues(alpha: 0.38), width: 1),
            boxShadow: [
              BoxShadow(
                color: ink.withValues(alpha: 0.24),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _VinylGroovesPainter(),
              ),
              Container(
                width: widget.size * 0.43,
                height: widget.size * 0.43,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: aqua.withValues(alpha: 0.54),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: MediaArtwork(
                  title: widget.title,
                  size: widget.size * 0.43,
                ),
              ),
              Container(
                width: widget.size * 0.035,
                height: widget.size * 0.035,
                decoration: const BoxDecoration(
                  color: ink,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = aqua.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    for (
      var radius = size.width * 0.25;
      radius < size.width * 0.49;
      radius += 5
    ) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) => false;
}
