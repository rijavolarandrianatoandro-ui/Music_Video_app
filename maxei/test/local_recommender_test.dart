import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/local_recommender.dart';
import 'package:maxei/src/media/media_item.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23);

  MediaItem track(String name, {MediaKind kind = MediaKind.audio}) =>
      MediaItem.stored(
        name: name,
        uri: Uri.parse('maxei-web://${Uri.encodeComponent(name)}'),
        size: 1024,
        kind: kind,
      );

  test('ranks unheard tracks from artists the user listens to', () {
    final recentTrack = track('Nova - Déjà entendu.mp3')
      ..playCount = 6
      ..lastPlayedAt = now.subtract(const Duration(days: 2));
    final relatedTrack = track('Nova - À découvrir.mp3');
    final unrelatedTrack = track('Echo - À découvrir.mp3');

    final recommendations = recommendLocalTracks([
      recentTrack,
      relatedTrack,
      unrelatedTrack,
    ], now: now);

    expect(recommendations.first.item, same(relatedTrack));
    expect(recommendations.first.reason, 'D’après vos écoutes de Nova');
  });

  test('does not recommend favorites, recently played tracks, or videos', () {
    final favorite = track('Nova - Favori.mp3')..isFavorite = true;
    final justPlayed = track('Nova - Récent.mp3')
      ..lastPlayedAt = now.subtract(const Duration(days: 1));
    final video = track('Nova - Clip.mp4', kind: MediaKind.video);

    final recommendations = recommendLocalTracks([
      favorite,
      justPlayed,
      video,
    ], now: now);

    expect(recommendations, isEmpty);
  });

  test('returns at most the requested number of audio recommendations', () {
    final tracks = [
      track('A - One.mp3'),
      track('B - Two.mp3'),
      track('C - Three.mp3'),
    ];

    final recommendations = recommendLocalTracks(tracks, now: now, limit: 2);

    expect(recommendations, hasLength(2));
  });
}
