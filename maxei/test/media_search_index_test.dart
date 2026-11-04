import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/media_item.dart';
import 'package:maxei/src/media/media_search_index.dart';

void main() {
  MediaItem track(
    String id, {
    required String title,
    required String artist,
    String album = '',
    MediaKind kind = MediaKind.audio,
  }) => MediaItem.stored(
    name: '$title.${kind == MediaKind.audio ? 'mp3' : 'mp4'}',
    uri: Uri.parse('file:///$id.${kind == MediaKind.audio ? 'mp3' : 'mp4'}'),
    size: 1024,
    kind: kind,
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

  test('finds scanned videos by title and filename', () {
    final video = track(
      'video',
      title: 'Weekend Drive',
      artist: 'Fichier local',
      kind: MediaKind.video,
    );
    final index = MediaSearchIndex()..rebuild([video]);

    expect(index.search('weekend'), [video]);
    expect(index.search('mp4'), [video]);
  });

  test('marks only audio shorter than ten seconds as hidden', () {
    final shortTrack = MediaItem.stored(
      name: 'Short.mp3',
      uri: Uri.parse('file:///short.mp3'),
      size: 1024,
      kind: MediaKind.audio,
      durationMs: 9999,
    );
    final boundaryTrack = MediaItem.stored(
      name: 'Boundary.mp3',
      uri: Uri.parse('file:///boundary.mp3'),
      size: 1024,
      kind: MediaKind.audio,
      durationMs: 10000,
    );
    final shortVideo = MediaItem.stored(
      name: 'Short.mp4',
      uri: Uri.parse('file:///short.mp4'),
      size: 1024,
      kind: MediaKind.video,
      durationMs: 5000,
    );

    expect(shortTrack.isShortAudio, isTrue);
    expect(boundaryTrack.isShortAudio, isFalse);
    expect(shortVideo.isShortAudio, isFalse);
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
