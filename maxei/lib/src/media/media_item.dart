import 'package:file_picker/file_picker.dart';

enum MediaKind { audio, video }

class MediaItem {
  MediaItem({required PlatformFile file, required this.kind})
    : id = file.uri.toString(),
      uri = file.uri,
      name = file.name,
      sizeBytes = file.lengthSync(),
      extension = (file.extension ?? '').toLowerCase(),
      title = _trackTitle(file.name),
      artist = _artistFrom(file.name),
      album = '',
      durationMs = null,
      addedAt = DateTime.now();

  MediaItem.downloaded({
    required String name,
    required String path,
    required int size,
    required this.kind,
  }) : id = Uri.file(path).toString(),
       uri = Uri.file(path),
       name = name,
       sizeBytes = size,
       extension = name.contains('.') ? name.split('.').last.toLowerCase() : '',
       title = _trackTitle(name),
       artist = _artistFrom(name),
       album = '',
       durationMs = null,
       addedAt = DateTime.now();

  MediaItem.stored({
    required this.name,
    required this.uri,
    required int size,
    required this.kind,
    String? title,
    String? artist,
    this.album = '',
    this.durationMs,
    DateTime? addedAt,
  }) : id = uri.toString(),
       sizeBytes = size,
       extension = name.contains('.') ? name.split('.').last.toLowerCase() : '',
       addedAt = addedAt ?? DateTime.now(),
       title = title?.trim().isNotEmpty == true
           ? title!.trim()
           : _trackTitle(name),
       artist = artist?.trim().isNotEmpty == true
           ? artist!.trim()
           : _artistFrom(name);

  MediaItem.deviceAudio({
    required this.name,
    required this.uri,
    required int size,
    required String title,
    required this.artist,
    required this.album,
    required this.durationMs,
    DateTime? addedAt,
  }) : id = uri.toString(),
       sizeBytes = size,
       extension = name.contains('.') ? name.split('.').last.toLowerCase() : '',
       kind = MediaKind.audio,
       addedAt = addedAt ?? DateTime.now(),
       title = title.trim().isEmpty ? _trackTitle(name) : title.trim();

  final Uri uri;
  final String name;
  final int? sizeBytes;
  final String extension;
  final MediaKind kind;
  final String id;
  final String title;
  final String artist;
  final String album;
  final int? durationMs;
  final DateTime addedAt;
  bool isFavorite = false;
  int playCount = 0;
  DateTime? lastPlayedAt;

  bool get isShortAudio =>
      kind == MediaKind.audio &&
      durationMs != null &&
      durationMs! < const Duration(seconds: 10).inMilliseconds;

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) return 'Taille inconnue';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Map<String, Object?> toJson() => {
    'uri': uri.toString(),
    'path': uri.scheme == 'file' ? uri.toFilePath() : uri.toString(),
    'name': name,
    'size': sizeBytes,
    'kind': kind.name,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'addedAt': addedAt.toIso8601String(),
    'favorite': isFavorite,
    'playCount': playCount,
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final rawUri = json['uri'] as String?;
    final item =
        MediaItem.stored(
            name: json['name'] as String,
            uri: rawUri == null
                ? Uri.file(json['path'] as String)
                : Uri.parse(rawUri),
            size: (json['size'] as num?)?.toInt() ?? 0,
            kind: MediaKind.values.byName(json['kind'] as String),
            title: json['title'] as String?,
            artist: json['artist'] as String?,
            album: json['album'] as String? ?? '',
            durationMs: (json['durationMs'] as num?)?.toInt(),
            addedAt:
                DateTime.tryParse(json['addedAt'] as String? ?? '') ??
                DateTime.now(),
          )
          ..isFavorite = json['favorite'] as bool? ?? false
          ..playCount = (json['playCount'] as num?)?.toInt() ?? 0;
    final lastPlayedAt = json['lastPlayedAt'] as String?;
    item.lastPlayedAt = lastPlayedAt == null
        ? null
        : DateTime.tryParse(lastPlayedAt);
    return item;
  }

  static String _titleFrom(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  static String _artistFrom(String fileName) {
    final parts = _titleFrom(fileName).split(' - ');
    return parts.length > 1 ? parts.first.trim() : 'Fichier local';
  }

  static String _trackTitle(String fileName) {
    final parts = _titleFrom(fileName).split(' - ');
    return parts.length > 1 ? parts.skip(1).join(' - ').trim() : parts.first;
  }
}
