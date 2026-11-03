import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/lyrics_parser.dart';

void main() {
  test('parses and sorts LRC timestamps including repeated tags', () {
    final lines = parseLyrics('[00:02.25]Second\n[00:01.5][00:03.00]First');

    expect(lines.map((line) => (line.at, line.text)).toList(), [
      (const Duration(milliseconds: 1500), 'First'),
      (const Duration(milliseconds: 2250), 'Second'),
      (const Duration(seconds: 3), 'First'),
    ]);
  });

  test('keeps plain embedded lyrics without inventing timestamps', () {
    final lines = parseLyrics('Verse one\n\nVerse two');

    expect(lines.map((line) => line.text), ['Verse one', 'Verse two']);
    expect(lines.every((line) => line.at == null), isTrue);
  });
}
