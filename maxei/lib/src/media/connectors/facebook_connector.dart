import '../media_link.dart';

class FacebookConnector extends MediaLinkConnector {
  const FacebookConnector();

  static const _domains = {'facebook.com', 'fb.watch'};

  @override
  MediaLink? parse(Uri uri) {
    if (!hostMatches(uri.host, _domains)) return null;
    final segments = uri.pathSegments;
    final videoIndex = segments.indexOf('videos');
    final reelIndex = segments.indexOf('reel');
    final id = videoIndex >= 0 && videoIndex + 1 < segments.length
        ? segments[videoIndex + 1]
        : reelIndex >= 0 && reelIndex + 1 < segments.length
        ? segments[reelIndex + 1]
        : uri.queryParameters['v'];
    return MediaLink(
      platform: MediaPlatform.facebook,
      uri: uri,
      contentId: id?.isEmpty == true ? null : id,
    );
  }
}
