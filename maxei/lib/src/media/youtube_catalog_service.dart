import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'youtube_video.dart';

const _favoritesKey = 'youtube_catalog_favorites_v1';
const _consentKey = 'youtube_catalog_consent_v1';
const _defaultWorkerUrl = String.fromEnvironment('YOUTUBE_CATALOG_WORKER_URL');

class YoutubeCatalogService {
  YoutubeCatalogService({
    http.Client? client,
    this.workerUrl = _defaultWorkerUrl,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final String workerUrl;

  Future<bool> isAvailable() async {
    try {
      final payload = await _getJson(_endpoint('/api/health', const {}));
      return payload is Map<String, dynamic> && payload['ok'] == true;
    } on TimeoutException {
      return false;
    } on http.ClientException {
      return false;
    } on StateError {
      return false;
    } on FormatException {
      return false;
    }
  }

  Future<List<YoutubeVideo>> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2 || normalizedQuery.length > 100) {
      throw const FormatException('Saisissez entre 2 et 100 caractères.');
    }

    final payload = await _getJson(
      _endpoint('/api/search', {'q': normalizedQuery}),
    );
    return _parseVideos(payload);
  }

  Future<List<YoutubeVideo>> loadRegionalTrends(String countryCode) async {
    final region = countryCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
      throw const FormatException('Choisissez un pays valide.');
    }
    final payload = await _getJson(
      _endpoint('/api/trending', {'region': region}),
    );
    return _parseVideos(payload);
  }

  Future<List<YoutubeVideo>> loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList(_favoritesKey) ?? const [];
    final validIds = ids
        .where((id) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id))
        .toSet()
        .toList(growable: false);
    if (validIds.isEmpty) return const [];

    final videos = <YoutubeVideo>[];
    for (var start = 0; start < validIds.length; start += 50) {
      final end = (start + 50).clamp(0, validIds.length);
      final payload = await _getJson(
        _endpoint('/api/videos', {
          'ids': validIds.sublist(start, end).join(','),
        }),
      );
      videos.addAll(_parseVideos(payload));
    }
    return videos;
  }

  Future<Set<String>> favoriteIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_favoritesKey) ?? const [])
        .where((id) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id))
        .toSet();
  }

  Future<void> setFavorite(String videoId, bool isFavorite) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
      throw const FormatException('Identifiant YouTube invalide.');
    }
    final preferences = await SharedPreferences.getInstance();
    final ids = (preferences.getStringList(_favoritesKey) ?? const [])
        .where((id) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id))
        .toList();
    ids.remove(videoId);
    if (isFavorite) {
      ids.add(videoId);
    }
    await preferences.setStringList(_favoritesKey, ids);
  }

  Future<void> clearFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_favoritesKey);
  }

  Future<bool> hasAcceptedPolicy() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_consentKey) ?? false;
  }

  Future<void> acceptPolicy() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_consentKey, true);
  }

  Future<void> revokePolicy() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_consentKey);
  }

  Uri _endpoint(String path, Map<String, String> parameters) {
    final worker = Uri.tryParse(workerUrl);
    if (worker == null ||
        worker.scheme != 'https' ||
        worker.host.isEmpty ||
        worker.userInfo.isNotEmpty) {
      throw StateError(
        'Configurez YOUTUBE_CATALOG_WORKER_URL avec l’URL HTTPS du Worker.',
      );
    }
    return Uri(
      scheme: worker.scheme,
      host: worker.host,
      port: worker.hasPort ? worker.port : null,
      path: path,
      queryParameters: parameters,
    );
  }

  Future<Object?> _getJson(Uri uri) async {
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 429) {
      throw StateError('Trop de recherches. Réessayez dans une minute.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        response.statusCode == 503
            ? 'Le service de recherche est indisponible.'
            : 'La recherche YouTube a échoué (${response.statusCode}).',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw StateError('Réponse invalide du service de recherche.');
    }
  }

  List<YoutubeVideo> _parseVideos(Object? payload) {
    if (payload is! Map<String, dynamic> || payload['items'] is! List) {
      throw StateError('Réponse invalide du service de recherche.');
    }
    return (payload['items'] as List)
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Résultat YouTube invalide.');
          }
          return YoutubeVideo.fromJson(item);
        })
        .toList(growable: false);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
