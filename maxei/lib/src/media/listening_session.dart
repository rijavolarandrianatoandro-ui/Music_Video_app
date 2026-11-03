class ListeningSession {
  const ListeningSession({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.artist,
    required this.startedAt,
    required this.listenedMilliseconds,
  });

  final String id;
  final String mediaId;
  final String title;
  final String artist;
  final DateTime startedAt;
  final int listenedMilliseconds;

  ListeningSession copyWith({int? listenedMilliseconds}) => ListeningSession(
    id: id,
    mediaId: mediaId,
    title: title,
    artist: artist,
    startedAt: startedAt,
    listenedMilliseconds: listenedMilliseconds ?? this.listenedMilliseconds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaId': mediaId,
    'title': title,
    'artist': artist,
    'startedAt': startedAt.toIso8601String(),
    'listenedMilliseconds': listenedMilliseconds,
  };

  factory ListeningSession.fromJson(Map<String, dynamic> json) =>
      ListeningSession(
        id: json['id'] as String,
        mediaId: json['mediaId'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        listenedMilliseconds:
            (json['listenedMilliseconds'] as num?)?.toInt() ?? 0,
      );
}
