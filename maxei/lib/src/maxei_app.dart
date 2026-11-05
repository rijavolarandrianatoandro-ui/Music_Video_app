import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'media/media_item.dart';
import 'media/media_search_index.dart';
import 'media/app_settings.dart';
import 'media/youtube_catalog_service.dart';
import 'media/listening_recap.dart';
import 'media/listening_session.dart';
import 'media/media_library.dart';
import 'media/media_playlist.dart';
import 'media/media_downloader.dart';
import 'media/media_providers.dart';
import 'media/playback_controller.dart';
import 'screens/browser_screen.dart';
import 'screens/artist_selection_dialog.dart';
import 'screens/home_screen.dart';
import 'screens/link_import_screen.dart';
import 'screens/listening_recap_screen.dart';
import 'screens/media_library_screen.dart';
import 'screens/playlist_library_screen.dart';
import 'screens/player_screens.dart';
import 'screens/settings_screen.dart';
import 'screens/youtube_search_screen.dart';
import 'theme/maxei_theme.dart';
import 'widgets/liquid_surface.dart';
import 'widgets/media_artwork.dart';

class MaxeiApp extends StatefulWidget {
  const MaxeiApp({super.key, this.startupWarning});

  final String? startupWarning;

  @override
  State<MaxeiApp> createState() => _MaxeiAppState();
}

class _MaxeiAppState extends State<MaxeiApp> {
  AppThemeMode _themeMode = AppThemeMode.dark;

  @override
  void initState() {
    super.initState();
    MaxeiPalette.setMode(_themeMode);
  }

  void _setThemeMode(AppThemeMode mode) {
    MaxeiPalette.setMode(mode);
    if (_themeMode != mode) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: MaterialApp(
      title: 'Maxei · votre bibliothèque média',
      debugShowCheckedModeBanner: false,
      theme: buildMaxeiTheme(isDark: false),
      darkTheme: buildMaxeiTheme(isDark: true),
      themeMode: _themeMode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: _MediaShell(
        startupWarning: widget.startupWarning,
        onThemeModeChanged: _setThemeMode,
      ),
    ),
  );
}

class _MediaShell extends StatefulWidget {
  const _MediaShell({this.startupWarning, required this.onThemeModeChanged});

  final String? startupWarning;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  @override
  State<_MediaShell> createState() => _MediaShellState();
}

