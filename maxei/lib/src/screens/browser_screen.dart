import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../media/media_downloader.dart';
import '../media/media_link.dart';
import '../media/media_link_parser.dart';
import '../theme/maxei_theme.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.onDownloaded,
    this.searchQuery = '',
    this.searchRequestId = 0,
  });

  final ValueChanged<DownloadedMedia> onDownloaded;
  final String searchQuery;
  final int searchRequestId;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const _searchBase = 'https://www.google.com/search?q=';

  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _parser = const MediaLinkParser();
  late final bool _supportsEmbeddedBrowser;
  WebViewController? _webController;
  MediaLink? _currentMediaLink;
  int _pageProgress = 0;
  double? _downloadProgress;
  String? _error;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _supportsEmbeddedBrowser =
        !kIsWeb &&
        const {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform);
    if (_supportsEmbeddedBrowser) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _pageProgress = progress);
            },
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _pageProgress = 0;
                  _currentMediaLink = null;
                  _error = null;
                  _addressController.text = url;
                });
              }
            },
            onPageFinished: _onPageFinished,
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted) {
                setState(() => _error = 'Cette page ne peut pas être chargée.');
              }
            },
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );
      _webController = controller;
      final query = widget.searchQuery.trim();
      final initialUri = query.isEmpty
          ? Uri.parse('https://www.google.com/')
          : _searchUri(query);
      _addressController.text = initialUri.toString();
      controller.loadRequest(initialUri);
    }
  }

  @override
  void didUpdateWidget(covariant BrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchRequestId != widget.searchRequestId &&
        widget.searchQuery.trim().isNotEmpty) {
      _loadSearch(widget.searchQuery);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _onPageFinished(String url) {
    final uri = Uri.tryParse(url);
    MediaLink? mediaLink;
    if (uri != null) {
      try {
        final parsed = _parser.parse(uri.toString());
        if (parsed.platform == MediaPlatform.directFile &&
            uri.scheme == 'https') {
          mediaLink = parsed;
        }
      } on FormatException {
        mediaLink = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _pageProgress = 100;
      _addressController.text = url;
      _currentMediaLink = mediaLink;
    });
  }

  Uri? _resolveAddress(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) return null;
    final looksLikeUrl =
        input.contains('://') ||
        RegExp(
          r'^(localhost|[\w-]+\.)+[\w-]+(?::\d+)?(?:/|$)',
          caseSensitive: false,
        ).hasMatch(input);
    if (looksLikeUrl && !input.contains(RegExp(r'\s'))) {
      final candidate = Uri.tryParse(
        input.contains('://') ? input : 'https://$input',
      );
      if (candidate != null &&
          candidate.host.isNotEmpty &&
          {'http', 'https'}.contains(candidate.scheme.toLowerCase())) {
        return candidate;
      }
    }
    return _searchUri(input);
  }

  Uri _searchUri(String query) =>
      Uri.parse('$_searchBase${Uri.encodeQueryComponent(query)}');

  Future<void> _loadSearch(String query) async {
    final uri = _searchUri(query.trim());
    _addressController.text = uri.toString();
    final controller = _webController;
    if (controller == null) {
      if (mounted) {
        setState(
          () => _error = 'La navigation intégrée est disponible dans la version mobile de Maxei.',
        );
      }
    } else {
      await controller.loadRequest(uri);
    }
  }

  Future<void> _navigate() async {
    final uri = _resolveAddress(_addressController.text);
    if (uri == null) return;
    _addressFocusNode.unfocus();
    setState(() {
      _error = null;
      _currentMediaLink = null;
      _pageProgress = 0;
    });
    final controller = _webController;
    if (controller == null) {
      if (mounted) {
        setState(
          () => _error = 'La navigation intégrée est disponible dans la version mobile de Maxei.',
        );
      }
      return;
    }
    await controller.loadRequest(uri);
  }

  Future<void> _openDirectDownload() async {
    final link = _currentMediaLink;
    if (link == null || _isDownloading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enregistrer ce média ?'),
        content: const Text(
          'Confirmez que vous possédez ce fichier ou avez l’autorisation de le télécharger. Le fichier sera enregistré dans l’espace privé de Maxei.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _error = null;
    });
    try {
      final download = await downloadDirectMedia(
        link.uri,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      widget.onDownloaded(download);
    } on UnsupportedError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Le téléchargement a échoué. Vérifiez le lien direct et réessayez.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _goBack() async {
    if (await _webController?.canGoBack() ?? false) {
      await _webController?.goBack();
    }
  }

  Future<void> _goForward() async {
    if (await _webController?.canGoForward() ?? false) {
      await _webController?.goForward();
    }
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _addressController,
            focusNode: _addressFocusNode,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _navigate(),
            decoration: InputDecoration(
              hintText: 'Rechercher ou saisir une adresse',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Ouvrir la recherche ou l’adresse',
                onPressed: _navigate,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              isDense: true,
            ),
          ),
        ),
        if (_pageProgress < 100)
          LinearProgressIndicator(
            value: _pageProgress == 0 ? null : _pageProgress / 100,
            minHeight: 2,
            color: aqua,
          )
        else
          const SizedBox(height: 2),
        Expanded(
          child: _webController != null
              ? WebViewWidget(controller: _webController!)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Le mini-navigateur est disponible dans les versions Android, iOS et macOS de Maxei.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ink.withValues(alpha: 0.72)),
                    ),
                  ),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Page précédente',
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              IconButton(
                tooltip: 'Page suivante',
                onPressed: _goForward,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              IconButton(
                tooltip: 'Recharger la page',
                onPressed: () => _webController?.reload(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _currentMediaLink == null || _isDownloading
                    ? null
                    : _openDirectDownload,
                icon: _isDownloading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ink,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _isDownloading
                      ? _downloadProgress == null
                            ? 'Téléchargement…'
                            : 'Téléchargement ${(_downloadProgress! * 100).round()} %'
                      : _currentMediaLink == null
                      ? 'Téléchargement disponible pour les fichiers directs autorisés'
                      : 'Enregistrer le fichier média',
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
