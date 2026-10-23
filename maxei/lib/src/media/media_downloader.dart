import 'package:flutter/foundation.dart';

import 'downloaded_media.dart';
import 'media_downloader_stub.dart'
    if (dart.library.io) 'media_downloader_io.dart'
    as implementation;

export 'downloaded_media.dart';

Future<DownloadedMedia> downloadDirectMedia(
  Uri uri, {
  required ValueChanged<double?> onProgress,
  String? resumePath,
}) => implementation.downloadDirectMedia(uri, onProgress: onProgress);
