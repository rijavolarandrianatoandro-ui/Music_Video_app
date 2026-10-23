import 'package:file_picker/file_picker.dart';

import 'downloaded_media.dart';

Future<DownloadedMedia> persistPickedFile(PlatformFile file) =>
    throw UnsupportedError(
      'Le stockage local n’est pas disponible sur le Web.',
    );

Future<bool> persistedFileExists(String path) async => false;

Future<bool> requestPersistentStorage() async => false;

Future<String> resolvePlayableMediaUri(
  String path, {
  String? extension,
}) async => path;

void releasePlayableMediaUri(String path) {}
