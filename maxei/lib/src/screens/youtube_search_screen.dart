import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../media/youtube_catalog_service.dart';
import '../media/youtube_video.dart';
import '../theme/maxei_theme.dart';

class YoutubeSearchScreen extends StatefulWidget {
  const YoutubeSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<YoutubeSearchScreen> createState() => _YoutubeSearchScreenState();
}

class _YoutubeSearchScreenState extends State<YoutubeSearchScreen> {
  final _service = YoutubeCatalogService();
  late final TextEditingController _queryController;
  final _focusNode = FocusNode();
  List<YoutubeVideo> _videos = const [];
  Set<String> _favoriteIds = {};
  String? _error;
  int _tab = 0;
  bool _isLoading = false;
  bool _consentLoaded = false;
  bool _consentAccepted = false;
  bool _consentPrompting = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _service.dispose();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final accepted = await _service.hasAcceptedPolicy();
      final favoriteIds = await _service.favoriteIds();
      if (!mounted) return;
      setState(() {
        _consentLoaded = true;
        _consentAccepted = accepted;
        _favoriteIds = favoriteIds;
      });
      if (!accepted) {
        await _showPolicy(requireConsent: true);
      }
      if (_consentAccepted && _queryController.text.trim().isNotEmpty) {
        await _search();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _clearFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer les favoris YouTube ?'),
        content: const Text('Les références enregistrées seront supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.clearFavorites();
      if (mounted) {
        setState(() {
          _favoriteIds.clear();
          _videos = const [];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<bool> _ensureConsent() async {
    if (!_consentLoaded) {
      try {
        final accepted = await _service.hasAcceptedPolicy();
        if (!mounted) return false;
        setState(() {
          _consentLoaded = true;
          _consentAccepted = accepted;
        });
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
        return false;
      }
    }
    if (_consentAccepted) return true;
    await _showPolicy(requireConsent: true);
    return _consentAccepted;
  }

  Future<void> _showPolicy({required bool requireConsent}) async {
    if (_consentPrompting) return;
    _consentPrompting = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: !requireConsent,
        builder: (context) => AlertDialog(
          title: const Text('Recherche YouTube'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Maxei transmet votre recherche à son Worker hébergé par '
                  'Cloudflare puis à YouTube pour afficher des titres, '
                  'chaînes et miniatures. '
                  'Les favoris enregistrent uniquement les identifiants '
                  'YouTube sur cet appareil. Aucun fichier audio ou vidéo '
                  'n’est envoyé ou téléchargé. La lecture se fait sur YouTube.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cloudflare et Google peuvent traiter les informations '
                  'nécessaires à la fourniture du service, comme votre requête '
                  'et des données de connexion. En continuant, vous acceptez '
                  'les conditions YouTube et cette notice. Consultez les '
                  'politiques liées pour en savoir plus.',
                ),
                const SizedBox(height: 12),
                _PolicyLink(
                  label: 'Conditions d’utilisation YouTube',
                  uri: Uri.https('www.youtube.com', '/t/terms'),
                ),
                _PolicyLink(
                  label: 'Confidentialité Google',
                  uri: Uri.https('policies.google.com', '/privacy'),
                ),
              ],
            ),
          ),
          actions: [
            if (requireConsent)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Refuser'),
              )
            else if (_consentAccepted)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Retirer mon accord'),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Fermer'),
              ),
            if (requireConsent)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Accepter et continuer'),
              ),
          ],
        ),
      );
      if (accepted == true) {
        await _service.acceptPolicy();
        if (mounted) setState(() => _consentAccepted = true);
      } else if (accepted == false && !requireConsent) {
        await _service.revokePolicy();
        if (mounted) setState(() => _consentAccepted = false);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _consentPrompting = false;
    }
  }

  Future<void> _search() async {
    if (!await _ensureConsent() || !mounted) return;
    final query = _queryController.text.trim();
    if (query.length < 2 || query.length > 100) {
      setState(() => _error = 'Saisissez entre 2 et 100 caractères.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _tab = 0;
      _isLoading = true;
      _error = null;
      _videos = const [];
    });
    try {
      final videos = await _service.search(query);
      if (mounted) setState(() => _videos = videos);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavorites() async {
    if (!await _ensureConsent() || !mounted) return;
    setState(() {
      _tab = 1;
      _isLoading = true;
      _error = null;
      _videos = const [];
    });
    try {
      final videos = await _service.loadFavorites();
      final favoriteIds = await _service.favoriteIds();
      if (mounted) {
        setState(() {
          _videos = videos;
          _favoriteIds = favoriteIds;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(YoutubeVideo video) async {
    final isFavorite = !_favoriteIds.contains(video.id);
    try {
      await _service.setFavorite(video.id, isFavorite);
      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _favoriteIds.add(video.id);
        } else {
          _favoriteIds.remove(video.id);
          if (_tab == 1) {
            _videos = _videos.where((item) => item.id != video.id).toList();
          }
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _openVideo(YoutubeVideo video) async {
    try {
      if (!await launchUrl(
        video.youtubeUri,
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Impossible d’ouvrir YouTube.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('YouTube'),
      actions: [
        if (_tab == 1 && _favoriteIds.isNotEmpty)
          IconButton(
            tooltip: 'Effacer les favoris YouTube',
            onPressed: _clearFavorites,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        IconButton(
          tooltip: 'Informations et confidentialité',
          onPressed: () => _showPolicy(requireConsent: false),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    maxLength: 100,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher des vidéos',
                      counterText: '',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Rechercher sur YouTube',
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Recherche')),
                ButtonSegment(
                  value: 1,
                  label: Text('Favoris'),
                  icon: Icon(Icons.favorite_rounded),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) {
                if (selection.single == 1) {
                  _loadFavorites();
                } else {
                  setState(() {
                    _tab = 0;
                    _error = null;
                  });
                }
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _videos.isEmpty && !_isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        _tab == 1
                            ? 'Aucun favori YouTube.'
                            : 'Les résultats YouTube apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedInk),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videos.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      final isFavorite = _favoriteIds.contains(video.id);
                      return Material(
                        color: surface,
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: BorderSide(color: ink.withValues(alpha: 0.08)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            6,
                            8,
                            6,
                          ),
                          leading: _YoutubeThumbnail(video: video),
                          title: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            video.channelTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: mutedInk),
                          ),
                          trailing: IconButton(
                            tooltip: isFavorite
                                ? 'Retirer des favoris'
                                : 'Ajouter aux favoris',
                            onPressed: () => _toggleFavorite(video),
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite ? aqua : mutedInk,
                            ),
                          ),
                          onTap: () => _openVideo(video),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Résultats et miniatures fournis par YouTube. '
              'Maxei ne télécharge pas ces contenus.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedInk.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _YoutubeThumbnail extends StatelessWidget {
  const _YoutubeThumbnail({required this.video});

  final YoutubeVideo video;

  @override
  Widget build(BuildContext context) {
    final thumbnail = video.thumbnailUrl;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        height: 58,
        child: thumbnail == null
            ? ColoredBox(
                color: surface,
                child: Icon(Icons.play_circle_outline_rounded, color: aqua),
              )
            : Image.network(
                thumbnail.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: surface,
                  child: Icon(Icons.play_circle_outline_rounded, color: aqua),
                ),
              ),
      ),
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Text(label),
    ),
  );
}
