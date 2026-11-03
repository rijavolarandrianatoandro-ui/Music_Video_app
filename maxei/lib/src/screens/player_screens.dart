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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: playback.shuffleEnabled
                                    ? 'Aléatoire activé'
                                    : 'Lecture aléatoire',
                                onPressed: playback.toggleShuffle,
                                color: playback.shuffleEnabled
                                    ? ink
                                    : ink.withValues(alpha: 0.55),
                                icon: const Icon(Icons.shuffle_rounded),
                              ),
                              IconButton(
                                tooltip: 'Précédent',
                                onPressed: playback.previous,
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  size: 30,
                                ),
                              ),
                              SizedBox.square(
                                dimension: 68,
                                child: FilledButton(
                                  onPressed: playback.isLoading
                                      ? null
                                      : playback.toggle,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: aqua,
                                    foregroundColor: canvas,
                                    shape: const CircleBorder(),
                                  ),
                                  child: playback.isLoading
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: canvas,
                                          ),
                                        )
                                      : Icon(
                                          playback.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 34,
                                        ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Suivant',
                                onPressed: playback.next,
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                tooltip: switch (playback.repeatMode) {
                                  PlaybackRepeatMode.off =>
                                    'Répétition désactivée',
                                  PlaybackRepeatMode.all => 'Répéter la file',
                                  PlaybackRepeatMode.one => 'Répéter le titre',
                                },
                                onPressed: playback.cycleRepeatMode,
                                color:
                                    playback.repeatMode ==
                                        PlaybackRepeatMode.off
                                    ? ink.withValues(alpha: 0.55)
                                    : ink,
                                icon: Icon(
                                  playback.repeatMode == PlaybackRepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                ),
                              ),
                            ],
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
          subtitle: const Text(
            'Paroles intégrées au fichier audio',
            style: TextStyle(color: mutedInk, fontSize: 11),
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
                    'Aucune parole intégrée trouvée. Maxei ne récupère pas les paroles sur des services tiers.',
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
  bool _landscape = false;
  double _doubleTapX = 0;
  double _videoWidth = 1;
  bool? _seekForwardFeedback;
  Timer? _seekFeedbackTimer;

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
    try {
      final playableUri = await resolvePlayableMediaUri(
        widget.item.uri.toString(),
        extension: widget.item.extension,
      );
      _playbackMediaPath = widget.item.uri.toString();
      if (!mounted) {
        releasePlayableMediaUri(_playbackMediaPath!);
        return;
      }
      final controller = createVideoPlayerController(Uri.parse(playableUri));
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error);
      final mediaPath = _playbackMediaPath;
      if (mediaPath != null) {
        releasePlayableMediaUri(mediaPath);
        _playbackMediaPath = null;
      }
    }
  }

  @override
  void dispose() {
    _seekFeedbackTimer?.cancel();
    _controller?.dispose();
    final mediaPath = _playbackMediaPath;
    if (mediaPath != null) releasePlayableMediaUri(mediaPath);
    unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  Future<void> _toggleLandscape() async {
    final orientations = _landscape
        ? const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
    await SystemChrome.setPreferredOrientations(orientations);
    if (mounted) setState(() => _landscape = !_landscape);
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
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.value.position + offset;
    final duration = controller.value.duration;
    await controller.seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > duration
          ? duration
          : target,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: ink,
        actions: [
          IconButton(
            tooltip: _landscape ? 'Rotation automatique' : 'Mode paysage',
            onPressed: _toggleLandscape,
            icon: const Icon(Icons.screen_rotation_rounded),
          ),
        ],
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _error != null
            ? Text(
                'Lecture de la vidéo impossible : $_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: ink),
              )
            : controller == null || !controller.value.isInitialized
            ? const CircularProgressIndicator(color: aqua)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = controller.value.aspectRatio;
                  final aspectRatio = ratio.isFinite && ratio > 0
                      ? ratio
                      : 16 / 9;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          maxHeight: constraints.maxHeight * 0.65,
                        ),
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: LayoutBuilder(
                            builder: (context, videoConstraints) {
                              _videoWidth = videoConstraints.maxWidth;
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoPlayer(controller),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onDoubleTapDown: (details) {
                                      _doubleTapX = details.localPosition.dx;
                                    },
                                    onDoubleTap: _onVideoDoubleTap,
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
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: aqua,
                          bufferedColor: mutedInk,
                          backgroundColor: surface,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  _seekBy(const Duration(seconds: -10)),
                              color: ink,
                              icon: const Icon(Icons.replay_10_rounded),
                            ),
                            IconButton.filled(
                              onPressed: () => setState(
                                () => controller.value.isPlaying
                                    ? controller.pause()
                                    : controller.play(),
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: aqua,
                                foregroundColor: canvas,
                              ),
                              icon: Icon(
                                controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _seekBy(const Duration(seconds: 10)),
                              color: ink,
                              icon: const Icon(Icons.forward_10_rounded),
                            ),
                            IconButton(
                              tooltip: _muted
                                  ? 'Activer le son'
                                  : 'Couper le son',
                              onPressed: () => setState(() {
                                _muted = !_muted;
                                controller.setVolume(_muted ? 0 : 1);
                              }),
                              color: ink,
                              icon: Icon(
                                _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                              ),
                            ),
                            PopupMenuButton<double>(
                              tooltip: 'Vitesse de lecture',
                              initialValue: _speed,
                              onSelected: (value) => setState(() {
                                _speed = value;
                                controller.setPlaybackSpeed(value);
                              }),
                              itemBuilder: (context) => [
                                for (final value in [
                                  0.5,
                                  0.75,
                                  1.0,
                                  1.25,
                                  1.5,
                                  2.0,
                                ])
                                  PopupMenuItem(
                                    value: value,
                                    child: Text('$value×'),
                                  ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Text(
                                  '$_speed×',
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
