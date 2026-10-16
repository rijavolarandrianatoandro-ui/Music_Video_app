enum MediaPlatform { youtube, facebook, instagram, directFile }

class MediaLink {
  const MediaLink({required this.platform, required this.uri, this.contentId});

  final MediaPlatform platform;
  final Uri uri;
  final String? contentId;

  String get platformName => switch (platform) {
    MediaPlatform.youtube => 'YouTube',
    MediaPlatform.facebook => 'Facebook',
    MediaPlatform.instagram => 'Instagram',
    MediaPlatform.directFile => 'Fichier média direct',
  };
}

abstract class MediaLinkConnector {
  const MediaLinkConnector();

  MediaLink? parse(Uri uri);

  bool hostMatches(String host, Set<String> domains) {
    final normalizedHost = host.toLowerCase();
    return domains.any(
      (domain) =>
          normalizedHost == domain || normalizedHost.endsWith('.$domain'),
    );
  }
}
