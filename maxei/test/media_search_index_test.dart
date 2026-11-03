import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/media_item.dart';
import 'package:maxei/src/media/media_search_index.dart';

void main() {
  MediaItem track(
    String id, {
    required String title,
    required String artist,
    String album = '',
  }) => MediaItem.stored(
    name: '$title.mp3',
    uri: Uri.parse('file:///$id.mp3'),
    size: 1024,
    kind: MediaKind.audio,
    title: title,
    artist: artist,
    album: album,
  );

  test('matches title and artist prefixes without scanning the full list', () {
    final titleMatch = track(
      'one',
      title: 'Neon Lights',
      artist: 'The Satellites',
    );
    final artistMatch = track('two', title: 'Afterglow', artist: 'Neon Fields');
    final unrelated = track('three', title: 'Ocean', artist: 'Waves');
    final index = MediaSearchIndex()
      ..rebuild([unrelated, artistMatch, titleMatch]);

    expect(index.search('neon'), [titleMatch, artistMatch]);
  });

  test('matches partial substrings in album metadata', () {
    final item = track(
      'album',
      title: 'Morning',
      artist: 'Artist',
      album: 'Silver Horizon',
    );
    final index = MediaSearchIndex()..rebuild([item]);

    expect(index.search('horiz'), [item]);
    expect(index.search('not found'), isEmpty);
  });

  test('rebuild removes items that are no longer in the library', () {
    final item = track('old', title: 'Old Song', artist: 'Artist');
    final index = MediaSearchIndex()..rebuild([item]);
    index.rebuild([]);

    expect(index.search('old'), isEmpty);
  });

  test(
    'background rebuild keeps search available while the index is built',
    () async {
      final titleMatch = track('one', title: 'Neon Lights', artist: 'Artist');
      final artistMatch = track(
        'two',
        title: 'Afterglow',
        artist: 'Neon Fields',
      );
      final index = MediaSearchIndex();

      final rebuilding = index.rebuildInBackground([titleMatch, artistMatch]);
      expect(index.search('neon'), [titleMatch, artistMatch]);
      await rebuilding;

      expect(index.search('neon'), [titleMatch, artistMatch]);
    },
  );
}
