import 'dart:ui';

import 'package:flutter/material.dart';

import 'media/media_item.dart';
import 'media/media_library.dart';
import 'media/media_playlist.dart';
import 'media/playback_controller.dart';
import 'screens/home_screen.dart';
import 'screens/link_import_screen.dart';
import 'screens/media_library_screen.dart';
import 'screens/playlist_library_screen.dart';
import 'screens/player_screens.dart';
import 'theme/maxei_theme.dart';
import 'widgets/liquid_surface.dart';
import 'widgets/media_artwork.dart';

class MaxeiApp extends StatelessWidget {
  const MaxeiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Maxei · votre bibliothèque média',
    debugShowCheckedModeBanner: false,
    theme: buildMaxeiTheme(),
    home: const _MediaShell(),
  );
}

class _MediaShell extends StatefulWidget {
  const _MediaShell();

  @override
  State<_MediaShell> createState() => _MediaShellState();
}

class _MediaShellState extends State<_MediaShell> {
  final _library = MediaLibrary();
  final _playback = PlaybackController();
  final _searchController = TextEditingController();
  final _pageController = PageController();
  final List<MediaItem> _items = [];
  final List<MediaPlaylist> _playlists = [];
  final List<int> _tabHistory = [];
  MediaLibraryFilter _libraryFilter = MediaLibraryFilter.all;
  int _tab = 0;
  bool _searchOpen = false;
  bool _isImporting = false;

