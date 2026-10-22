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
      artist = _artistFrom(file.name);

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
       artist = _artistFrom(name);

  final Uri uri;
  final String name;
  final int? sizeBytes;
  final String extension;
  final MediaKind kind;
  final String id;
  final String title;
  final String artist;
  bool isFavorite = false;
  int playCount = 0;
  DateTime? lastPlayedAt;

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) return 'Taille inconnue';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Map<String, Object?> toJson() => {
    'path': uri.toFilePath(),
    'name': name,
    'size': sizeBytes,
    'kind': kind.name,
    'favorite': isFavorite,
    'playCount': playCount,
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final item =
        MediaItem.downloaded(
            name: json['name'] as String,
            path: json['path'] as String,
            size: (json['size'] as num?)?.toInt() ?? 0,
            kind: MediaKind.values.byName(json['kind'] as String),
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
