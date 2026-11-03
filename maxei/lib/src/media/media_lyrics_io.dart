import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_item.dart';

const _deviceMediaChannel = MethodChannel('app.maxei/device_media');

Future<String?> readEmbeddedLyrics(MediaItem item) async {
  String path;
  String? temporaryPath;
  if (item.uri.scheme == 'file') {
    path = item.uri.toFilePath();
  } else if (item.uri.scheme == 'content' && Platform.isAndroid) {
    temporaryPath = await _deviceMediaChannel.invokeMethod<String>(
      'copyAudioForLyrics',
      {'uri': item.uri.toString(), 'extension': item.extension},
    );
    if (temporaryPath == null) {
      throw const FormatException(
        'Le fichier audio temporaire est introuvable.',
      );
    }
    path = temporaryPath;
  } else {
    return null;
  }

  try {
    return await compute(_readLyricsFromFile, path);
  } finally {
    if (temporaryPath != null) {
      await _deviceMediaChannel.invokeMethod<void>(
        'deleteLyricsTempFile',
        temporaryPath,
      );
    }
  }
}

String? _readLyricsFromFile(String path) {
  final lyrics = readMetadata(File(path), getImage: false).lyrics?.trim();
  return lyrics == null || lyrics.isEmpty ? null : lyrics;
}
