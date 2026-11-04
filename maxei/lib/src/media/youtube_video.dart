class YoutubeVideo {
  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.channelTitle,
    this.thumbnailUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String channelTitle;
  final Uri? thumbnailUrl;
  final DateTime? publishedAt;

  factory YoutubeVideo.fromJson(Map<String, Object?> json) {
    final rawId = json['id'];
    final id = rawId is String
        ? rawId
        : rawId is Map<String, Object?>
        ? rawId['videoId']
        : null;
    final snippet = json['snippet'];
    if (id is! String || !_isValidVideoId(id) || snippet is! Map) {
      throw const FormatException('Résultat YouTube invalide.');
    }

    final title = snippet['title'];
    final channelTitle = snippet['channelTitle'];
    final publishedAt = snippet['publishedAt'];
    final thumbnails = snippet['thumbnails'];
    final medium = thumbnails is Map ? thumbnails['medium'] : null;
    final rawThumbnail = medium is Map ? medium['url'] : null;
    final thumbnail = rawThumbnail is String
        ? Uri.tryParse(rawThumbnail)
        : null;
    final isYoutubeThumbnail =
        thumbnail?.scheme == 'https' &&
        (thumbnail!.host == 'ytimg.com' ||
            thumbnail.host.endsWith('.ytimg.com'));

    return YoutubeVideo(
      id: id,
      title: title is String && title.isNotEmpty ? title : 'Vidéo YouTube',
      channelTitle: channelTitle is String ? channelTitle : '',
      thumbnailUrl: isYoutubeThumbnail ? thumbnail : null,
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)
          : null,
    );
  }

  Uri get youtubeUri => Uri.https('www.youtube.com', '/watch', {'v': id});

  static bool _isValidVideoId(String id) =>
      RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
}