  @override
  void dispose() {
    _playback.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index, {bool rememberCurrent = true}) {
    if (index == _tab) return;
    if (rememberCurrent) {
      _tabHistory.add(_tab);
      if (_tabHistory.length > 32) _tabHistory.removeAt(0);
    }
    setState(() => _tab = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleSystemBack(bool didPop) {
    if (didPop) return;
    if (_tabHistory.isNotEmpty) {
      _selectTab(_tabHistory.removeLast(), rememberCurrent: false);
    } else if (_tab != 0) {
      _selectTab(0, rememberCurrent: false);
    }
  }

  void _onPageChanged(int index) {
    if (index == _tab) return;
    _tabHistory.add(_tab);
    if (_tabHistory.length > 32) _tabHistory.removeAt(0);
    setState(() => _tab = index);
  }

  void _selectMediaFilter(MediaLibraryFilter filter) {
    setState(() => _libraryFilter = filter);
    _selectTab(1);
  }

  Future<void> _importMedia() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final imported = await _library.importFiles();
      if (!mounted || imported.isEmpty) {
        return;
      }
      final knownIds = _items.map((item) => item.id).toSet();
      final freshItems = imported
          .where((item) => knownIds.add(item.id))
          .toList();
      setState(() {
        _items.addAll(freshItems);
        _items.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        _searchOpen = false;
        _searchController.clear();
      });
      if (freshItems.isNotEmpty) {
        _selectMediaFilter(
          freshItems.every((item) => item.kind == MediaKind.audio)
              ? MediaLibraryFilter.audio
              : freshItems.every((item) => item.kind == MediaKind.video)
              ? MediaLibraryFilter.video
              : MediaLibraryFilter.all,
        );
      }
      final message = freshItems.isEmpty
          ? 'Ces fichiers sont déjà dans votre bibliothèque.'
          : '${freshItems.length} média${freshItems.length == 1 ? '' : 's'} ajouté${freshItems.length == 1 ? '' : 's'} sur cet appareil.';
      _showMessage(message);
    } catch (_) {
      if (mounted) {
        _showMessage('Import impossible. Vérifiez le format et réessayez.');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _playAudio(
    MediaItem item,
    List<MediaItem> queue, {
    bool openPlayer = true,
  }) async {
    try {
      await _playback.playQueue(queue, queue.indexOf(item));
      if (mounted && openPlayer) {
        _showPlayer();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Ce fichier audio ne peut pas être lu sur cet appareil.');
      }
    }
  }

  void _openMedia(MediaItem item, List<MediaItem> queue) {
    if (item.kind == MediaKind.video) {
      item.playCount++;
      item.lastPlayedAt = DateTime.now();
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => VideoPlayerScreen(item: item)),
      );
    } else {
      _playAudio(item, queue);
    }
  }

  void _showPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NowPlayingScreen(playback: _playback),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _playPlaylist(List<MediaItem> tracks) {
    if (tracks.isEmpty) return;
    final kind = tracks.first.kind;
    final compatibleTracks = tracks.where((item) => item.kind == kind).toList();
    if (kind == MediaKind.audio) {
      _playAudio(compatibleTracks.first, compatibleTracks);
    } else {
      _openMedia(compatibleTracks.first, compatibleTracks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioItems = _items
        .where((item) => item.kind == MediaKind.audio)
        .toList();
    final videoItems = _items
        .where((item) => item.kind == MediaKind.video)
        .toList();
    final query = _searchController.text.trim().toLowerCase();
    return PopScope<Object?>(
      canPop: _tab == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) => _handleSystemBack(didPop),
      child: Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          titleSpacing: 20,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: ColoredBox(color: canvas.withValues(alpha: 0.54)),
            ),
          ),
          title: _searchOpen
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: ink, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher dans vos médias',
                    border: InputBorder.none,
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        color: aqua,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.equalizer_rounded,
                        size: 20,
                        color: ink,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'maxei',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
          actions: [
            IconButton(
              tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher',
              onPressed: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _searchController.clear();
              }),
              icon: Icon(
                _searchOpen ? Icons.close_rounded : Icons.search_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Analyser un lien média',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LinkImportScreen(),
                ),
              ),
              icon: const Icon(Icons.link_rounded),
            ),
            IconButton(
              tooltip: 'Importer des fichiers audio ou vidéo',
              onPressed: _isImporting ? null : _importMedia,
              icon: _isImporting
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: LiquidBackdrop(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    HomeScreen(
                      items: _items,
                      playlists: _playlists,
                      query: query,
                      onImport: _importMedia,
                      onOpen: (item) => _openMedia(
                        item,
                        item.kind == MediaKind.audio ? audioItems : videoItems,
                      ),
                      onFavorite: (item) =>
                          setState(() => item.isFavorite = !item.isFavorite),
                      onSelectMediaFilter: _selectMediaFilter,
                      onOpenPlaylists: () => _selectTab(2),
                    ),
                    MediaLibraryScreen(
                      title: 'Votre bibliothèque',
                      items: _items,
                      query: query,
                      filter: _libraryFilter,
                      onFilterChanged: (filter) =>
                          setState(() => _libraryFilter = filter),
                      onImport: _importMedia,
                      onOpen: (item) => _openMedia(
                        item,
                        item.kind == MediaKind.audio ? audioItems : videoItems,
                      ),
                      onFavorite: (item) =>
                          setState(() => item.isFavorite = !item.isFavorite),
                    ),
                    PlaylistLibraryScreen(
                      playlists: _playlists,
                      mediaItems: _items,
                      onChanged: () => setState(() {}),
                      onPlay: _playPlaylist,
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _playback,
                builder: (context, _) => _playback.current == null
                    ? const SizedBox.shrink()
                    : _MiniPlayer(
                        item: _playback.current!,
                        isPlaying: _playback.isPlaying,
                        onOpen: _showPlayer,
                        onToggle: _playback.toggle,
                        onNext: _playback.next,
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
                  child: LiquidGlass(
                    radius: 25,
                    child: NavigationBar(
                      selectedIndex: _tab,
                      onDestinationSelected: _selectTab,
                      backgroundColor: Colors.transparent,
                      indicatorColor: aqua.withValues(alpha: 0.55),
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Accueil',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.library_music_outlined),
                          selectedIcon: Icon(Icons.library_music_rounded),
                          label: 'Bibliothèque',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.queue_music_outlined),
                          selectedIcon: Icon(Icons.queue_music_rounded),
                          label: 'Playlists',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.item,
    required this.isPlaying,
    required this.onOpen,
    required this.onToggle,
    required this.onNext,
  });

  final MediaItem item;
  final bool isPlaying;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    radius: 14,
    tint: aqua.withValues(alpha: 0.72),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Row(
            children: [
              MediaArtwork(title: item.title, size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ink, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isPlaying ? 'Pause' : 'Reprendre',
                onPressed: onToggle,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: ink,
                ),
              ),
              IconButton(
                tooltip: 'Suivant',
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded, color: ink),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
