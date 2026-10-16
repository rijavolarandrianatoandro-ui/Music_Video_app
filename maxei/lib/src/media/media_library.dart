import 'package:file_picker/file_picker.dart';

import 'media_item.dart';

class MediaLibrary {
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
        items.add(MediaItem(file: file, kind: kind));
      }
    }
    return items;
  }
}
