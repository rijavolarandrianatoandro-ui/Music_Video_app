import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media/media_item.dart';
import 'media/app_settings.dart';
import 'media/media_library.dart';
import 'media/media_playlist.dart';
import 'media/media_downloader.dart';
import 'media/media_providers.dart';
import 'media/playback_controller.dart';
import 'screens/browser_screen.dart';
import 'screens/home_screen.dart';
import 'screens/link_import_screen.dart';
import 'screens/media_library_screen.dart';
import 'screens/playlist_library_screen.dart';
import 'screens/player_screens.dart';
import 'screens/settings_screen.dart';
import 'theme/maxei_theme.dart';
import 'widgets/liquid_surface.dart';
import 'widgets/media_artwork.dart';

class MaxeiApp extends StatelessWidget {
  const MaxeiApp({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: MaterialApp(
      title: 'Maxei · votre bibliothèque média',
      debugShowCheckedModeBanner: false,
      theme: buildMaxeiTheme(),
      home: const _MediaShell(),
    ),
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
  final _settings = AppSettings();
  final _searchController = TextEditingController();
  final _pageController = PageController();
  final List<MediaItem> _items = [];
  final List<MediaPlaylist> _playlists = [];
  final List<int> _tabHistory = [];
  MediaLibraryFilter _libraryFilter = MediaLibraryFilter.all;
  int _tab = 0;
  bool _searchOpen = false;
  bool _isImporting = false;
  bool _libraryReady = false;
  bool _browserInitialized = false;
  String _webSearchQuery = '';
  int _webSearchRequestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLibrary());
    unawaited(_restoreSettings());
  }

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
    setState(() {
      _tab = index;
      if (index == 3) _browserInitialized = true;
    });
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
    setState(() {
      _tab = index;
      if (index == 3) _browserInitialized = true;
    });
  }

  void _addDownloadedMedia(DownloadedMedia download) {
    final item = _library.itemFromDownloaded(download);
    if (item == null) {
      _showMessage('Ce fichier n’est pas dans un format pris en charge.');
      return;
    }
    if (_items.any((existing) => existing.id == item.id)) {
      _showMessage('Ce média est déjà dans votre bibliothèque.');
      return;
    }
    setState(() {
      _items.add(item);
      _items.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    });
    _persistLibraryInBackground();
    _showMessage('Téléchargement terminé, média ajouté à la bibliothèque.');
  }

  Future<void> _restoreLibrary() async {
    try {
      final saved = await _library.restore();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(saved.items);
        _playlists
          ..clear()
          ..addAll(saved.playlists);
      });
    } catch (error) {
      if (mounted) {
        _showMessage(
          'La bibliothèque locale n’a pas pu être restaurée : $error',
        );
      }
    } finally {
      if (mounted) setState(() => _libraryReady = true);
    }
  }

  Future<void> _restoreSettings() async {
    try {
      final saved = await AppSettings.load();
      _settings
        ..volume = saved.volume
        ..speed = saved.speed
        ..shuffle = saved.shuffle
        ..repeatMode = saved.repeatMode
        ..confirmDownloads = saved.confirmDownloads;
      _playback
        ..setShuffle(_settings.shuffle)
        ..setRepeatMode(_settings.repeatMode);
      await _playback.setVolume(_settings.volume);
      await _playback.setSpeed(_settings.speed);
    } catch (error) {
      if (mounted) {
        _showMessage('Les paramètres n’ont pas pu être restaurés : $error');
      }
    }
  }

  Future<void> _saveSettings() => _settings.save();

  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: _settings,
          playback: _playback,
          onChanged: _saveSettings,
        ),
      ),
    );
  }

  void _persistLibraryInBackground() {
    unawaited(_persistLibrary().then<void>((_) {}));
  }

  Future<bool> _persistLibrary() async {
    try {
      await _library.save(_items, _playlists);
      return true;
    } catch (error) {
      if (mounted) _showMessage('La sauvegarde locale a échoué : $error');
      return false;
    }
  }

  void _toggleFavorite(MediaItem item) {
    setState(() => item.isFavorite = !item.isFavorite);
    _persistLibraryInBackground();
  }

  void _onPlaylistsChanged() {
    setState(() {});
    _persistLibraryInBackground();
  }

  void _selectMediaFilter(MediaLibraryFilter filter) {
    setState(() => _libraryFilter = filter);
    _selectTab(1);
  }

  void _searchWeb() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchOpen = false;
      _searchController.clear();
      _webSearchQuery = query;
      _webSearchRequestId++;
    });
    _selectTab(3);
  }

  Future<void> _importMedia() async {
    if (_isImporting || !_libraryReady) return;
    setState(() => _isImporting = true);
    try {
      final persistentStorage = await _library
          .requestPersistentBrowserStorage();
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
      if (!await _persistLibrary()) return;
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
          : '${freshItems.length} média${freshItems.length == 1 ? '' : 's'} ajouté${freshItems.length == 1 ? '' : 's'} sur cet appareil.${persistentStorage ? '' : ' Edge ne garantit pas la conservation des données : évitez d’effacer les données du site.'}';
      _showMessage(message);
    } catch (error) {
      if (mounted) {
        _showMessage('Import impossible : $error');
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
      _persistLibraryInBackground();
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
      _persistLibraryInBackground();
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
        builder: (_) => NowPlayingScreen(
          playback: _playback,
          onMediaChanged: _persistLibraryInBackground,
        ),
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
                  onSubmitted: (_) => _searchWeb(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: ink, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Médias ou recherche Web',
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      tooltip: 'Rechercher sur le Web',
                      onPressed: _searchWeb,
                      icon: const Icon(Icons.public_rounded),
                    ),
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
                        color: canvas,
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
                  builder: (_) => Consumer(
                    builder: (context, ref, child) => LinkImportScreen(
                      downloadManager: ref.read(downloadManagerProvider),
                      onDownloaded: _addDownloadedMedia,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.link_rounded),
            ),
            IconButton(
              tooltip: 'Importer des fichiers audio ou vidéo',
              onPressed: _isImporting || !_libraryReady ? null : _importMedia,
              icon: _isImporting
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
            ),
            IconButton(
              tooltip: 'Paramètres',
              onPressed: _showSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: LiquidBackdrop(
          child: Column(
            children: [
              Expanded(
                child: !_libraryReady
                    ? const Center(child: CircularProgressIndicator())
                    : PageView(
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
                              item.kind == MediaKind.audio
                                  ? audioItems
                                  : videoItems,
                            ),
                            onFavorite: (item) => _toggleFavorite(item),
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
                              item.kind == MediaKind.audio
                                  ? audioItems
                                  : videoItems,
                            ),
                            onFavorite: (item) => _toggleFavorite(item),
                          ),
                          PlaylistLibraryScreen(
                            playlists: _playlists,
                            mediaItems: _items,
                            onChanged: _onPlaylistsChanged,
                            onPlay: _playPlaylist,
                          ),
                          if (_browserInitialized)
                            Consumer(
                              builder: (context, ref, child) => BrowserScreen(
                                searchQuery: _webSearchQuery,
                                searchRequestId: _webSearchRequestId,
                                onDownloaded: _addDownloadedMedia,
                                confirmDownloads: _settings.confirmDownloads,
                                downloadManager: ref.read(
                                  downloadManagerProvider,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
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
                      indicatorColor: aqua.withValues(alpha: 0.18),
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
                        NavigationDestination(
                          icon: Icon(Icons.travel_explore_outlined),
                          selectedIcon: Icon(Icons.travel_explore_rounded),
                          label: 'Explorer',
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
    radius: 22,
    tint: const Color(0xFF202629),
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
                style: IconButton.styleFrom(
                  backgroundColor: aqua,
                  foregroundColor: canvas,
                ),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
