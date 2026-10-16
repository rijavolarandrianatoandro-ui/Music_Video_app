import '../media_link.dart';

class InstagramConnector extends MediaLinkConnector {
  const InstagramConnector();

  static const _domains = {'instagram.com'};
  static const _contentTypes = {'p', 'reel', 'reels', 'tv'};

  @override
  MediaLink? parse(Uri uri) {
    if (!hostMatches(uri.host, _domains)) return null;
    final segments = uri.pathSegments;
    final typeIndex = segments.indexWhere(_contentTypes.contains);
    final id = typeIndex >= 0 && typeIndex + 1 < segments.length
        ? segments[typeIndex + 1]
        : null;
    return MediaLink(
      platform: MediaPlatform.instagram,
      uri: uri,
      contentId: id?.isEmpty == true ? null : id,
    );
  }
}
