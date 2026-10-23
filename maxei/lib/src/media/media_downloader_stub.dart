import 'package:flutter/foundation.dart';

import 'downloaded_media.dart';

Future<DownloadedMedia> downloadDirectMedia(
  Uri uri, {
  required ValueChanged<double?> onProgress,
  String? resumePath,
}) => throw UnsupportedError(
  'Le téléchargement local n’est pas disponible sur cette plateforme.',
);
