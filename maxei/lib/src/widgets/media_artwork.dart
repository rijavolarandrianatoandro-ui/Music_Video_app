import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/media_item.dart';

class MediaArtwork extends StatelessWidget {
  const MediaArtwork({
    super.key,
    required this.title,
    this.item,
    this.size = 64,
  });

  final String title;
  final MediaItem? item;
  final double size;

  static const _artworkChannel = MethodChannel('app.maxei/media_artwork');
  static final Map<String, Future<Uint8List?>> _artworkCache = {};

  static Future<Uint8List?> _loadArtwork(MediaItem item) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    try {
      return await _artworkChannel.invokeMethod<Uint8List>('getArtwork', {
        'uri': item.uri.toString(),
        'kind': item.kind.name,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<Uint8List?> _artwork() =>
      _artworkCache.putIfAbsent(item!.id, () => _loadArtwork(item!));

  @override
  Widget build(BuildContext context) {
    final variant = title.hashCode.abs() % 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palettes = isDark
        ? const [
            (Color(0xFF454545), Color(0xFF171717), Color(0xFFF0F0F0)),
            (Color(0xFF5C5C5C), Color(0xFF252525), Color(0xFFFFFFFF)),
            (Color(0xFF777777), Color(0xFF303030), Color(0xFFE4E4E4)),
          ]
        : const [
            (Color(0xFFDADADA), Color(0xFFB8B8B8), Color(0xFF222222)),
            (Color(0xFFC8C8C8), Color(0xFFA0A0A0), Color(0xFF111111)),
            (Color(0xFFE6E6E6), Color(0xFFBDBDBD), Color(0xFF333333)),
          ];
    final (primary, secondary, detail) = palettes[variant];
    final fallback = SizedBox.square(
      dimension: size,
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(size * 0.27),
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
                child: Text(
                  title.trim().isEmpty
                      ? '?'
                      : String.fromCharCode(title.trim().runes.first)
                            .toUpperCase(),
                  style: TextStyle(
                    color: detail,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final currentItem = item;
    if (currentItem == null) return fallback;

    return FutureBuilder<Uint8List?>(
      future: _artwork(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return fallback;
        return SizedBox.square(
          dimension: size,
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(size * 0.27),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
