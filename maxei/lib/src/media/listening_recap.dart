import 'media_item.dart';
import 'listening_session.dart';

class TrackRecap {
  const TrackRecap({
    required this.mediaId,
    required this.title,
    required this.artist,
    required this.plays,
    required this.listenedMilliseconds,
    required this.isFavorite,
  });

  final String mediaId;
  final String title;
  final String artist;
  final int plays;
  final int listenedMilliseconds;
  final bool isFavorite;
}

class ListeningRecap {
  ListeningRecap({
    required this.start,
    required this.end,
    required this.sessions,
    required this.topTracks,
    required this.topArtist,
    required this.topFavorite,
    required this.activeDays,
    required this.longestStreak,
    required this.previousMonthMilliseconds,
  });

  final DateTime start;
  final DateTime end;
  final List<ListeningSession> sessions;
  final List<TrackRecap> topTracks;
  final String? topArtist;
  final TrackRecap? topFavorite;
  final int activeDays;
  final int longestStreak;
  final int previousMonthMilliseconds;

  int get totalMilliseconds => sessions.fold(
    0,
    (total, session) => total + session.listenedMilliseconds,
  );

  int get uniqueTracks =>
      sessions.map((session) => session.mediaId).toSet().length;

  static ListeningRecap forPreviousMonth(
    List<ListeningSession> history,
    List<MediaItem> library, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final thisMonth = DateTime(today.year, today.month);
    final start = DateTime(today.year, today.month - 1);
    final end = thisMonth;
    final previousStart = DateTime(start.year, start.month - 1);

    final sessions =
        history
            .where(
              (entry) =>
                  !entry.startedAt.isBefore(start) &&
                  entry.startedAt.isBefore(end),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final previousMilliseconds = history
        .where(
          (entry) =>
              !entry.startedAt.isBefore(previousStart) &&
              entry.startedAt.isBefore(start),
        )
        .fold<int>(0, (sum, entry) => sum + entry.listenedMilliseconds);
    final favoriteIds = {
      for (final item in library)
        if (item.kind == MediaKind.audio && item.isFavorite) item.id,
    };

    final trackStats = <String, _TrackStats>{};
    final artistPlays = <String, int>{};
    final activeDates = <DateTime>{};
    for (final session in sessions) {
      final stat = trackStats.putIfAbsent(
        session.mediaId,
        () => _TrackStats(
          mediaId: session.mediaId,
          title: session.title,
          artist: session.artist,
          isFavorite: favoriteIds.contains(session.mediaId),
        ),
      );
      stat.plays++;
      stat.listenedMilliseconds += session.listenedMilliseconds;
      final artistKey = session.artist.trim().toLowerCase();
      if (artistKey.isNotEmpty) {
        artistPlays.update(artistKey, (plays) => plays + 1, ifAbsent: () => 1);
      }
      activeDates.add(
        DateTime.utc(
          session.startedAt.year,
          session.startedAt.month,
          session.startedAt.day,
        ),
      );
    }

    final tracks = trackStats.values.map((stat) => stat.toRecap()).toList()
      ..sort((a, b) {
        final byPlays = b.plays.compareTo(a.plays);
        return byPlays != 0
            ? byPlays
            : b.listenedMilliseconds.compareTo(a.listenedMilliseconds);
      });
    final favoriteTracks = tracks.where((track) => track.isFavorite).toList();
    final topArtist = artistPlays.entries.isEmpty
        ? null
        : artistPlays.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return ListeningRecap(
      start: start,
      end: end,
      sessions: sessions,
      topTracks: tracks.take(5).toList(),
      topArtist: topArtist == null
          ? null
          : sessions
                .firstWhere(
                  (session) => session.artist.trim().toLowerCase() == topArtist,
                )
                .artist,
      topFavorite: favoriteTracks.isEmpty ? null : favoriteTracks.first,
      activeDays: activeDates.length,
      longestStreak: _longestStreak(activeDates),
      previousMonthMilliseconds: previousMilliseconds,
    );
  }

  static int _longestStreak(Set<DateTime> activeDates) {
    if (activeDates.isEmpty) return 0;
    final dates = activeDates.toList()..sort();
    var longest = 1;
    var current = 1;
    for (var index = 1; index < dates.length; index++) {
      if (dates[index].difference(dates[index - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }
}

class _TrackStats {
  _TrackStats({
    required this.mediaId,
    required this.title,
    required this.artist,
    required this.isFavorite,
  });

  final String mediaId;
  final String title;
  final String artist;
  final bool isFavorite;
  int plays = 0;
  int listenedMilliseconds = 0;

  TrackRecap toRecap() => TrackRecap(
    mediaId: mediaId,
    title: title,
    artist: artist,
    plays: plays,
    listenedMilliseconds: listenedMilliseconds,
    isFavorite: isFavorite,
  );
}
