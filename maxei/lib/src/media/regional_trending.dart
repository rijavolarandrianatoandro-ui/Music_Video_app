import 'media_item.dart';
import 'music_discovery_catalog.dart';
import 'youtube_video.dart';

class RegionalTrend {
  const RegionalTrend({required this.video, required this.score});

  final YoutubeVideo video;
  final double score;
}

List<RegionalTrend> rankRegionalTrends(
  List<YoutubeVideo> videos, {
  required List<MediaItem> library,
  required List<String> preferredArtistIds,
}) {
  final preferredArtists = preferredArtistIds
      .map(artistById)
      .whereType<MusicArtist>()
      .toList(growable: false);
  final genreWeights = <String, double>{};
  for (final artist in preferredArtists) {
    for (final genre in artist.genres) {
      genreWeights.update(genre, (weight) => weight + 1, ifAbsent: () => 1);
    }
  }

  final artistsByName = {
    for (final artist in featuredArtists) _normalize(artist.name): artist,
  };
  final localAffinity = <String, double>{};
  for (final item in library.where((item) => item.kind == MediaKind.audio)) {
    final normalizedArtist = _normalize(item.artist);
    final artist = artistsByName[normalizedArtist];
    if (artist == null) continue;
    final weight = (1 + item.playCount + (item.isFavorite ? 5 : 0)).toDouble();
    localAffinity.update(
      artist.id,
      (current) => current + weight,
      ifAbsent: () => weight,
    );
    for (final genre in artist.genres) {
      genreWeights.update(
        genre,
        (current) => current + weight / 5,
        ifAbsent: () => weight / 5,
      );
    }
  }

  final normalizedPreferredIds = preferredArtistIds.toSet();
  final ranked = <({YoutubeVideo video, double score, int index})>[];
  for (var index = 0; index < videos.length; index++) {
    final video = videos[index];
    final text = _normalize('${video.title} ${video.channelTitle}');
    var score = (videos.length - index).toDouble();

    for (final artist in featuredArtists) {
      if (text.contains(_normalize(artist.name))) {
        score += normalizedPreferredIds.contains(artist.id) ? 120 : 0;
        score += (localAffinity[artist.id] ?? 0) * 4;
      }
    }
    for (final entry in genreWeights.entries) {
      final aliases = _genreAliases[entry.key] ?? [entry.key];
      if (aliases.any(text.contains)) score += entry.value * 8;
    }
    ranked.add((video: video, score: score, index: index));
  }

  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return [
    for (final result in ranked)
      RegionalTrend(video: result.video, score: result.score),
  ];
}

const _genreAliases = <String, List<String>>{
  'pop': ['pop'],
  'r&b': ['r&b', 'rnb', 'rhythm and blues'],
  'latin': ['latin', 'latino', 'latina'],
  'reggaeton': ['reggaeton', 'reguetón'],
  'hip-hop': ['hip hop', 'hip-hop', 'rap'],
  'k-pop': ['k-pop', 'kpop'],
  'dance': ['dance', 'dance music'],
  'rock': ['rock', 'metal'],
  'afrobeats': ['afrobeats', 'afrobeat', 'afropop'],
  'funk': ['funk'],
  'electronic': ['electronic', 'edm', 'techno', 'house'],
  'soul': ['soul'],
};

String _normalize(String value) => value.trim().toLowerCase();
