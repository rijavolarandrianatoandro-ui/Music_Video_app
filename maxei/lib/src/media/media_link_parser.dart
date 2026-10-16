import 'connectors/direct_file_connector.dart';
import 'connectors/facebook_connector.dart';
import 'connectors/instagram_connector.dart';
import 'connectors/youtube_connector.dart';
import 'media_link.dart';

class MediaLinkParser {
  static const _connectors = <MediaLinkConnector>[
    YouTubeConnector(),
    FacebookConnector(),
    InstagramConnector(),
    DirectFileConnector(),
  ];

  const MediaLinkParser();

  MediaLink parse(String input) {
    final text = input.trim();
    if (text.isEmpty) throw const FormatException('Saisissez un lien.');
    final candidate = Uri.tryParse(
      text.contains('://') ? text : 'https://$text',
    );
    if (candidate == null ||
        !{'http', 'https'}.contains(candidate.scheme.toLowerCase()) ||
        candidate.host.isEmpty) {
      throw const FormatException('Ce lien n’est pas une URL valide.');
    }
    for (final connector in _connectors) {
      final result = connector.parse(candidate);
      if (result != null) return result;
    }
    throw const FormatException(
      'Source non reconnue. Essayez YouTube, Facebook, Instagram ou un lien direct .mp3/.mp4.',
    );
  }
}
