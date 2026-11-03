import 'package:flutter/foundation.dart';

import 'media_item.dart';

class MediaSearchIndex {
  final Map<String, Set<String>> _postings = {};
  final Map<String, String> _titles = {};
  final Map<String, String> _artists = {};
  final Map<String, String> _searchableText = {};
  final Map<String, MediaItem> _itemsById = {};
  List<MediaItem> _allItems = const [];
  int _buildVersion = 0;
  bool _isBuilding = false;

  void rebuild(Iterable<MediaItem> items) {
    _buildVersion++;
    _isBuilding = false;
    _allItems = items.toList(growable: false);
    _postings.clear();
    _titles.clear();
    _artists.clear();
    _searchableText.clear();
    _itemsById.clear();

    for (final item in _allItems) {
      final title = _normalize(item.title);
      final artist = _normalize(item.artist);
      final searchable =
          '$title $artist ${_normalize(item.album)} '
          '${_normalize(item.name)}';
      _titles[item.id] = title;
      _artists[item.id] = artist;
      _searchableText[item.id] = searchable;
      _itemsById[item.id] = item;

      for (final token in _tokens(searchable)) {
        for (var length = 1; length <= token.length && length <= 3; length++) {
          _postings
              .putIfAbsent(token.substring(0, length), () => <String>{})
              .add(item.id);
        }
        for (var start = 0; start + 3 <= token.length; start++) {
          _postings
              .putIfAbsent(token.substring(start, start + 3), () => <String>{})
              .add(item.id);
        }
      }
    }
  }

  Future<void> rebuildInBackground(Iterable<MediaItem> items) async {
    final snapshot = items.toList(growable: false);
    final buildVersion = ++_buildVersion;
    _allItems = snapshot;
    _itemsById
      ..clear()
      ..addEntries(snapshot.map((item) => MapEntry(item.id, item)));
    _isBuilding = true;

    final input = snapshot
        .map(
          (item) => {
            'id': item.id,
            'title': item.title,
            'artist': item.artist,
            'album': item.album,
            'name': item.name,
          },
        )
        .toList(growable: false);
    late final Map<String, Object?> data;
    try {
      data = await compute(_buildIndexData, input);
    } catch (_) {
      if (buildVersion == _buildVersion) {
        rebuild(snapshot);
      }
      rethrow;
    }
    if (buildVersion != _buildVersion) return;

    _postings
      ..clear()
      ..addAll(
        (data['postings']! as Map<String, Object?>).map(
          (gram, ids) => MapEntry(gram, Set<String>.from(ids! as List)),
        ),
      );
    _titles
      ..clear()
      ..addAll(
        (data['titles']! as Map<String, Object?>).cast<String, String>(),
      );
    _artists
      ..clear()
      ..addAll(
        (data['artists']! as Map<String, Object?>).cast<String, String>(),
      );
    _searchableText
      ..clear()
      ..addAll(
        (data['searchable']! as Map<String, Object?>).cast<String, String>(),
      );
    _isBuilding = false;
  }

  List<MediaItem> search(String query) {
    final tokens = _tokens(_normalize(query));
    if (tokens.isEmpty) return _allItems;
    if (_isBuilding) {
      return _allItems.where((item) {
        final searchable =
            '${_normalize(item.title)} ${_normalize(item.artist)} '
            '${_normalize(item.album)} ${_normalize(item.name)}';
        return tokens.every(searchable.contains);
      }).toList();
    }

    Set<String>? candidates;
    for (final token in tokens) {
      final grams = token.length <= 3
          ? [token]
          : [
              for (var start = 0; start + 3 <= token.length; start++)
                token.substring(start, start + 3),
            ];
      for (final gram in grams.toSet()) {
        final matches = _postings[gram];
        if (matches == null) return const [];
        candidates = candidates == null
            ? Set<String>.of(matches)
            : candidates.intersection(matches);
        if (candidates.isEmpty) return const [];
      }
    }

    final results =
        candidates?.map((id) => _itemsById[id]).whereType<MediaItem>().where((
          item,
        ) {
          final title = _titles[item.id] ?? '';
          final artist = _artists[item.id] ?? '';
          final searchable = _searchableText[item.id] ?? '$title $artist';
          return tokens.every(searchable.contains);
        }).toList() ??
        const <MediaItem>[];

    results.sort((a, b) {
      final aTitle = _titles[a.id] ?? '';
      final bTitle = _titles[b.id] ?? '';
      final aRank = aTitle.startsWith(tokens.first)
          ? 0
          : (_artists[a.id] ?? '').startsWith(tokens.first)
          ? 1
          : 2;
      final bRank = bTitle.startsWith(tokens.first)
          ? 0
          : (_artists[b.id] ?? '').startsWith(tokens.first)
          ? 1
          : 2;
      final byRelevance = aRank.compareTo(bRank);
      return byRelevance != 0 ? byRelevance : a.title.compareTo(b.title);
    });
    return results;
  }

  static List<String> _tokens(String value) => _tokensFor(value);

  static String _normalize(String value) => value.trim().toLowerCase();
}

Map<String, Object?> _buildIndexData(List<Map<String, String>> items) {
  final postings = <String, Set<String>>{};
  final titles = <String, String>{};
  final artists = <String, String>{};
  final searchableText = <String, String>{};

  for (final item in items) {
    final id = item['id']!;
    final title = _normalizeForIndex(item['title']!);
    final artist = _normalizeForIndex(item['artist']!);
    final searchable =
        '$title $artist ${_normalizeForIndex(item['album']!)} '
        '${_normalizeForIndex(item['name']!)}';
    titles[id] = title;
    artists[id] = artist;
    searchableText[id] = searchable;

    for (final token in _tokensFor(searchable)) {
      for (var length = 1; length <= token.length && length <= 3; length++) {
        postings
            .putIfAbsent(token.substring(0, length), () => <String>{})
            .add(id);
      }
      for (var start = 0; start + 3 <= token.length; start++) {
        postings
            .putIfAbsent(token.substring(start, start + 3), () => <String>{})
            .add(id);
      }
    }
  }

  return {
    'postings': {
      for (final entry in postings.entries) entry.key: entry.value.toList(),
    },
    'titles': titles,
    'artists': artists,
    'searchable': searchableText,
  };
}

List<String> _tokensFor(String value) =>
    value.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      ..removeWhere((token) => token.isEmpty);

String _normalizeForIndex(String value) => value.trim().toLowerCase();
