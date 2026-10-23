import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'downloaded_media.dart';

Future<DownloadedMedia> persistPickedFile(PlatformFile file) async {
  final supportDirectory = await getApplicationSupportDirectory();
  final mediaDirectory = Directory(
    '${supportDirectory.path}${Platform.pathSeparator}media',
  );
  await mediaDirectory.create(recursive: true);

  final sourceName = file.name.split(RegExp(r'[/\\]')).last;
  final safeName = sourceName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final baseName = safeName.isEmpty ? 'media' : safeName;
  final dotIndex = baseName.lastIndexOf('.');
  final stem = dotIndex > 0 ? baseName.substring(0, dotIndex) : baseName;
  final extension = dotIndex > 0 ? baseName.substring(dotIndex) : '';
  final name = '$stem-${DateTime.now().microsecondsSinceEpoch}$extension';
  final destination = File(
    '${mediaDirectory.path}${Platform.pathSeparator}$name',
  );

  await file.xFile.saveTo(destination.path);
  return DownloadedMedia(
    name: name,
    path: destination.path,
    size: await destination.length(),
  );
}

Future<bool> persistedFileExists(String path) => File(path).exists();
