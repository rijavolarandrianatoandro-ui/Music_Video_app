import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media/media_item.dart';
import 'media/media_search_index.dart';
import 'media/app_settings.dart';
import 'media/listening_recap.dart';
import 'media/listening_session.dart';
import 'media/media_library.dart';
import 'media/media_playlist.dart';
import 'media/media_downloader.dart';
import 'media/media_providers.dart';
import 'media/playback_controller.dart';
import 'screens/browser_screen.dart';
import 'screens/home_screen.dart';
import 'screens/link_import_screen.dart';
import 'screens/listening_recap_screen.dart';
import 'screens/media_library_screen.dart';
import 'screens/playlist_library_screen.dart';
import 'screens/player_screens.dart';
import 'screens/settings_screen.dart';
import 'theme/maxei_theme.dart';
import 'widgets/liquid_surface.dart';
import 'widgets/media_artwork.dart';

class MaxeiApp extends StatelessWidget {
  const MaxeiApp({super.key, this.startupWarning});

  final String? startupWarning;

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: MaterialApp(
      title: 'Maxei · votre bibliothèque média',
      debugShowCheckedModeBanner: false,
      theme: buildMaxeiTheme(),
      home: _MediaShell(startupWarning: startupWarning),
    ),
  );
}

class _MediaShell extends StatefulWidget {
  const _MediaShell({this.startupWarning});

  final String? startupWarning;

  @override
  State<_MediaShell> createState() => _MediaShellState();
}

