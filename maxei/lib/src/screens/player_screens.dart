import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../media/media_file_store.dart';
import '../media/media_item.dart';
import '../media/media_lyrics.dart';
import '../media/lyrics_parser.dart';
import '../media/playback_controller.dart';
import '../media/video_player_source.dart';
import '../theme/maxei_theme.dart';
import '../widgets/liquid_surface.dart';
import '../widgets/vinyl_record.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    super.key,
    required this.playback,
    required this.onMediaChanged,
  });

  final PlaybackController playback;
  final VoidCallback onMediaChanged;

  String _time(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _showSleepTimer(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Arrêter la lecture après',
                  style: TextStyle(
                    color: aqua,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final minutes in [15, 30, 45, 60])
                  ListTile(
                    leading: const Icon(Icons.bedtime_outlined, color: ink),
                    title: Text('$minutes minutes'),
                    onTap: () {
                      playback.setSleepTimer(Duration(minutes: minutes));
                      Navigator.pop(context);
                    },
                  ),
                if (playback.hasSleepTimer)
                  ListTile(
                    leading: const Icon(Icons.timer_off_outlined, color: ink),
                    title: const Text('Désactiver le minuteur'),
                    onTap: () {
                      playback.setSleepTimer(null);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        centerTitle: true,
        title: const Text(
          'LECTURE EN COURS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: canvas.withValues(alpha: 0.42),
      ),
      body: LiquidBackdrop(
        child: AnimatedBuilder(
          animation: playback,
          builder: (context, _) {
            final item = playback.current;
            if (item == null) return const SizedBox.shrink();
            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final recordSize = (constraints.maxWidth * 0.76)
                      .clamp(220, 310)
                      .toDouble();
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 38,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          VinylRecord(
                            title: item.title,
                            isPlaying: playback.isPlaying,
                            size: recordSize,
                          ),
                          const SizedBox(height: 23),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.artist.toUpperCase(),
                                      style: TextStyle(
                                        color: ink.withValues(alpha: 0.62),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ink,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: item.isFavorite
                                    ? 'Retirer des favoris'
                                    : 'Ajouter aux favoris',
                                onPressed: () {
                                  playback.toggleFavorite();
                                  onMediaChanged();
                                },
                                icon: Icon(
                                  item.isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                          StreamBuilder<Duration>(
                            stream: playback.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final total = playback.duration;
                              final max = total.inMilliseconds
                                  .toDouble()
                                  .clamp(1, double.infinity)
                                  .toDouble();
                              return Column(
                                children: [
                                  Slider(
                                    value: position.inMilliseconds
                                        .toDouble()
                                        .clamp(0, max)
                                        .toDouble(),
                                    max: max,
                                    onChanged: (value) => playback.seek(
                                      Duration(milliseconds: value.round()),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _time(position),
                                        style: TextStyle(
                                          color: ink.withValues(alpha: 0.65),
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        _time(total),
                                        style: TextStyle(
                                          color: ink.withValues(alpha: 0.65),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: surface.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(34),
                              border: Border.all(
                                color: ink.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'Précédent',
                                      onPressed: playback.previous,
                                      icon: const Icon(
                                        Icons.skip_previous_rounded,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Container(
                                      width: 78,
                                      height: 78,
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: aqua.withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: aqua.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: SizedBox.expand(
                                        child: FilledButton(
                                          onPressed: playback.isLoading
                                              ? null
                                              : playback.toggle,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: aqua,
                                            foregroundColor: canvas,
                                            shape: const CircleBorder(),
                                            padding: EdgeInsets.zero,
                                          ),
                                          child: playback.isLoading
                                              ? const SizedBox.square(
                                                  dimension: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: canvas,
                                                      ),
                                                )
                                              : Icon(
                                                  playback.isPlaying
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                            .play_arrow_rounded,
                                                  size: 38,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    IconButton(
                                      tooltip: 'Suivant',
                                      onPressed: playback.next,
                                      icon: const Icon(
                                        Icons.skip_next_rounded,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: playback.shuffleEnabled
                                          ? 'Aléatoire activé'
                                          : 'Lecture aléatoire',
                                      onPressed: playback.toggleShuffle,
                                      color: playback.shuffleEnabled
                                          ? aqua
                                          : mutedInk,
                                      icon: const Icon(Icons.shuffle_rounded),
                                    ),
                                    const SizedBox(width: 42),
                                    IconButton(
                                      tooltip: switch (playback.repeatMode) {
                                        PlaybackRepeatMode.off =>
                                          'Répétition désactivée',
                                        PlaybackRepeatMode.all =>
                                          'Répéter la file',
                                        PlaybackRepeatMode.one =>
                                          'Répéter le titre',
                                      },
                                      onPressed: playback.cycleRepeatMode,
                                      color:
                                          playback.repeatMode ==
                                              PlaybackRepeatMode.off
                                          ? mutedInk
                                          : aqua,
                                      icon: Icon(
                                        playback.repeatMode ==
                                                PlaybackRepeatMode.one
                                            ? Icons.repeat_one_rounded
                                            : Icons.repeat_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (playback.upcomingItems.isNotEmpty)
                            LiquidGlass(
                              radius: 20,
                              tint: const Color(0xFF202629),
                              child: Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  key: const ValueKey('upcoming-queue'),
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    10,
                                  ),
                                  leading: const Icon(
                                    Icons.queue_music_rounded,
                                    color: aqua,
                                  ),
                                  title: const Text(
                                    'À suivre',
                                    style: TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${playback.upcomingItems.length} titre${playback.upcomingItems.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: mutedInk,
                                      fontSize: 11,
                                    ),
                                  ),
                                  children: [
                                    for (final (index, queuedItem)
                                        in playback.upcomingItems
                                            .take(30)
                                            .indexed)
                                      ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                        leading: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: mutedInk,
                                            fontSize: 12,
                                          ),
                                        ),
                                        title: Text(
                                          queuedItem.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: ink,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          queuedItem.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: mutedInk,
                                            fontSize: 11,
                                          ),
                                        ),
                                        onTap: () =>
                                            playback.playQueueItem(queuedItem),
                                      ),
                                    if (playback.upcomingItems.length > 30)
                                      const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          '+ titres suivants',
                                          style: TextStyle(
                                            color: mutedInk,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PopupMenuButton<double>(
                                tooltip: 'Vitesse de lecture',
                                initialValue: playback.speed,
                                onSelected: playback.setSpeed,
                                itemBuilder: (context) => [
                                  for (final speed in [
                                    0.5,
                                    0.75,
                                    1.0,
                                    1.25,
                                    1.5,
                                    2.0,
                                  ])
                                    PopupMenuItem(
                                      value: speed,
                                      child: Text('$speed×'),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  child: Text(
                                    '${playback.speed}×',
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showSleepTimer(context),
                                icon: Icon(
                                  playback.hasSleepTimer
                                      ? Icons.timer_rounded
                                      : Icons.bedtime_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  playback.hasSleepTimer
                                      ? 'Minuteur actif'
                                      : 'Minuteur',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: ink,
                                ),
                              ),
                            ],
                          ),
                          _LyricsSection(item: item, playback: playback),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LyricsSection extends StatefulWidget {
  const _LyricsSection({required this.item, required this.playback});

  final MediaItem item;
  final PlaybackController playback;

  @override
  State<_LyricsSection> createState() => _LyricsSectionState();
}

class _LyricsSectionState extends State<_LyricsSection> {
  bool _expanded = false;
  Future<String?>? _lyricsFuture;

  @override
  void didUpdateWidget(covariant _LyricsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _expanded = false;
      _lyricsFuture = null;
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _lyricsFuture ??= readEmbeddedLyrics(widget.item);
    });
  }

  @override
  Widget build(BuildContext context) => LiquidGlass(
    radius: 20,
    tint: const Color(0xFF202629),
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.lyrics_rounded, color: aqua),
          title: const Text(
            'Paroles',
            style: TextStyle(color: ink, fontWeight: FontWeight.w700),
          ),
          trailing: Icon(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: ink,
          ),
          onTap: _toggle,
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: FutureBuilder<String?>(
              future: _lyricsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(color: aqua),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'Impossible de lire les paroles intégrées : ${snapshot.error}',
                    style: const TextStyle(color: ink, height: 1.45),
                  );
                }
                final lyrics = snapshot.data;
                if (lyrics == null || lyrics.trim().isEmpty) {
                  return const Text(
                    'Aucune parole intégrée.',
                    style: TextStyle(color: mutedInk, height: 1.45),
                  );
                }
                return _LyricsText(
                  lyrics: lyrics,
                  positionStream: widget.playback.positionStream,
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _LyricsText extends StatefulWidget {
  const _LyricsText({required this.lyrics, required this.positionStream});

  final String lyrics;
  final Stream<Duration> positionStream;

  @override
  State<_LyricsText> createState() => _LyricsTextState();
}

class _LyricsTextState extends State<_LyricsText> {
  final _scrollController = ScrollController();
  final _activeLineKey = GlobalKey();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = parseLyrics(widget.lyrics);
    if (!lines.any((line) => line.at != null)) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: SelectableText(
            widget.lyrics,
            style: const TextStyle(color: ink, height: 1.65),
          ),
        ),
      );
    }
    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      initialData: Duration.zero,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        var activeIndex = -1;
        for (var index = 0; index < lines.length; index++) {
          final at = lines[index].at;
          if (at != null && at <= position) activeIndex = index;
        }
        if (activeIndex != _lastActiveIndex) {
          _lastActiveIndex = activeIndex;
          if (activeIndex >= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final activeContext = _activeLineKey.currentContext;
              if (activeContext != null) {
                unawaited(
                  Scrollable.ensureVisible(
                    activeContext,
                    alignment: 0.5,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                );
              }
            });
          }
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < lines.length; index++)
                  Padding(
                    key: index == activeIndex ? _activeLineKey : null,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      lines[index].text,
                      style: TextStyle(
                        color: index == activeIndex ? aqua : mutedInk,
                        fontSize: index == activeIndex ? 17 : 14,
                        fontWeight: index == activeIndex
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.item});

  final MediaItem item;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _playbackMediaPath;
  Object? _error;
  double _speed = 1;
  bool _muted = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  double _doubleTapX = 0;
  double _videoWidth = 1;
  bool? _seekForwardFeedback;
  Timer? _seekFeedbackTimer;
  Timer? _controlsTimer;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    final previousController = _controller;
    previousController?.removeListener(_onControllerChanged);
    if (previousController != null) unawaited(previousController.dispose());
    _controller = null;
    final previousMediaPath = _playbackMediaPath;
    if (previousMediaPath != null) {
      releasePlayableMediaUri(previousMediaPath);
      _playbackMediaPath = null;
    }
    setState(() {
      _isInitializing = true;
      _error = null;
    });
    try {
      final playableUri = await resolvePlayableMediaUri(
        widget.item.uri.toString(),
        extension: widget.item.extension,
      );
      _playbackMediaPath = widget.item.uri.toString();
      if (!mounted) {
        releasePlayableMediaUri(_playbackMediaPath!);
        _playbackMediaPath = null;
        return;
      }
      final controller = createVideoPlayerController(Uri.parse(playableUri));
      _controller = controller;
      controller.addListener(_onControllerChanged);
      await controller.initialize();
      if (mounted) {
        setState(() => _isInitializing = false);
        _scheduleControlsHide();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isInitializing = false;
        });
      }
      final mediaPath = _playbackMediaPath;
      if (mediaPath != null) {
        releasePlayableMediaUri(mediaPath);
        _playbackMediaPath = null;
      }
    }
  }

  void _onControllerChanged() {
    final error = _controller?.value.errorDescription;
    if (error == null || !mounted || _error == error) return;
    setState(() => _error = error);
  }

  @override
  void dispose() {
    _seekFeedbackTimer?.cancel();
    _controlsTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    final mediaPath = _playbackMediaPath;
    if (mediaPath != null) releasePlayableMediaUri(mediaPath);
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    final enterFullscreen = !_isFullscreen;
    try {
      await SystemChrome.setPreferredOrientations(
        enterFullscreen
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      );
      await SystemChrome.setEnabledSystemUIMode(
        enterFullscreen
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      );
      if (mounted) {
        setState(() {
          _isFullscreen = enterFullscreen;
          _showControls = true;
        });
        _scheduleControlsHide();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de changer l’affichage : $error')),
        );
      }
    }
  }

  Future<void> _onVideoDoubleTap() async {
    final isForward = _doubleTapX >= _videoWidth / 2;
    try {
      await _seekBy(Duration(seconds: isForward ? 10 : -10));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de déplacer la lecture : $error')),
        );
      }
      return;
    }
    _seekFeedbackTimer?.cancel();
    setState(() => _seekForwardFeedback = isForward);
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekForwardFeedback = null);
    });
    _scheduleControlsHide();
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final target = controller.value.position + offset;
    final duration = controller.value.duration;
    await controller.seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > duration
          ? duration
          : target,
    );
    _scheduleControlsHide();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleControlsHide();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (!_showControls || !(_controller?.value.isPlaying ?? false)) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
        _controlsTimer?.cancel();
        if (mounted) setState(() => _showControls = true);
      } else {
        await controller.play();
        _scheduleControlsHide();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de contrôler la lecture : $error'),
          ),
        );
      }
    }
  }

  Future<void> _setMuted(VideoPlayerController controller) async {
    final muted = !_muted;
    try {
      await controller.setVolume(muted ? 0 : 1);
      if (mounted) setState(() => _muted = muted);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de régler le son : $error')),
        );
      }
    }
  }

  Future<void> _setPlaybackSpeed(
    VideoPlayerController controller,
    double speed,
  ) async {
    try {
      await controller.setPlaybackSpeed(speed);
      if (mounted) setState(() => _speed = speed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de régler la vitesse : $error'),
          ),
        );
      }
    }
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _buildPlaybackControls(VideoPlayerController controller) {
    final value = controller.value;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xE6000000)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 38, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 7),
                colors: const VideoProgressColors(
                  playedColor: aqua,
                  bufferedColor: mutedInk,
                  backgroundColor: Color(0x66FFFFFF),
                ),
              ),
              Row(
                children: [
                  Text(
                    _formatTime(value.position),
                    style: const TextStyle(color: ink, fontSize: 11),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Reculer de 10 secondes',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _seekBy(const Duration(seconds: -10)),
                    color: ink,
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  IconButton.filled(
                    tooltip: value.isPlaying ? 'Pause' : 'Lire',
                    visualDensity: VisualDensity.compact,
                    onPressed: _togglePlayback,
                    style: IconButton.styleFrom(
                      backgroundColor: aqua,
                      foregroundColor: canvas,
                    ),
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Avancer de 10 secondes',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _seekBy(const Duration(seconds: 10)),
                    color: ink,
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                  IconButton(
                    tooltip: _muted ? 'Activer le son' : 'Couper le son',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _setMuted(controller),
                    color: ink,
                    icon: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Options de lecture',
                    onOpened: () => _controlsTimer?.cancel(),
                    onCanceled: _scheduleControlsHide,
                    onSelected: (value) {
                      if (value == 'fullscreen') {
                        _toggleFullscreen();
                      } else {
                        _setPlaybackSpeed(controller, double.parse(value));
                      }
                      _scheduleControlsHide();
                    },
                    itemBuilder: (context) => [
                      for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                        PopupMenuItem(
                          value: '$speed',
                          child: Text(
                            '$speed×${_speed == speed ? '  ✓' : ''}',
                          ),
                        ),
                      PopupMenuItem(
                        value: 'fullscreen',
                        child: Text(
                          _isFullscreen
                              ? 'Quitter le plein écran'
                              : 'Plein écran',
                        ),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$_speed×',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(value.duration),
                    style: const TextStyle(color: ink, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: canvas,
      appBar: _isFullscreen
          ? null
          : AppBar(
              elevation: 0,
              backgroundColor: surface,
              foregroundColor: ink,
              actions: [
                IconButton(
                  tooltip: 'Plein écran',
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
              title: Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: aqua,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lecture impossible\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ink),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _initialize,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : _isInitializing ||
                controller == null ||
                !controller.value.isInitialized
          ? const Center(child: CircularProgressIndicator(color: aqua))
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = controller.value.aspectRatio;
                  final aspectRatio = ratio.isFinite && ratio > 0
                      ? ratio
                      : 16 / 9;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: LayoutBuilder(
                          builder: (context, videoConstraints) {
                            _videoWidth = videoConstraints.maxWidth;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(
                                  color: Colors.black,
                                  child: VideoPlayer(controller),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _toggleControls,
                                  onDoubleTapDown: (details) {
                                    _doubleTapX = details.localPosition.dx;
                                  },
                                  onDoubleTap: _onVideoDoubleTap,
                                ),
                                if (controller.value.isBuffering)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: aqua,
                                    ),
                                  ),
                                if (_seekForwardFeedback != null)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _SeekFeedback(
                                              visible: !_seekForwardFeedback!,
                                              icon: Icons.replay_10_rounded,
                                              label: '-10 s',
                                            ),
                                          ),
                                          Expanded(
                                            child: _SeekFeedback(
                                              visible: _seekForwardFeedback!,
                                              icon: Icons.forward_10_rounded,
                                              label: '+10 s',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_showControls)
                                  _buildPlaybackControls(controller),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _SeekFeedback extends StatelessWidget {
  const _SeekFeedback({
    required this.visible,
    required this.icon,
    required this.label,
  });

  final bool visible;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0,
    duration: const Duration(milliseconds: 140),
    child: ColoredBox(
      color: Colors.black.withValues(alpha: 0.22),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ink, size: 44),
            Text(
              label,
              style: const TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
