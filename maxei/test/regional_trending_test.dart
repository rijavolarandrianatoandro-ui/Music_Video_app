import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/media_item.dart';
import 'package:maxei/src/media/music_discovery_catalog.dart';
import 'package:maxei/src/media/regional_trending.dart';
import 'package:maxei/src/media/youtube_video.dart';

void main() {
  test('ranks chosen artists and locally favored genres above chart order', () {
    final popVideo = const YoutubeVideo(
      id: 'abcdefghijk',
      title: 'Taylor Swift - New song',
      channelTitle: 'Official',
    );
    final rapVideo = const YoutubeVideo(
      id: 'bcdefghijkl',
      title: 'New rap hit',
      channelTitle: 'Music',
    );
    final libraryTrack = MediaItem.stored(
      name: 'Taylor Swift.mp3',
      uri: Uri.parse('file:///taylor.mp3'),
      size: 10,
      kind: MediaKind.audio,
      title: 'Taylor Swift',
      artist: 'Taylor Swift',
    )..isFavorite = true;

    final ranked = rankRegionalTrends(
      [rapVideo, popVideo],
      library: [libraryTrack],
      preferredArtistIds: const ['taylor-swift'],
    );

    expect(ranked.first.video.id, popVideo.id);
  });

  test('artist and region catalogs use stable ids and valid region codes', () {
    expect(featuredArtists.length, greaterThan(5));
    expect(artistById('bts')?.name, 'BTS');
    expect(regionByCode('MG')?.name, 'Madagascar');
    expect(regionByCode(null), isNull);
  });
}
