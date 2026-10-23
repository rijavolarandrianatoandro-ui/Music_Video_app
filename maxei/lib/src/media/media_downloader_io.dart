import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'downloaded_media.dart';

const _maxDownloadBytes = 500 * 1024 * 1024;
const _mediaExtensions = {
  'aac',
  'aiff',
  'avi',
  'flac',
  'm4a',
  'm4v',
  'mkv',
  'mov',
  'mp3',
  'mp4',
  'mpeg',
  'mpg',
  'ogg',
  'opus',
  'wav',
  'webm',
  'wma',
};

Future<DownloadedMedia> downloadDirectMedia(
  Uri uri, {
  required ValueChanged<double?> onProgress,
  String? resumePath,
}) async {
  final extension = uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.last.split('.').last.toLowerCase();
  if (uri.scheme != 'https' || !_mediaExtensions.contains(extension)) {
    throw const FormatException(
      'Seuls les fichiers média directs en HTTPS sont acceptés.',
    );
  }

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = 2;
  File? partialFile;
  IOSink? sink;
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = true;
    request.maxRedirects = 5;
    var existingBytes = 0;
    if (resumePath != null) {
      final existing = File(resumePath);
      if (await existing.exists()) {
        existingBytes = await existing.length();
        if (existingBytes > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
        }
      }
    }
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw HttpException('Le serveur a répondu ${response.statusCode}.');
    }
    final canResume =
        existingBytes > 0 && response.statusCode == HttpStatus.partialContent;
    if (!canResume) existingBytes = 0;
    final totalBytes = response.contentLength > 0
        ? response.contentLength + existingBytes
        : -1;
    if (totalBytes > _maxDownloadBytes) {
      throw const FormatException('Le fichier dépasse la limite de 500 Mo.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final downloadsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}Maxei${Platform.pathSeparator}Downloads',
    );
    await downloadsDirectory.create(recursive: true);

    final sourceName = Uri.decodeComponent(uri.pathSegments.last);
    final safeName = sourceName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final name = safeName.isEmpty || safeName.startsWith('.')
        ? 'media_${DateTime.now().millisecondsSinceEpoch}.$extension'
        : safeName;
    var outputFile = resumePath == null
        ? File('${downloadsDirectory.path}${Platform.pathSeparator}$name')
        : File(resumePath);
    if (resumePath == null && await outputFile.exists()) {
      final dot = name.lastIndexOf('.');
      final stem = dot > 0 ? name.substring(0, dot) : name;
      outputFile = File(
        '${downloadsDirectory.path}${Platform.pathSeparator}$stem-${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
    }
    partialFile = File('${outputFile.path}.part');
    if (!canResume && await partialFile.exists()) {
      await partialFile.delete();
    }
    if (canResume) {
      await File(resumePath!).rename(partialFile.path);
    }
    sink = partialFile.openWrite(
      mode: canResume ? FileMode.append : FileMode.write,
    );

    var received = existingBytes;
    var lastReportedPercent = -1;
    onProgress(totalBytes > 0 ? received / totalBytes : null);
    await for (final chunk in response) {
      received += chunk.length;
      if (received > _maxDownloadBytes) {
        throw const FormatException('Le fichier dépasse la limite de 500 Mo.');
      }
      sink.add(chunk);
      if (totalBytes > 0) {
        final percent = (received * 100 / totalBytes).floor();
        if (percent != lastReportedPercent) {
          lastReportedPercent = percent;
          onProgress(percent / 100);
        }
      }
    }
    await sink.flush();
    await sink.close();
    sink = null;
    final file = await partialFile.rename(outputFile.path);
    onProgress(1);
    return DownloadedMedia(
      name: outputFile.uri.pathSegments.last,
      path: file.path,
      size: received,
    );
  } catch (_) {
    await sink?.close();
    if (partialFile != null && await partialFile.exists()) {
      await partialFile.delete();
    }
    rethrow;
  } finally {
    client.close(force: true);
  }
}
