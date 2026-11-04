import 'package:flutter/services.dart';

import 'media_item.dart';

class DeviceMediaScanResult {
  const DeviceMediaScanResult({
    required this.audioPermissionGranted,
    required this.videoPermissionGranted,
    required this.items,
  });

  final bool audioPermissionGranted;
  final bool videoPermissionGranted;
  final List<MediaItem> items;
}

class DeviceMediaScanner {
  static const _channel = MethodChannel('app.maxei/device_media');

  Future<DeviceMediaScanResult> scan() async {
    final response = await _channel.invokeMapMethod<String, Object?>(
      'scanMedia',
    );
    if (response == null) {
      throw const FormatException('Réponse invalide du scanner média.');
    }

    final audioPermissionGranted = response['audioPermissionGranted'];
    final videoPermissionGranted = response['videoPermissionGranted'];
    if (audioPermissionGranted is! bool || videoPermissionGranted is! bool) {
      throw const FormatException('État des permissions média invalide.');
    }
    final rawItems = response['items'];
    if (rawItems is! List) {
      throw const FormatException('Liste média invalide.');
    }
    if (!audioPermissionGranted && !videoPermissionGranted) {
      return const DeviceMediaScanResult(
        audioPermissionGranted: false,
        videoPermissionGranted: false,
        items: [],
      );
    }

    final items = <MediaItem>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw const FormatException('Métadonnées média invalides.');
      }
      final item = Map<Object?, Object?>.from(rawItem);
      final uri = Uri.tryParse(item['uri'] as String? ?? '');
      final name = item['name'] as String?;
      final kind = item['kind'] as String?;
      if (uri == null ||
          uri.scheme != 'content' ||
          name == null ||
          (kind != 'audio' && kind != 'video')) {
        throw const FormatException('URI ou type média MediaStore invalide.');
      }
      items.add(
        MediaItem.stored(
          name: name,
          uri: uri,
          size: _intValue(item['size']),
          kind: kind == 'audio' ? MediaKind.audio : MediaKind.video,
          title: item['title'] as String?,
          artist: item['artist'] as String?,
          album: item['album'] as String? ?? '',
          durationMs: _intValue(item['durationMs']),
          addedAt: DateTime.fromMillisecondsSinceEpoch(
            _intValue(item['dateAdded']) * 1000,
          ),
        ),
      );
    }
    return DeviceMediaScanResult(
      audioPermissionGranted: audioPermissionGranted,
      videoPermissionGranted: videoPermissionGranted,
      items: items,
    );
  }

  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');

  int _intValue(Object? value) => value is num ? value.toInt() : 0;
}
