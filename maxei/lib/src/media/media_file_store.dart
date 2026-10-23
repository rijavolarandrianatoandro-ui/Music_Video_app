import 'package:file_picker/file_picker.dart';

import 'downloaded_media.dart';
import 'media_file_store_stub.dart'
    if (dart.library.html) 'media_file_store_web.dart'
    if (dart.library.io) 'media_file_store_io.dart'
    as implementation;

Future<DownloadedMedia> persistPickedFile(PlatformFile file) =>
    implementation.persistPickedFile(file);

Future<bool> persistedFileExists(String path) =>
    implementation.persistedFileExists(path);