class _MediaShellState extends State<_MediaShell> {
  final _library = MediaLibrary();
  final _searchIndex = MediaSearchIndex();
  late final PlaybackController _playback;
  final _settings = AppSettings();
  final _searchController = TextEditingController();
  final _pageController = PageController();
  final List<MediaItem> _items = [];
  final List<MediaPlaylist> _playlists = [];
  final List<ListeningSession> _listeningHistory = [];
  final List<int> _tabHistory = [];
  MediaLibraryFilter _libraryFilter = MediaLibraryFilter.all;
  int _tab = 0;
  bool _searchOpen = false;
  bool _isImporting = false;
  bool _isScanningDeviceAudio = false;
  bool _deviceAudioPermissionDenied = false;
  bool _showStartupWarning = true;
  bool _libraryReady = false;
  bool _settingsReady = false;
  bool _recapPromptScheduled = false;
  bool _browserInitialized = false;
  String _webSearchQuery = '';
  int _webSearchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _playback = PlaybackController(
      onListeningSessionChanged: _recordListeningSession,
    );
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
    unawaited(_rebuildSearchIndex());
    _persistLibraryInBackground();
    _showMessage('Téléchargement terminé, média ajouté à la bibliothèque.');
  }

  Future<void> _restoreLibrary() async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    try {
      final saved = await _library.restore(
        preserveUnverifiedDeviceAudio: isAndroid,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(saved.items)
          ..sort(_compareMedia);
        _playlists
          ..clear()
          ..addAll(saved.playlists);
        _listeningHistory
          ..clear()
          ..addAll(saved.listeningHistory);
      });
      unawaited(_rebuildSearchIndex());
      _maybeShowMonthlyRecap();
      if (isAndroid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_scanDeviceAudio(showResult: false));
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _deviceAudioPermissionDenied = isAndroid;
        });
        _showMessage(
          'La bibliothèque locale n’a pas pu être restaurée : $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _libraryReady = true);
        _maybeShowMonthlyRecap();
      }
    }
  }

  MediaItem _restoreDeviceAudioState(MediaItem scanned, MediaItem? saved) {
    if (saved == null) return scanned;
    return scanned
      ..isFavorite = saved.isFavorite
      ..playCount = saved.playCount
      ..lastPlayedAt = saved.lastPlayedAt;
  }

  bool get _canScanDeviceAudio =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  int _compareMedia(MediaItem a, MediaItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  Future<void> _rebuildSearchIndex() async {
    try {
      await _searchIndex.rebuildInBackground(_items);
    } catch (error) {
      if (mounted) {
        _showMessage('L’index de recherche n’a pas pu être construit : $error');
      }
    }
  }

  Future<void> _scanDeviceAudio({bool showResult = true}) async {
    if (_isScanningDeviceAudio ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    setState(() => _isScanningDeviceAudio = true);
    try {
      final result = await _library.scanDeviceAudio();
      if (!mounted) return;
      if (!result.permissionGranted) {
        setState(() => _deviceAudioPermissionDenied = true);
        _showPermissionMessage();
        return;
      }

      final existingById = {for (final item in _items) item.id: item};
      final scannedItems = [
        for (final item in result.items)
          _restoreDeviceAudioState(item, existingById[item.id]),
      ];
      final localItems = _items
          .where((item) => item.uri.scheme != 'content')
          .toList();
      setState(() {
        _items
          ..clear()
          ..addAll([...scannedItems, ...localItems])
          ..sort(_compareMedia);
        _deviceAudioPermissionDenied = false;
      });
      unawaited(_rebuildSearchIndex());
      final saved = await _persistLibrary();
      if (showResult && saved) {
        _showMessage(
          '${result.items.length} morceau(s) trouvés sur l’appareil.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('Le scan des musiques a échoué : $error');
    } finally {
      if (mounted) setState(() => _isScanningDeviceAudio = false);
    }
  }

  void _showPermissionMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Autorisez l’accès à Musique et audio pour analyser vos morceaux.',
          ),
          action: SnackBarAction(
            label: 'Paramètres',
            onPressed: _library.openDeviceAudioSettings,
          ),
        ),
      );
  }

  Future<void> _restoreSettings() async {
    try {
      final saved = await AppSettings.load();
      _settings
        ..volume = saved.volume
        ..speed = saved.speed
        ..shuffle = saved.shuffle
        ..repeatMode = saved.repeatMode
        ..confirmDownloads = saved.confirmDownloads
        ..dismissedRecapMonth = saved.dismissedRecapMonth;
      _playback
        ..setShuffle(_settings.shuffle)
        ..setRepeatMode(_settings.repeatMode);
      _settingsReady = true;
      _maybeShowMonthlyRecap();
      await _playback.setVolume(_settings.volume);
      await _playback.setSpeed(_settings.speed);
    } catch (error) {
      _settingsReady = true;
      _maybeShowMonthlyRecap();
      if (mounted) {
        _showMessage('Les paramètres n’ont pas pu être restaurés : $error');
      }
    }
  }

  Future<void> _saveSettings() => _settings.save();

  void _recordListeningSession(ListeningSession session) {
    final existingIndex = _listeningHistory.indexWhere(
      (entry) => entry.id == session.id,
    );
    if (existingIndex < 0) {
      _listeningHistory.add(session);
    } else {
      _listeningHistory[existingIndex] = session;
    }
    if (_listeningHistory.length > 5000) {
      _listeningHistory.removeRange(0, _listeningHistory.length - 5000);
    }
    _persistLibraryInBackground();
  }

  String _recapMonthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  ListeningRecap _monthlyRecap() =>
      ListeningRecap.forPreviousMonth(_listeningHistory, _items);

  void _maybeShowMonthlyRecap() {
    if (!mounted ||
        !_libraryReady ||
        !_settingsReady ||
        _recapPromptScheduled) {
      return;
    }
    final recap = _monthlyRecap();
    if (recap.sessions.isEmpty) return;
    final monthKey = _recapMonthKey(recap.start);
    if (_settings.dismissedRecapMonth == monthKey) return;

    _recapPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _recapPromptScheduled = false;
        return;
      }
      unawaited(_showMonthlyRecapPrompt(recap, monthKey));
    });
  }

  Future<void> _showMonthlyRecapPrompt(
    ListeningRecap recap,
    String monthKey,
  ) async {
    bool? showRecap;
    try {
      showRecap = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: surface,
          icon: const Icon(Icons.auto_awesome_rounded, color: aqua, size: 30),
          title: const Text('Votre mois en musique est prêt'),
          content: Text(
            '${ListeningRecapScreen.formatDuration(recap.totalMilliseconds)} '
            'd’écoute, ${recap.uniqueTracks} titres et '
            '${recap.sessions.length} lectures. Découvrez vos favoris du mois.',
            style: const TextStyle(color: mutedInk, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Passer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Voir le récap'),
            ),
          ],
        ),
      );
    } finally {
      _recapPromptScheduled = false;
    }
    if (!mounted) return;
    await _dismissMonthlyRecap(monthKey);
    if (showRecap == true && mounted) _openListeningRecap(recap);
  }

  Future<void> _dismissMonthlyRecap(String monthKey) async {
    _settings.dismissedRecapMonth = monthKey;
    try {
      await _saveSettings();
    } catch (error) {
      if (mounted) {
        _showMessage('Le rappel du récap n’a pas pu être enregistré : $error');
      }
    }
  }

  void _openListeningRecap([ListeningRecap? recap]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListeningRecapScreen(recap: recap ?? _monthlyRecap()),
      ),
    );
  }

  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: _settings,
          playback: _playback,
          onChanged: _saveSettings,
          onOpenRecap: _openListeningRecap,
          listeningSessionCount: _listeningHistory.length,
        ),
      ),
    );
  }

  void _persistLibraryInBackground() {
    unawaited(_persistLibrary().then<void>((_) {}));
  }

  Future<bool> _persistLibrary() async {
    try {
      await _library.save(
        _items,
        _playlists,
        listeningHistory: _listeningHistory,
      );
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
      await _rebuildSearchIndex();
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
    if (item.uri.scheme == 'content' && _deviceAudioPermissionDenied) {
      _showPermissionMessage();
      return;
    }
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
    final searchResults = query.isEmpty ? _items : _searchIndex.search(query);
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
              if (widget.startupWarning != null && _showStartupWarning)
                MaterialBanner(
                  backgroundColor: surface,
                  content: Text(
                    widget.startupWarning!,
                    style: const TextStyle(color: ink, fontSize: 12),
                  ),
                  leading: const Icon(Icons.warning_amber_rounded, color: aqua),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _showStartupWarning = false),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              Expanded(
                child: !_libraryReady
                    ? const Center(child: CircularProgressIndicator())
                    : PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        children: [
                          HomeScreen(
                            items: searchResults,
                            playlists: _playlists,
                            query: query,
                            deviceAudioPermissionDenied:
                                _deviceAudioPermissionDenied,
                            isScanningDeviceAudio: _isScanningDeviceAudio,
                            onImport: _importMedia,
                            onScanDeviceAudio: _canScanDeviceAudio
                                ? _scanDeviceAudio
                                : null,
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
                            items: searchResults,
                            query: query,
                            filter: _libraryFilter,
                            onFilterChanged: (filter) =>
                                setState(() => _libraryFilter = filter),
                            onImport: _importMedia,
                            onScanDeviceAudio: _canScanDeviceAudio
                                ? _scanDeviceAudio
                                : null,
                            isScanningDeviceAudio: _isScanningDeviceAudio,
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
