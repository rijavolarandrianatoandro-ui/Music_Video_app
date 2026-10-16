import '../media_link.dart';

class DirectFileConnector extends MediaLinkConnector {
  const DirectFileConnector();

  static const _extensions = {
    'aac',
    'aiff',
    'avi',
    'flac',
    'm4a',
    'm4v',
    'mkv',
    'mov',
    'mp3',
    'mp4',
    'mpeg',
    'mpg',
    'ogg',
    'opus',
    'wav',
    'webm',
    'wma',
  };

  @override
  MediaLink? parse(Uri uri) {
    final extension = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last.split('.').last.toLowerCase();
    if (!_extensions.contains(extension)) return null;
    return MediaLink(platform: MediaPlatform.directFile, uri: uri);
  }
}
