enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.uri,
    required this.name,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.error,
    this.resumePath,
  });

  final String id;
  final Uri uri;
  final String name;
  final DownloadStatus status;
  final double progress;
  final String? error;
  final String? resumePath;

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
    String? resumePath,
  }) => DownloadTask(
    id: id,
    uri: uri,
    name: name,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: error ?? this.error,
    resumePath: resumePath ?? this.resumePath,
  );
}
