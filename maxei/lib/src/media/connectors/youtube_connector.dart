import '../media_link.dart';

class YouTubeConnector extends MediaLinkConnector {
  const YouTubeConnector();

  static const _domains = {'youtube.com', 'youtube-nocookie.com', 'youtu.be'};

  @override
  MediaLink? parse(Uri uri) {
    if (!hostMatches(uri.host, _domains)) return null;

    String? id = uri.queryParameters['v'];
    final segments = uri.pathSegments;
    if (id == null && uri.host.toLowerCase() == 'youtu.be') {
      id = segments.isEmpty ? null : segments.first;
    }
    if (id == null &&
        segments.length > 1 &&
        const {'embed', 'live', 'shorts', 'v'}.contains(segments.first)) {
      id = segments[1];
    }
    return MediaLink(
      platform: MediaPlatform.youtube,
      uri: uri,
      contentId: id?.isEmpty == true ? null : id,
    );
  }
}
