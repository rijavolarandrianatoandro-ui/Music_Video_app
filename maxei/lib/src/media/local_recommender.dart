import 'media_item.dart';

class MediaRecommendation {
  const MediaRecommendation({required this.item, required this.reason});

  final MediaItem item;
  final String reason;
}

List<MediaRecommendation> recommendLocalTracks(
  List<MediaItem> items, {
  DateTime? now,
  int limit = 4,
}) {
  if (limit <= 0) return const [];

  final currentTime = now ?? DateTime.now();
  final audioItems = items
      .where((item) => item.kind == MediaKind.audio)
      .toList();
  final artistAffinity = <String, double>{};

  for (final item in audioItems) {
    final artist = _normalizedArtist(item.artist);
    if (artist.isEmpty) continue;

    var affinity = item.playCount.toDouble();
    if (item.isFavorite) affinity += 2;

    final lastPlayed = item.lastPlayedAt;
    if (lastPlayed != null) {
      final ageInDays = currentTime.difference(lastPlayed).inDays;
      if (ageInDays >= 0 && ageInDays < 30) {
        affinity += (30 - ageInDays) / 30;
      }
    }

    if (affinity > 0) {
      artistAffinity.update(
        artist,
        (score) => score + affinity,
        ifAbsent: () => affinity,
      );
    }
  }

  final candidates = audioItems
      .where((item) {
        if (item.isFavorite) return false;
        final lastPlayed = item.lastPlayedAt;
        return lastPlayed == null ||
            currentTime.difference(lastPlayed) >= const Duration(days: 3);
      })
      .toList();

  candidates.sort((a, b) {
    final affinityDifference =
        (_score(b, artistAffinity) - _score(a, artistAffinity));
    if (affinityDifference.abs() > 0.0001) {
      return affinityDifference > 0 ? 1 : -1;
    }
    final byPlayCount = a.playCount.compareTo(b.playCount);
    return byPlayCount != 0 ? byPlayCount : a.title.compareTo(b.title);
  });

  return [
    for (final item in candidates.take(limit))
      MediaRecommendation(
        item: item,
        reason: artistAffinity.containsKey(_normalizedArtist(item.artist))
            ? 'D’après vos écoutes de ${item.artist}'
            : 'À découvrir dans votre bibliothèque',
      ),
  ];
}

double _score(MediaItem item, Map<String, double> artistAffinity) {
  final affinity = artistAffinity[_normalizedArtist(item.artist)] ?? 0;
  return affinity + 2 / (item.playCount + 1);
}

String _normalizedArtist(String artist) {
  final normalized = artist.trim().toLowerCase();
  return normalized == 'fichier local' ? '' : normalized;
}
