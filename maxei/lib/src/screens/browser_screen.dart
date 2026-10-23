import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;

import '../media/media_downloader.dart';
import '../media/download_manager.dart';
import '../media/media_link.dart';
import '../media/media_link_parser.dart';
import '../theme/maxei_theme.dart';
import '../platform/platform_info.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.onDownloaded,
    this.downloadManager,
    this.confirmDownloads = true,
    this.searchQuery = '',
    this.searchRequestId = 0,
  });

  final ValueChanged<DownloadedMedia> onDownloaded;
  final DownloadManager? downloadManager;
  final bool confirmDownloads;
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
  InAppWebViewController? _webController;
  windows_webview.WebviewController? _windowsWebController;
  StreamSubscription<String>? _windowsUrlSubscription;
  StreamSubscription<windows_webview.LoadingState>? _windowsLoadingSubscription;
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
      final query = widget.searchQuery.trim();
      final initialUri = query.isEmpty
          ? Uri.parse('https://www.google.com/')
          : _searchUri(query);
      _addressController.text = initialUri.toString();
    } else if (isWindowsPlatform) {
      final query = widget.searchQuery.trim();
      _addressController.text =
          (query.isEmpty
                  ? Uri.parse('https://www.google.com/')
                  : _searchUri(query))
              .toString();
      unawaited(_initializeWindowsBrowser());
    } else {
      final query = widget.searchQuery.trim();
      final initialUri = query.isEmpty
          ? Uri.parse('https://www.google.com/')
          : _searchUri(query);
      _addressController.text = initialUri.toString();
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
    unawaited(_windowsUrlSubscription?.cancel());
    unawaited(_windowsLoadingSubscription?.cancel());
    unawaited(_windowsWebController?.dispose());
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeWindowsBrowser() async {
    try {
      final version =
          await windows_webview.WebviewController.getWebViewVersion();
      if (version == null) {
        if (mounted) {
          setState(
            () => _error =
                'WebView2 Runtime est requis pour le mini-navigateur Windows.',
          );
        }
        return;
      }
      final controller = windows_webview.WebviewController();
      await controller.initialize();
      await controller.setPopupWindowPolicy(
        windows_webview.WebviewPopupWindowPolicy.sameWindow,
      );
      _windowsUrlSubscription = controller.url.listen(_onWindowsUrlChanged);
      _windowsLoadingSubscription = controller.loadingState.listen((state) {
        if (!mounted) return;
        setState(() {
          _pageProgress =
              state == windows_webview.LoadingState.navigationCompleted
              ? 100
              : 35;
        });
      });
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _windowsWebController = controller);
      final query = widget.searchQuery.trim();
      await controller.loadUrl(
        (query.isEmpty
                ? Uri.parse('https://www.google.com/')
                : _searchUri(query))
            .toString(),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Le mini-navigateur Windows n’a pas pu démarrer : $error',
        );
      }
    }
  }

  void _onWindowsUrlChanged(String url) {
    _onPageFinished(url);
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
    final windowsController = _windowsWebController;
    if (windowsController != null) {
      await windowsController.loadUrl(uri.toString());
    } else if (controller == null) {
      if (isWindowsPlatform) {
        _showWindowsUnavailable();
      } else {
        await _openInSystemBrowser(uri);
      }
    } else {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(uri.toString())),
      );
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
    final windowsController = _windowsWebController;
    if (windowsController != null) {
      await windowsController.loadUrl(uri.toString());
    } else if (controller == null) {
      if (isWindowsPlatform) {
        _showWindowsUnavailable();
      } else {
        await _openInSystemBrowser(uri);
      }
      return;
    } else {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(uri.toString())),
      );
    }
  }

  Future<void> _openInSystemBrowser(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;
    setState(() => _error = 'Impossible d’ouvrir le navigateur du système.');
  }

  void _showWindowsUnavailable() {
    if (!mounted) return;
    setState(
      () => _error = 'Le mini-navigateur Windows attend WebView2 Runtime. Installez-le puis relancez Maxei.',
    );
  }

  Future<void> _openDirectDownload() async {
    final link = _currentMediaLink;
    if (link == null || _isDownloading) return;
    if (widget.confirmDownloads) {
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
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _error = null;
    });
    try {
      final download = widget.downloadManager == null
          ? await downloadDirectMedia(
              link.uri,
              onProgress: (progress) {
                if (mounted) setState(() => _downloadProgress = progress);
              },
            )
          : await widget.downloadManager!.enqueue(link.uri);
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
    final windowsController = _windowsWebController;
    if (windowsController != null) {
      await windowsController.goBack();
    } else if (await _webController?.canGoBack() ?? false) {
      await _webController?.goBack();
    }
  }

  Future<void> _goForward() async {
    final windowsController = _windowsWebController;
    if (windowsController != null) {
      await windowsController.goForward();
    } else if (await _webController?.canGoForward() ?? false) {
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
          child: _windowsWebController != null
              ? windows_webview.Webview(_windowsWebController!)
              : _webController != null
              ? InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_addressController.text),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onWebViewCreated: (controller) {
                    _webController = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    if (mounted) setState(() => _pageProgress = progress);
                  },
                  onLoadStart: (controller, url) {
                    if (url != null && mounted) {
                      setState(() {
                        _pageProgress = 0;
                        _currentMediaLink = null;
                        _error = null;
                        _addressController.text = url.toString();
                      });
                    }
                  },
                  onLoadStop: (controller, url) {
                    if (url != null) _onPageFinished(url.toString());
                  },
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame == true && mounted) {
                      setState(
                        () => _error = 'Cette page ne peut pas être chargée.',
                      );
                    }
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    final uri = action.request.url;
                    if (uri == null ||
                        !{'http', 'https'}.contains(uri.scheme)) {
                      return NavigationActionPolicy.CANCEL;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_browser_rounded,
                          size: 42,
                          color: ink.withValues(alpha: 0.65),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sur PC, Maxei ouvre les recherches et les adresses dans votre navigateur par défaut.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ink.withValues(alpha: 0.72)),
                        ),
                        const SizedBox(height: 16),
                        if (!isWindowsPlatform)
                          FilledButton.icon(
                            onPressed: () => _openInSystemBrowser(
                              _resolveAddress(_addressController.text) ??
                                  Uri.parse('https://www.google.com/'),
                            ),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Ouvrir dans le navigateur'),
                          ),
                      ],
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
                onPressed: _webController == null ? null : _goBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              IconButton(
                tooltip: 'Page suivante',
                onPressed: _webController == null ? null : _goForward,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              IconButton(
                tooltip: 'Recharger la page',
                onPressed: _windowsWebController != null
                    ? () => _windowsWebController?.reload()
                    : isWindowsPlatform
                    ? _showWindowsUnavailable
                    : _webController == null
                    ? () => _openInSystemBrowser(
                        Uri.tryParse(_addressController.text) ??
                            Uri.parse('https://www.google.com/'),
                      )
                    : () => _webController?.reload(),
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
