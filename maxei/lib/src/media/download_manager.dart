import 'dart:async';
import 'dart:collection';

import 'download_task.dart';
import 'media_downloader.dart';

class DownloadManager {
  final _tasks = <String, DownloadTask>{};
  final _queue = Queue<String>();
  final _changes = StreamController<List<DownloadTask>>.broadcast();
  bool _running = false;

  Stream<List<DownloadTask>> get changes => _changes.stream;
  List<DownloadTask> get tasks => List.unmodifiable(_tasks.values);

  Future<DownloadedMedia> enqueue(Uri uri, {String? name}) async {
    final id = uri.toString();
    final existing = _tasks[id];
    if (existing != null && existing.status == DownloadStatus.completed) {
      throw StateError('Ce téléchargement est déjà terminé.');
    }
    final task = DownloadTask(
      id: id,
      uri: uri,
      name: name ?? _nameFromUri(uri),
      status: DownloadStatus.queued,
    );
    _tasks[id] = task;
    _queue.add(id);
    _publish();
    return _runUntilComplete(id);
  }

  Future<DownloadedMedia> resume(String id) {
    final task = _tasks[id];
    if (task == null) throw StateError('Téléchargement introuvable.');
    if (!_queue.contains(id)) _queue.add(id);
    _publish();
    return _runUntilComplete(id);
  }

  void pause(String id) {
    final task = _tasks[id];
    if (task == null) return;
    _tasks[id] = task.copyWith(status: DownloadStatus.paused);
    _publish();
  }

  Future<DownloadedMedia> _runUntilComplete(String id) async {
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _running = true;
    try {
      final task = _tasks[id];
      if (task == null) throw StateError('Téléchargement introuvable.');
      _queue.remove(id);
      _tasks[id] = task.copyWith(status: DownloadStatus.downloading);
      _publish();
      final download = await downloadDirectMedia(
        task.uri,
        resumePath: task.resumePath,
        onProgress: (progress) {
          final current = _tasks[id];
          if (current != null) {
            _tasks[id] = current.copyWith(
              progress: progress ?? current.progress,
            );
            _publish();
          }
        },
      );
      _tasks[id] = task.copyWith(
        status: DownloadStatus.completed,
        progress: 1,
        resumePath: download.path,
      );
      _publish();
      return download;
    } catch (error) {
      final current = _tasks[id];
      if (current != null) {
        _tasks[id] = current.copyWith(
          status: DownloadStatus.failed,
          error: error.toString(),
        );
        _publish();
      }
      rethrow;
    } finally {
      _running = false;
      if (_queue.isNotEmpty) {
        unawaited(_runUntilComplete(_queue.first));
      }
    }
  }

  void _publish() => _changes.add(tasks);

  String _nameFromUri(Uri uri) =>
      uri.pathSegments.isEmpty ? 'media' : uri.pathSegments.last;

  Future<void> dispose() => _changes.close();
}
