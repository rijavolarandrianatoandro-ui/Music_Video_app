import 'package:file_picker/file_picker.dart';

enum MediaKind { audio, video }

class MediaItem {
  MediaItem({required this.file, required this.kind})
    : id = file.uri.toString(),
      title = _trackTitle(file.name),
      artist = _artistFrom(file.name);

  final PlatformFile file;
  final MediaKind kind;
  final String id;
  final String title;
  final String artist;
  bool isFavorite = false;
  int playCount = 0;
  DateTime? lastPlayedAt;

  String get extension => (file.extension ?? '').toLowerCase();
  String get sizeLabel {
    final bytes = file.lengthSync();
    if (bytes == null) return 'Taille inconnue';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
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
