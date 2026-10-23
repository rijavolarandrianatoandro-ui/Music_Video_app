import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';

import 'downloaded_media.dart';

const _maxWebFileBytes = 4 * 1024 * 1024;
const _prefix = 'maxei.media.';

Future<DownloadedMedia> persistPickedFile(PlatformFile file) async {
  final bytes = await file.xFile.readAsBytes();
  if (bytes.length > _maxWebFileBytes) {
    throw UnsupportedError(
      'Sur Edge, les fichiers de plus de 4 Mo doivent être importés sur mobile.',
    );
  }
  final id = DateTime.now().microsecondsSinceEpoch.toString();
  final key = '$_prefix$id';
  html.window.localStorage[key] = base64Encode(bytes);
  return DownloadedMedia(
    name: file.name,
    path: 'maxei-web://$id',
    size: bytes.length,
  );
}

Future<bool> persistedFileExists(String path) async {
  if (!path.startsWith('maxei-web://')) return false;
  final id = path.substring('maxei-web://'.length);
  return html.window.localStorage.containsKey('$_prefix$id');
}
