import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../media/media_item.dart';
import '../media/music_discovery_catalog.dart';
import '../media/regional_trending.dart';
import '../media/youtube_catalog_service.dart';
import '../media/youtube_video.dart';
import '../theme/maxei_theme.dart';
import 'liquid_surface.dart';
import 'media_artwork.dart';

class RegionalTrendsSection extends StatefulWidget {
  const RegionalTrendsSection({
    super.key,
    required this.enabled,
    required this.countryCode,
    required this.preferredArtistIds,
    required this.library,
  });

  final bool enabled;
  final String? countryCode;
  final List<String> preferredArtistIds;
  final List<MediaItem> library;

  @override
  State<RegionalTrendsSection> createState() => _RegionalTrendsSectionState();
}

class _RegionalTrendsSectionState extends State<RegionalTrendsSection> {
  final _service = YoutubeCatalogService();
  final _connectivity = Connectivity();
  List<YoutubeVideo> _videos = const [];
  List<RegionalTrend> _trends = const [];
  String? _error;
  bool _loading = false;
  int _requestId = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          _loadIfEnabled();
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => _error = 'Connexion réseau indisponible : $error');
        }
      },
    );
    _loadIfEnabled();
  }

  @override
  void didUpdateWidget(covariant RegionalTrendsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.countryCode != widget.countryCode) {
      _loadIfEnabled();
    } else if (oldWidget.preferredArtistIds.join(',') !=
            widget.preferredArtistIds.join(',') ||
        _librarySignature(oldWidget.library) !=
            _librarySignature(widget.library)) {
      _rankCurrentVideos();
    }
  }

  List<RegionalTrend> _rank(List<YoutubeVideo> videos) => rankRegionalTrends(
    videos,
    library: widget.library,
    preferredArtistIds: widget.preferredArtistIds,
  );

  void _rankCurrentVideos() {
    if (_videos.isEmpty) return;
    setState(() => _trends = _rank(_videos));
  }

  String _librarySignature(List<MediaItem> items) => items
      .where((item) => item.kind == MediaKind.audio)
      .map((item) => '${item.artist}:${item.playCount}:${item.isFavorite}')
      .join('|');

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadIfEnabled() async {
    final requestId = ++_requestId;
    final countryCode = widget.countryCode;
    if (!widget.enabled || regionByCode(countryCode) == null) {
      setState(() {
        _trends = const [];
        _videos = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connectivity = await _connectivity.checkConnectivity();
      if (!connectivity.any((result) => result != ConnectivityResult.none)) {
        if (mounted && requestId == _requestId) {
          setState(() {
            _error = 'En attente d’une connexion internet.';
            _loading = false;
          });
        }
        return;
      }
      final videos = await _service.loadRegionalTrends(countryCode!);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _videos = videos;
        _trends = _rank(videos);
      });
    } on Object catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || regionByCode(widget.countryCode) == null) {
      return const SizedBox.shrink();
    }
    final region = regionByCode(widget.countryCode)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: _Heading(title: 'Tendances musicales')),
            Text(
              region.name,
              style: TextStyle(color: mutedInk, fontSize: 11),
            ),
            if (!_loading)
              IconButton(
                tooltip: 'Actualiser les tendances',
                onPressed: _loadIfEnabled,
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.smart_display_rounded, color: aqua, size: 16),
              const SizedBox(width: 5),
              Text(
                'Données et vidéos fournies par YouTube',
                style: TextStyle(
                  color: mutedInk.withValues(alpha: 0.9),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (_loading && _trends.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          LiquidGlass(
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: aqua),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tendances indisponibles : $_error',
                      style: TextStyle(color: mutedInk, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Réessayer',
                    onPressed: _loadIfEnabled,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          )
        else if (_trends.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucune tendance disponible pour ce pays.',
              style: TextStyle(color: mutedInk),
            ),
          )
        else
          for (final trend in _trends.take(8))
            _TrendRow(
              trend: trend,
              onTap: () => _openYoutube(trend.video.youtubeUri),
            ),
      ],
    );
  }

  Future<void> _openYoutube(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Impossible d’ouvrir YouTube.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend, required this.onTap});

  final RegionalTrend trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Material(
      color: surface.withValues(alpha: 0.9),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: ink.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: _TrendThumbnail(video: trend.video),
        title: Text(
          trend.video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          trend.video.channelTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: mutedInk, fontSize: 11),
        ),
        trailing: Icon(Icons.open_in_new_rounded, color: aqua, size: 18),
      ),
    ),
  );
}

class _TrendThumbnail extends StatelessWidget {
  const _TrendThumbnail({required this.video});

  final YoutubeVideo video;

  @override
  Widget build(BuildContext context) {
    final thumbnail = video.thumbnailUrl;
    if (thumbnail == null) {
      return MediaArtwork(title: video.title, size: 64);
    }
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        thumbnail.toString(),
        width: 88,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            MediaArtwork(title: video.title, size: 58),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      color: ink,
      fontSize: 17,
      fontWeight: FontWeight.w800,
    ),
  );
}
