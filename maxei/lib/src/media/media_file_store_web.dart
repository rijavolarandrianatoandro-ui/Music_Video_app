import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:web/web.dart' as web;

import 'downloaded_media.dart';

const _databaseName = 'maxei.media';
const _storeName = 'files';
const _legacyPrefix = 'maxei.media.';
const _pathPrefix = 'maxei-web://';

Future<Database>? _database;
final Map<String, String> _objectUrls = {};

Future<Database> get _databaseInstance => _database ??= _openDatabase();

Future<Database> _openDatabase() async {
  final factory = getIdbFactory();
  if (factory == null) {
    throw UnsupportedError(
      'IndexedDB n’est pas disponible dans ce navigateur.',
    );
  }
  return factory.open(
    _databaseName,
    version: 1,
    onUpgradeNeeded: (event) {
      if (!event.database.objectStoreNames.contains(_storeName)) {
        event.database.createObjectStore(_storeName);
      }
    },
  );
}

Future<DownloadedMedia> persistPickedFile(PlatformFile file) async {
  final bytes = await file.xFile.readAsBytes();
  final id = DateTime.now().microsecondsSinceEpoch.toString();
  final database = await _databaseInstance;
  final transaction = database.transaction(_storeName, idbModeReadWrite);
  await transaction.objectStore(_storeName).put(bytes, id);
  await transaction.completed;

  return DownloadedMedia(
    name: file.name,
    path: '$_pathPrefix$id',
    size: bytes.length,
  );
}

Future<bool> requestPersistentStorage() async {
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } on Object {
    return false;
  }
}

Future<bool> persistedFileExists(String path) async {
  final id = _idFromPath(path);
  if (id == null) return false;

  final database = await _databaseInstance;
  final transaction = database.transaction(_storeName, idbModeReadOnly);
  final store = transaction.objectStore(_storeName);
  if (await store.getObject(id) != null) return true;

  final legacyValue = web.window.localStorage.getItem('$_legacyPrefix$id');
  if (legacyValue == null) return false;

  final bytes = Uint8List.fromList(base64Decode(legacyValue));
  final migration = database.transaction(_storeName, idbModeReadWrite);
  await migration.objectStore(_storeName).put(bytes, id);
  await migration.completed;
  web.window.localStorage.removeItem('$_legacyPrefix$id');
  return true;
}

Future<String> resolvePlayableMediaUri(String path, {String? extension}) async {
  final id = _idFromPath(path);
  if (id == null) return path;

  final existingUrl = _objectUrls[id];
  if (existingUrl != null) return existingUrl;

  final database = await _databaseInstance;
  final transaction = database.transaction(_storeName, idbModeReadOnly);
  final value = await transaction.objectStore(_storeName).getObject(id);
  if (value is! Uint8List) {
    throw StateError('Le fichier média enregistré est introuvable.');
  }

  final mimeType = _mimeTypeForExtension(extension ?? '');
  final blob = web.Blob(
    <web.BlobPart>[value.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  _objectUrls[id] = objectUrl;
  return objectUrl;
}

void releasePlayableMediaUri(String path) {
  final id = _idFromPath(path);
  if (id == null) return;

  final objectUrl = _objectUrls.remove(id);
  if (objectUrl != null) web.URL.revokeObjectURL(objectUrl);
}

String? _idFromPath(String path) =>
    path.startsWith(_pathPrefix) ? path.substring(_pathPrefix.length) : null;

String _mimeTypeForExtension(String extension) {
  return switch (extension) {
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'mp4' => 'video/mp4',
    'aac' => 'audio/aac',
    'wav' => 'audio/wav',
    'flac' => 'audio/flac',
    'ogg' || 'opus' => 'audio/ogg',
    'aiff' => 'audio/aiff',
    'wma' => 'audio/x-ms-wma',
    'm4v' => 'video/x-m4v',
    'mov' => 'video/quicktime',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    'avi' => 'video/x-msvideo',
    '3gp' => 'video/3gpp',
    'mpeg' || 'mpg' => 'video/mpeg',
    _ => 'application/octet-stream',
  };
}
