import 'package:flutter/services.dart';

import 'media_item.dart';

class DeviceAudioScanResult {
  const DeviceAudioScanResult({
    required this.permissionGranted,
    required this.items,
  });

  final bool permissionGranted;
  final List<MediaItem> items;
}

class DeviceAudioScanner {
  static const _channel = MethodChannel('app.maxei/device_media');

  Future<DeviceAudioScanResult> scan() async {
    final response = await _channel.invokeMapMethod<String, Object?>(
      'scanAudio',
    );
    if (response == null) {
      throw const FormatException('Réponse invalide du scanner audio.');
    }

    final permissionGranted = response['permissionGranted'];
    if (permissionGranted is! bool) {
      throw const FormatException('État de permission audio invalide.');
    }
    final rawItems = response['items'];
    if (rawItems is! List) {
      throw const FormatException('Liste audio invalide.');
    }
    if (!permissionGranted) {
      return const DeviceAudioScanResult(permissionGranted: false, items: []);
    }

    final items = <MediaItem>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw const FormatException('Métadonnées audio invalides.');
      }
      final item = Map<Object?, Object?>.from(rawItem);
      final uri = Uri.tryParse(item['uri'] as String? ?? '');
      final name = item['name'] as String?;
      if (uri == null || uri.scheme != 'content' || name == null) {
        throw const FormatException('URI audio MediaStore invalide.');
      }
      items.add(
        MediaItem.deviceAudio(
          name: name,
          uri: uri,
          size: _intValue(item['size']),
          title: item['title'] as String? ?? '',
          artist: item['artist'] as String? ?? '',
          album: item['album'] as String? ?? '',
          durationMs: _intValue(item['durationMs']),
        ),
      );
    }
    return DeviceAudioScanResult(permissionGranted: true, items: items);
  }

  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');

  int _intValue(Object? value) => value is num ? value.toInt() : 0;
}
