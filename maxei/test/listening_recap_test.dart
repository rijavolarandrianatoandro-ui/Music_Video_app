import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/listening_recap.dart';
import 'package:maxei/src/media/listening_session.dart';
import 'package:maxei/src/media/media_item.dart';

void main() {
  final now = DateTime(2026, 11, 3, 12);

  ListeningSession session(
    String id,
    String mediaId,
    String title,
    String artist,
    DateTime startedAt,
    int listenedMilliseconds,
  ) => ListeningSession(
    id: id,
    mediaId: mediaId,
    title: title,
    artist: artist,
    startedAt: startedAt,
    listenedMilliseconds: listenedMilliseconds,
  );

  test('builds previous-month listening and favorite highlights', () {
    final favorite = MediaItem.stored(
      name: 'Night Drive.mp3',
      uri: Uri.parse('file:///night-drive.mp3'),
      size: 1024,
      kind: MediaKind.audio,
      title: 'Night Drive',
      artist: 'Nova',
    )..isFavorite = true;
    final history = [
      session(
        '1',
        favorite.id,
        favorite.title,
        favorite.artist,
        DateTime(2026, 10, 1, 21),
        180000,
      ),
      session(
        '2',
        favorite.id,
        favorite.title,
        favorite.artist,
        DateTime(2026, 10, 2, 21),
        120000,
      ),
      session(
        '3',
        'file:///other.mp3',
        'Daylight',
        'Mira',
        DateTime(2026, 10, 3, 10),
        60000,
      ),
      session(
        '4',
        'file:///outside-month.mp3',
        'Outside',
        'Nova',
        DateTime(2026, 11, 1, 10),
        300000,
      ),
    ];

    final recap = ListeningRecap.forPreviousMonth(history, [
      favorite,
    ], now: now);

    expect(recap.start, DateTime(2026, 10));
    expect(recap.sessions, hasLength(3));
    expect(recap.totalMilliseconds, 360000);
    expect(recap.uniqueTracks, 2);
    expect(recap.topTracks.first.title, 'Night Drive');
    expect(recap.topTracks.first.plays, 2);
    expect(recap.topArtist, 'Nova');
    expect(recap.topFavorite?.title, 'Night Drive');
    expect(recap.activeDays, 3);
    expect(recap.longestStreak, 3);
  });

  test('uses previous month listening as the comparison baseline', () {
    final history = [
      session('older', 'song', 'Song', 'Artist', DateTime(2026, 9, 15), 10000),
      session(
        'current',
        'song',
        'Song',
        'Artist',
        DateTime(2026, 10, 15),
        20000,
      ),
    ];

    final recap = ListeningRecap.forPreviousMonth(history, const [], now: now);

    expect(recap.previousMonthMilliseconds, 10000);
    expect(recap.totalMilliseconds, 20000);
  });
}
