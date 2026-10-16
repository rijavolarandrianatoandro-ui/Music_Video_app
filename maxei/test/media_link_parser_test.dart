import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/media_link.dart';
import 'package:maxei/src/media/media_link_parser.dart';

void main() {
  const parser = MediaLinkParser();

  test('parses YouTube watch and short links', () {
    final watch = parser.parse('https://www.youtube.com/watch?v=abc123');
    final short = parser.parse('youtu.be/xyz789');

    expect(watch.platform, MediaPlatform.youtube);
    expect(watch.contentId, 'abc123');
    expect(short.contentId, 'xyz789');
  });

  test('recognizes Facebook and Instagram public URLs', () {
    final facebook = parser.parse('https://www.facebook.com/reel/12345');
    final instagram = parser.parse('https://www.instagram.com/reel/shortcode/');

    expect(facebook.platform, MediaPlatform.facebook);
    expect(facebook.contentId, '12345');
    expect(instagram.platform, MediaPlatform.instagram);
    expect(instagram.contentId, 'shortcode');
  });

  test('recognizes a direct media URL without claiming to download it', () {
    final link = parser.parse('https://media.example/music.flac?token=abc');

    expect(link.platform, MediaPlatform.directFile);
    expect(link.uri.queryParameters['token'], 'abc');
  });

  test('rejects malformed and unsupported URLs', () {
    expect(() => parser.parse(''), throwsFormatException);
    expect(
      () => parser.parse('https://example.com/page'),
      throwsFormatException,
    );
    expect(
      () => parser.parse('file:///private/video.mp4'),
      throwsFormatException,
    );
  });
}
