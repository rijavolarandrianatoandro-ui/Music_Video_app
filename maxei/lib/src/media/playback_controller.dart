import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart'
    as audio_background;

import 'listening_session.dart';
import 'media_file_store.dart';
import 'media_item.dart';

enum PlaybackRepeatMode { off, all, one }

class PlaybackController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  late final StreamSubscription<PlayerState> _stateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  final ValueChanged<ListeningSession>? onListeningSessionChanged;
  List<MediaItem> _queue = const [];
  List<MediaItem> _originalQueue = const [];
  int _queueIndex = -1;
  Timer? _sleepTimer;
  MediaItem? current;
  bool isLoading = false;
  bool shuffleEnabled = false;
  PlaybackRepeatMode repeatMode = PlaybackRepeatMode.off;
  double speed = 1;
  double volume = 1;
  bool _handlingCompletion = false;
  bool _isBackgroundVideoAudio = false;
  String? _activeMediaPath;
  MediaItem? _previousVideoAudioItem;
  Duration? _previousVideoAudioPosition;
  ListeningSession? _activeListeningSession;
  Duration? _lastTrackedPosition;
  DateTime? _lastPublishedAt;

  PlaybackController({this.onListeningSessionChanged}) {
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (_isDisposed) return;
      notifyListeners();
      if (!_player.playing) {
        _lastTrackedPosition = null;
        _publishListeningSession();
      }
      if (state.processingState == ProcessingState.completed &&
          !_isBackgroundVideoAudio) {
        unawaited(_advanceAfterCompletion());
      }
    });
    _positionSubscription = _player.positionStream.listen(
      _trackListeningPosition,
    );
  }

  bool _isDisposed = false;
  bool get isPlaying => _player.playing;
  Duration get duration => _player.duration ?? Duration.zero;
  Duration get backgroundVideoAudioPosition => _player.position;
  bool get isBackgroundVideoAudioPlaying =>
      _isBackgroundVideoAudio && _player.playing;
  Stream<Duration> get positionStream => _player.positionStream;
  bool get hasSleepTimer => _sleepTimer?.isActive ?? false;
  List<MediaItem> get upcomingItems {
    if (_queueIndex < 0 || _queue.isEmpty) return const [];
    if (repeatMode == PlaybackRepeatMode.one && current != null) {
      return [current!];
    }
    final upcoming = _queue.skip(_queueIndex + 1).toList();
    if (repeatMode == PlaybackRepeatMode.all) {
      upcoming.addAll(_queue.take(_queueIndex));
      upcoming.add(_queue[_queueIndex]);
    }
    return upcoming;
  }

  void _trackListeningPosition(Duration position) {
    final previous = _lastTrackedPosition;
    _lastTrackedPosition = position;
    if (!_player.playing || previous == null) return;
    final elapsed = position - previous;
    if (elapsed <= Duration.zero || elapsed > const Duration(seconds: 2)) {
      return;
    }

    final session = _activeListeningSession;
    if (session == null) return;
    _activeListeningSession = session.copyWith(
      listenedMilliseconds:
          session.listenedMilliseconds + elapsed.inMilliseconds,
    );
    final now = DateTime.now();
    final lastPublished = _lastPublishedAt;
    if (lastPublished == null ||
        now.difference(lastPublished) >= const Duration(seconds: 10)) {
      _publishListeningSession();
    }
  }

  void _publishListeningSession() {
    final session = _activeListeningSession;
    if (session == null) return;
    _lastPublishedAt = DateTime.now();
    onListeningSessionChanged?.call(session);
  }

  Future<void> playQueue(List<MediaItem> items, int index) async {
    if (index < 0 || index >= items.length) return;
    _originalQueue = List.of(items);
    _queue = List.of(items);
    _queueIndex = index;
    if (shuffleEnabled) _shuffleUpcoming();
    await play(_queue[index]);
  }

  Future<void> playQueueItem(MediaItem item) async {
    final index = _queue.indexWhere((queuedItem) => queuedItem.id == item.id);
    if (index < 0) return;
    _queueIndex = index;
    await play(_queue[index]);
  }

  Future<void> next() async {
    await _advanceQueue();
  }

  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
    } else if (_queueIndex > 0) {
      _queueIndex--;
      await play(_queue[_queueIndex]);
    } else if (repeatMode == PlaybackRepeatMode.all && _queue.isNotEmpty) {
      _queueIndex = _queue.length - 1;
      await play(_queue[_queueIndex]);
    }
  }

  void toggleShuffle() {
    setShuffle(!shuffleEnabled);
  }

  void setShuffle(bool value) {
    if (shuffleEnabled == value) return;
    shuffleEnabled = value;
    final currentId = current?.id;
    if (!value && _originalQueue.isNotEmpty && currentId != null) {
      _queue = List.of(_originalQueue);
      final restoredIndex = _queue.indexWhere((item) => item.id == currentId);
      if (restoredIndex >= 0) _queueIndex = restoredIndex;
    } else if (value) {
      _shuffleUpcoming();
    }
    notifyListeners();
  }

  void _shuffleUpcoming() {
    if (_queue.isEmpty || _queueIndex < 0) return;
    final upcoming = _queue.sublist(_queueIndex + 1)..shuffle(_random);
    _queue = [..._queue.take(_queueIndex + 1), ...upcoming];
  }

  void setRepeatMode(PlaybackRepeatMode value) {
    repeatMode = value;
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0, 1);
    await _player.setVolume(volume);
    notifyListeners();
  }

  void cycleRepeatMode() {
    repeatMode = switch (repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    speed = value;
    await _player.setSpeed(value);
    notifyListeners();
  }

  Future<void> pause() => _player.pause();

  Future<void> playVideoAudioInBackground({
    required Uri uri,
    required MediaItem item,
    required Duration position,
    required double volume,
    required double speed,
  }) async {
    if (_isBackgroundVideoAudio) return;
    _previousVideoAudioItem = current;
    _previousVideoAudioPosition = _player.position;
    if (_player.playing) await _player.pause();
    _publishListeningSession();
    _activeListeningSession = null;
    _lastTrackedPosition = null;
    _isBackgroundVideoAudio = true;
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: audio_background.MediaItem(
            id: item.id,
            album: item.album.isEmpty ? 'Maxei' : item.album,
            title: item.title,
            artist: item.artist,
          ),
        ),
      );
      await _player.setVolume(volume.clamp(0, 1));
      await _player.setSpeed(speed);
      await _player.seek(position);
      await _player.play();
    } catch (_) {
      _isBackgroundVideoAudio = false;
      await _restoreAudioAfterBackgroundVideo();
      rethrow;
    }
  }

  Future<void> stopVideoAudioInBackground() async {
    if (!_isBackgroundVideoAudio) return;
    await _player.pause();
    _isBackgroundVideoAudio = false;
    await _restoreAudioAfterBackgroundVideo();
  }

  Future<void> _restoreAudioAfterBackgroundVideo() async {
    final previousItem = _previousVideoAudioItem;
    final previousPosition = _previousVideoAudioPosition;
    _previousVideoAudioItem = null;
    _previousVideoAudioPosition = null;
    if (previousItem == null) {
      await _player.stop();
      return;
    }
    final playableUri = await resolvePlayableMediaUri(
      previousItem.uri.toString(),
      extension: previousItem.extension,
    );
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(playableUri),
        tag: audio_background.MediaItem(
          id: previousItem.id,
          title: previousItem.title,
          artist: previousItem.artist,
          album: previousItem.album.isEmpty ? 'Maxei' : previousItem.album,
        ),
      ),
    );
    await _player.setVolume(volume);
    await _player.setSpeed(speed);
    await _player.seek(previousPosition ?? Duration.zero);
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = duration == null
        ? null
        : Timer(duration, () {
            _sleepTimer = null;
            unawaited(_player.pause());
            if (!_isDisposed) notifyListeners();
          });
    notifyListeners();
  }

  Future<void> _advanceAfterCompletion() async {
    if (_handlingCompletion || _isDisposed) return;
    _handlingCompletion = true;
    try {
      if (repeatMode == PlaybackRepeatMode.one && current != null) {
        await play(current!);
      } else {
        await _advanceQueue();
      }
    } catch (_) {
      // Keep the player available when the next file is unsupported.
    } finally {
      _handlingCompletion = false;
    }
  }

  Future<void> _advanceQueue() async {
    if (_queue.isEmpty) return;
    if (_queueIndex + 1 < _queue.length) {
      _queueIndex++;
    } else if (repeatMode == PlaybackRepeatMode.all) {
      _queueIndex = 0;
    } else {
      return;
    }
    await play(_queue[_queueIndex]);
  }

  Future<void> play(MediaItem item) async {
    _publishListeningSession();
    _activeListeningSession = null;
    _lastTrackedPosition = null;
    isLoading = true;
    current = item;
    notifyListeners();
    String? playableUri;
    try {
      playableUri = await resolvePlayableMediaUri(
        item.uri.toString(),
        extension: item.extension,
      );
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(playableUri),
          tag: audio_background.MediaItem(
            id: item.id,
            title: item.title,
            artist: item.artist,
            album: 'Maxei',
          ),
        ),
      );
      await _player.setVolume(volume);
      await _player.setSpeed(speed);
      final previousMediaPath = _activeMediaPath;
      _activeMediaPath = item.uri.toString();
      if (previousMediaPath != null && previousMediaPath != _activeMediaPath) {
        releasePlayableMediaUri(previousMediaPath);
      }
      item.playCount++;
      item.lastPlayedAt = DateTime.now();
      _activeListeningSession = ListeningSession(
        id: '${item.id}-${DateTime.now().microsecondsSinceEpoch}',
        mediaId: item.id,
        title: item.title,
        artist: item.artist,
        startedAt: DateTime.now(),
        listenedMilliseconds: 0,
      );
      _publishListeningSession();
      isLoading = false;
      notifyListeners();
      unawaited(_player.play().catchError((Object _) {}));
    } catch (_) {
      if (playableUri != null && _activeMediaPath != item.uri.toString()) {
        releasePlayableMediaUri(item.uri.toString());
      }
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else if (_player.audioSource != null) {
      unawaited(_player.play().catchError((Object _) {}));
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  void toggleFavorite() {
    final item = current;
    if (item == null) return;
    item.isFavorite = !item.isFavorite;
    notifyListeners();
  }

  @override
  void dispose() {
    _publishListeningSession();
    _isDisposed = true;
    _sleepTimer?.cancel();
    unawaited(_stateSubscription.cancel());
    unawaited(_positionSubscription.cancel());
    unawaited(_player.dispose());
    final activeMediaPath = _activeMediaPath;
    if (activeMediaPath != null) {
      releasePlayableMediaUri(activeMediaPath);
    }
    super.dispose();
  }
}
