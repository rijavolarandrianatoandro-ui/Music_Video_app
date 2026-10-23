import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_downloader.dart';
import 'media_file_store.dart';
import 'media_item.dart';
import 'media_playlist.dart';

class MediaLibraryState {
  const MediaLibraryState({required this.items, required this.playlists});

  final List<MediaItem> items;
  final List<MediaPlaylist> playlists;
}

class MediaLibrary {
  static const _itemsKey = 'maxei.library.items.v1';
  static const _playlistsKey = 'maxei.library.playlists.v1';
  static const _audioExtensions = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'flac',
    'ogg',
    'opus',
    'aiff',
    'wma',
  };
  static const _videoExtensions = {
    'mp4',
    'm4v',
    'mov',
    'mkv',
    'webm',
    'avi',
    '3gp',
    'mpeg',
    'mpg',
  };

  Future<List<MediaItem>> importFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.media,
      dialogTitle: 'Choisir des fichiers audio ou vidéo',
    );
    if (files.isEmpty) return const [];

    final items = <MediaItem>[];
    for (final file in files) {
      final extension = (file.extension ?? '').toLowerCase();
      final kind = _audioExtensions.contains(extension)
          ? MediaKind.audio
          : _videoExtensions.contains(extension)
          ? MediaKind.video
          : null;
      if (kind != null && file.uri.toString().isNotEmpty) {
        final stored = await persistPickedFile(file);
        items.add(
          MediaItem.stored(
            name: stored.name,
            uri: kIsWeb ? Uri.parse(stored.path) : Uri.file(stored.path),
            size: stored.size,
            kind: kind,
          ),
        );
      }
    }
    return items;
  }

  Future<MediaLibraryState> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final items = _decodeList(
      preferences.getString(_itemsKey),
      MediaItem.fromJson,
    );
    final availableItems = <MediaItem>[];
    for (final item in items) {
      final storedPath = item.uri.scheme == 'file'
          ? item.uri.toFilePath()
          : item.uri.toString();
      if (await persistedFileExists(storedPath)) {
        availableItems.add(item);
      }
    }
    final availableIds = availableItems.map((item) => item.id).toSet();
    final playlists = _decodeList(
      preferences.getString(_playlistsKey),
      MediaPlaylist.fromJson,
    );
    for (final playlist in playlists) {
      playlist.mediaIds.removeWhere((id) => !availableIds.contains(id));
    }
    return MediaLibraryState(items: availableItems, playlists: playlists);
  }

  Future<void> save(
    List<MediaItem> items,
    List<MediaPlaylist> playlists,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _itemsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      _playlistsKey,
      jsonEncode(playlists.map((playlist) => playlist.toJson()).toList()),
    );
  }

  List<T> _decodeList<T>(
    String? encoded,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (encoded == null) return [];
    try {
      final values = jsonDecode(encoded) as List<dynamic>;
      final decoded = <T>[];
      for (final value in values.whereType<Map<String, dynamic>>()) {
        try {
          decoded.add(fromJson(value));
        } on Object {
          // Keep valid entries when one old or damaged record is unreadable.
        }
      }
      return decoded;
    } on Object {
      return [];
    }
  }

  MediaItem? itemFromDownloaded(DownloadedMedia download) {
    final extension = download.name.split('.').last.toLowerCase();
    final kind = _audioExtensions.contains(extension)
        ? MediaKind.audio
        : _videoExtensions.contains(extension)
        ? MediaKind.video
        : null;
    if (kind == null) return null;
    return MediaItem.downloaded(
      name: download.name,
      path: download.path,
      size: download.size,
      kind: kind,
    );
  }
}