class _MediaShellState extends State<_MediaShell> with WidgetsBindingObserver {
  final _library = MediaLibrary();
  final _searchIndex = MediaSearchIndex();
  late final PlaybackController _playback;
  final _settings = AppSettings();
  final _connectivity = Connectivity();
  final _searchController = TextEditingController();
  final _pageController = PageController();
  final List<MediaItem> _items = [];
  final List<MediaPlaylist> _playlists = [];
  final List<ListeningSession> _listeningHistory = [];
  final List<int> _tabHistory = [];
  MediaLibraryFilter _libraryFilter = MediaLibraryFilter.audio;
  MediaSortOrder _mediaSortOrder = MediaSortOrder.name;
  int _tab = 0;
  bool _searchOpen = false;
  bool _isImporting = false;
  bool _isScanningDeviceMedia = false;
  bool _deviceAudioPermissionGranted = false;
  bool _deviceVideoPermissionGranted = false;
  bool _deviceMediaPermissionDenied = false;
  bool _showStartupWarning = true;
  bool _libraryReady = false;
  bool _settingsReady = false;
  bool _recapPromptScheduled = false;
  bool _browserInitialized = false;
  String _webSearchQuery = '';
  int _webSearchRequestId = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _artistSetupPromptVisible = false;
  bool _workerAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
      onError: (Object error) {
        if (mounted) {
          _showMessage('État de la connexion indisponible : $error');
        }
      },
    );
    unawaited(_checkNetworkForArtistSetup());
    _playback = PlaybackController(
      onListeningSessionChanged: _recordListeningSession,
    );
    unawaited(_restoreLibrary());
    unawaited(_restoreSettings());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    _playback.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkNetworkForArtistSetup());
    }
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      unawaited(_checkNetworkForArtistSetup());
    } else {
      _workerAvailable = false;
    }
  }

  Future<void> _checkNetworkForArtistSetup() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (!results.any((result) => result != ConnectivityResult.none)) {
        _workerAvailable = false;
        return;
      }
      final service = YoutubeCatalogService();
      try {
        _workerAvailable = await service.isAvailable();
        if (_workerAvailable) unawaited(_maybeShowArtistSetup());
      } finally {
        service.dispose();
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Impossible de vérifier la connexion réseau : $error');
      }
    }
  }

  Future<void> _maybeShowArtistSetup() async {
    if (!mounted ||
        !_libraryReady ||
        !_settingsReady ||
        !_workerAvailable ||
        _artistSetupPromptVisible ||
        _settings.artistSetupCompleted ||
        _recapPromptScheduled) {
      return;
    }
    _artistSetupPromptVisible = true;
    try {
      final selection = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ArtistSelectionDialog(
          initialSelection: _settings.preferredArtistIds,
        ),
      );
      if (!mounted || selection == null) return;
      if (selection.length == 5) {
        _settings.preferredArtistIds = selection;
      }
      _settings.artistSetupCompleted = true;
      await _saveSettings();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Les préférences musicales n’ont pas été enregistrées : $error',
        );
      }
    } finally {
      _artistSetupPromptVisible = false;
      if (mounted) _maybeShowMonthlyRecap();
    }
  }

  Future<void> _editPreferredArtists() async {
    final selection = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          ArtistSelectionDialog(initialSelection: _settings.preferredArtistIds),
    );
    if (!mounted || selection == null || selection.length != 5) return;
    _settings
      ..preferredArtistIds = selection
      ..artistSetupCompleted = true;
    try {
      await _saveSettings();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Les artistes préférés n’ont pas été enregistrés : $error',
        );
      }
    }
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
          if (mounted) unawaited(_scanDeviceMedia(showResult: false));
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _deviceMediaPermissionDenied = isAndroid;
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

  MediaItem _restoreDeviceMediaState(MediaItem scanned, MediaItem? saved) {
    if (saved == null) return scanned;
    return scanned
      ..isFavorite = saved.isFavorite
      ..playCount = saved.playCount
      ..lastPlayedAt = saved.lastPlayedAt;
  }

  bool get _canScanDeviceMedia =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  int _compareMedia(MediaItem a, MediaItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  List<MediaItem> get _visibleItems =>
      _items.where((item) => !item.isShortAudio).toList(growable: false);

  List<MediaItem> get _hiddenShortAudioItems =>
      _items.where((item) => item.isShortAudio).toList(growable: false);

  Future<void> _rebuildSearchIndex() async {
    try {
      await _searchIndex.rebuildInBackground(_visibleItems);
    } catch (error) {
      if (mounted) {
        _showMessage('L’index de recherche n’a pas pu être construit : $error');
      }
    }
  }

  Future<void> _scanDeviceMedia({bool showResult = true}) async {
    if (_isScanningDeviceMedia ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    setState(() => _isScanningDeviceMedia = true);
    try {
      final result = await _library.scanDeviceMedia();
      if (!mounted) return;
      if (!result.audioPermissionGranted && !result.videoPermissionGranted) {
        setState(() {
          _deviceAudioPermissionGranted = false;
          _deviceVideoPermissionGranted = false;
          _deviceMediaPermissionDenied = true;
        });
        _showPermissionMessage();
        return;
      }

      final existingById = {for (final item in _items) item.id: item};
      final scannedItems = [
        for (final item in result.items)
          if ((item.kind == MediaKind.audio && result.audioPermissionGranted) ||
              (item.kind == MediaKind.video && result.videoPermissionGranted))
            _restoreDeviceMediaState(item, existingById[item.id]),
      ];
      final unscannedDeviceItems = _items
          .where((item) {
            if (item.uri.scheme != 'content') return false;
            return item.kind == MediaKind.audio
                ? !result.audioPermissionGranted
                : !result.videoPermissionGranted;
          })
          .toList(growable: false);
      final localItems = _items
          .where((item) => item.uri.scheme != 'content')
          .toList(growable: false);
      setState(() {
        _items
          ..clear()
          ..addAll([...scannedItems, ...unscannedDeviceItems, ...localItems])
          ..sort(_compareMedia);
        _deviceAudioPermissionGranted = result.audioPermissionGranted;
        _deviceVideoPermissionGranted = result.videoPermissionGranted;
        _deviceMediaPermissionDenied =
            !result.audioPermissionGranted || !result.videoPermissionGranted;
      });
      unawaited(_rebuildSearchIndex());
      final saved = await _persistLibrary();
      if (showResult && saved) {
        _showMessage('${result.items.length} média(s) trouvés sur l’appareil.');
      }
    } catch (error) {
      if (mounted) _showMessage('Le scan des médias a échoué : $error');
    } finally {
      if (mounted) setState(() => _isScanningDeviceMedia = false);
    }
  }

  void _showPermissionMessage() {
    final missingTypes = [
      if (!_deviceAudioPermissionGranted) 'audio',
      if (!_deviceVideoPermissionGranted) 'vidéo',
    ].join(' et ');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Autorisez l’accès aux fichiers $missingTypes pour analyser votre bibliothèque.',
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
        ..themeMode = saved.themeMode
        ..volume = saved.volume
        ..speed = saved.speed
        ..shuffle = saved.shuffle
        ..repeatMode = saved.repeatMode
        ..confirmDownloads = saved.confirmDownloads
        ..dismissedRecapMonth = saved.dismissedRecapMonth
        ..preferredArtistIds = saved.preferredArtistIds
        ..artistSetupCompleted =
            saved.artistSetupCompleted || saved.preferredArtistIds.length == 5
        ..regionalTrendsEnabled = saved.regionalTrendsEnabled
        ..trendingCountryCode = saved.trendingCountryCode
        ..regionalTrendsConsentAccepted = saved.regionalTrendsConsentAccepted;
      widget.onThemeModeChanged(_settings.themeMode);
      _playback
        ..setShuffle(_settings.shuffle)
        ..setRepeatMode(_settings.repeatMode);
      _settingsReady = true;
      _maybeShowMonthlyRecap();
      unawaited(_checkNetworkForArtistSetup());
      await _playback.setVolume(_settings.volume);
      await _playback.setSpeed(_settings.speed);
    } catch (error) {
      _settingsReady = true;
      _maybeShowMonthlyRecap();
      unawaited(_checkNetworkForArtistSetup());
      if (mounted) {
        _showMessage('Les paramètres n’ont pas pu être restaurés : $error');
      }
    }
  }

  Future<void> _saveSettings() async {
    await _settings.save();
    if (mounted) setState(() {});
  }

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

  ListeningRecap _monthlyRecap() {
    final hiddenIds = _hiddenShortAudioItems.map((item) => item.id).toSet();
    final visibleHistory = _listeningHistory
        .where((session) => !hiddenIds.contains(session.mediaId))
        .toList(growable: false);
    return ListeningRecap.forPreviousMonth(visibleHistory, _visibleItems);
  }

  void _maybeShowMonthlyRecap() {
    if (!mounted ||
        !_libraryReady ||
        !_settingsReady ||
        _recapPromptScheduled) {
      return;
    }
    final recap = _monthlyRecap();
    if (recap.sessions.isEmpty) {
      unawaited(_maybeShowArtistSetup());
      return;
    }
    final monthKey = _recapMonthKey(recap.start);
    if (_settings.dismissedRecapMonth == monthKey) {
      unawaited(_maybeShowArtistSetup());
      return;
    }

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
          icon: Icon(Icons.auto_awesome_rounded, color: aqua, size: 30),
          title: const Text('Votre mois en musique est prêt'),
          content: Text(
            '${ListeningRecapScreen.formatDuration(recap.totalMilliseconds)} '
            'd’écoute, ${recap.uniqueTracks} titres et '
            '${recap.sessions.length} lectures. Découvrez vos favoris du mois.',
            style: TextStyle(color: mutedInk, height: 1.4),
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
    unawaited(_maybeShowArtistSetup());
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
          onThemeModeChanged: (mode) {
            _settings.themeMode = mode;
            widget.onThemeModeChanged(mode);
          },
          onOpenRecap: _openListeningRecap,
          hiddenAudioItems: _hiddenShortAudioItems,
          onEditArtists: _editPreferredArtists,
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

  Future<void> _refreshLibrary() async {
    if (_canScanDeviceMedia) {
      await _scanDeviceMedia(showResult: false);
    } else {
      await _rebuildSearchIndex();
    }
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

  void _submitSearch() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final query = _searchController.text.trim();
      if (query.isEmpty) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _searchOpen = false;
        _searchController.clear();
      });
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => YoutubeSearchScreen(initialQuery: query),
        ),
      );
      return;
    }
    _searchWeb();
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
          freshItems.first.kind == MediaKind.audio
              ? MediaLibraryFilter.audio
              : MediaLibraryFilter.video,
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

  Future<void> _openMedia(MediaItem item, List<MediaItem> queue) async {
    if (item.uri.scheme == 'content' &&
        (item.kind == MediaKind.audio
            ? !_deviceAudioPermissionGranted
            : !_deviceVideoPermissionGranted)) {
      _showPermissionMessage();
      return;
    }
    if (item.kind == MediaKind.video) {
      try {
        if (_playback.isPlaying) await _playback.pause();
      } catch (error) {
        if (mounted) {
          _showMessage('Impossible de mettre le son en pause : $error');
        }
        return;
      }
      if (!mounted) return;
      item.playCount++;
      item.lastPlayedAt = DateTime.now();
      _persistLibraryInBackground();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(
            item: item,
            queue: queue
                .where((entry) => entry.kind == MediaKind.video)
                .toList(),
            playback: _playback,
            onMediaChanged: _persistLibraryInBackground,
          ),
        ),
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
      unawaited(_openMedia(compatibleTracks.first, compatibleTracks));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    final audioItems = visibleItems
        .where((item) => item.kind == MediaKind.audio)
        .toList();
    final videoItems = visibleItems
        .where((item) => item.kind == MediaKind.video)
        .toList();
    final query = _searchController.text.trim().toLowerCase();
    final searchResults = query.isEmpty
        ? visibleItems
        : _searchIndex.search(query);
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
                  onSubmitted: (_) => _submitSearch(),
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: ink, fontSize: 16),
                  decoration: InputDecoration(
                    hintText:
                        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                        ? 'Médias ou recherche YouTube'
                        : 'Médias ou recherche Web',
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      tooltip:
                          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                          ? 'Rechercher sur YouTube'
                          : 'Rechercher sur le Web',
                      onPressed: _submitSearch,
                      icon: Icon(
                        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                            ? Icons.play_circle_outline_rounded
                            : Icons.public_rounded,
                      ),
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
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
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
              tooltip: 'Importer des médias',
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
                    style: TextStyle(color: ink, fontSize: 12),
                  ),
                  leading: Icon(Icons.warning_amber_rounded, color: aqua),
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
                            regionalTrendsEnabled:
                                _settings.regionalTrendsEnabled,
                            trendingCountryCode: _settings.trendingCountryCode,
                            preferredArtistIds: _settings.preferredArtistIds,
                            deviceMediaPermissionDenied:
                                _deviceMediaPermissionDenied,
                            isScanningDeviceMedia: _isScanningDeviceMedia,
                            onImport: _importMedia,
                            onScanDeviceMedia: _canScanDeviceMedia
                                ? _scanDeviceMedia
                                : null,
                            onOpen: (item) => unawaited(
                              _openMedia(
                                item,
                                item.kind == MediaKind.audio
                                    ? audioItems
                                    : videoItems,
                              ),
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
                            sortOrder: _mediaSortOrder,
                            onSortChanged: (order) =>
                                setState(() => _mediaSortOrder = order),
                            onRefresh: _refreshLibrary,
                            onFilterChanged: (filter) =>
                                setState(() => _libraryFilter = filter),
                            onImport: _importMedia,
                            onOpen: (item, visibleQueue) => unawaited(
                              _openMedia(
                                item,
                                visibleQueue
                                    .where(
                                      (queuedItem) =>
                                          queuedItem.kind == item.kind,
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                            onFavorite: (item) => _toggleFavorite(item),
                          ),
                          PlaylistLibraryScreen(
                            playlists: _playlists,
                            mediaItems: visibleItems,
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
    tint: surface,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Row(
            children: [
              MediaArtwork(title: item.title, item: item, size: 42),
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
                      style: TextStyle(
                        color: ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ink, fontSize: 10),
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
                icon: Icon(Icons.skip_next_rounded, color: ink),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
