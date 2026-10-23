import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download_manager.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager();
  ref.onDispose(manager.dispose);
  return manager;
});
