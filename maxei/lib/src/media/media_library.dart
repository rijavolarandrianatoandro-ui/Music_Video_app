import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_downloader.dart';
import 'device_media_scanner.dart';
import 'media_file_store.dart';
import 'media_item.dart';
import 'listening_session.dart';
import 'media_playlist.dart';

class MediaLibraryState {
  const MediaLibraryState({
    required this.items,
    required this.playlists,
    required this.listeningHistory,
  });

  final List<MediaItem> items;
  final List<MediaPlaylist> playlists;
  final List<ListeningSession> listeningHistory;
}

class MediaLibrary {
  static const _itemsKey = 'maxei.library.items.v1';
  static const _playlistsKey = 'maxei.library.playlists.v1';
  static const _listeningHistoryKey = 'maxei.library.listeningHistory.v1';
  final DeviceMediaScanner _deviceMediaScanner = DeviceMediaScanner();
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _importIosFolder();
    }

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

  Future<List<MediaItem>> _importIosFolder() async {
    const channel = MethodChannel('app.maxei/ios_folder_media_import');
    final response = await channel.invokeListMethod<Object?>('importFolder');
    if (response == null) return const [];

    final items = <MediaItem>[];
    for (final entry in response) {
      if (entry is! Map) {
        throw const FormatException('Métadonnées média iOS invalides.');
      }
      final metadata = Map<Object?, Object?>.from(entry);
      final name = metadata['name'];
      final path = metadata['path'];
      final kind = metadata['kind'];
      final size = metadata['size'];
      final addedAtMs = metadata['addedAtMs'];
      if (name is! String ||
          path is! String ||
          (kind != 'audio' && kind != 'video') ||
          size is! num ||
          addedAtMs is! num) {
        throw const FormatException('Métadonnées média iOS invalides.');
      }
      items.add(
        MediaItem.stored(
          name: name,
          uri: Uri.file(path),
          size: size.toInt(),
          kind: kind == 'audio' ? MediaKind.audio : MediaKind.video,
          addedAt: DateTime.fromMillisecondsSinceEpoch(addedAtMs.toInt()),
        ),
      );
    }
    return items;
  }

  Future<bool> requestPersistentBrowserStorage() => requestPersistentStorage();

  Future<DeviceMediaScanResult> scanDeviceMedia() => _deviceMediaScanner.scan();

  Future<void> openDeviceAudioSettings() =>
      _deviceMediaScanner.openAppSettings();

  Future<MediaLibraryState> restore({
    Set<String>? availableDeviceAudioUris,
    bool preserveUnverifiedDeviceAudio = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final items = _decodeList(
      preferences.getString(_itemsKey),
      MediaItem.fromJson,
    );
    final availableItems = <MediaItem>[];
    for (final item in items) {
      if (item.uri.scheme == 'content' && preserveUnverifiedDeviceAudio) {
        availableItems.add(item);
        continue;
      }
      if (item.uri.scheme == 'content' && availableDeviceAudioUris != null) {
        if (availableDeviceAudioUris.contains(item.uri.toString())) {
          availableItems.add(item);
        }
        continue;
      }
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
    final listeningHistory = _decodeList(
      preferences.getString(_listeningHistoryKey),
      ListeningSession.fromJson,
    );
    for (final playlist in playlists) {
      playlist.mediaIds.removeWhere((id) => !availableIds.contains(id));
    }
    return MediaLibraryState(
      items: availableItems,
      playlists: playlists,
      listeningHistory: listeningHistory,
    );
  }

  Future<void> save(
    List<MediaItem> items,
    List<MediaPlaylist> playlists, {
    List<ListeningSession>? listeningHistory,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _itemsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      _playlistsKey,
      jsonEncode(playlists.map((playlist) => playlist.toJson()).toList()),
    );
    if (listeningHistory != null) {
      await preferences.setString(
        _listeningHistoryKey,
        jsonEncode(
          listeningHistory.map((session) => session.toJson()).toList(),
        ),
      );
    }
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
