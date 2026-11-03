import 'media_item.dart';
import 'media_lyrics_stub.dart'
    if (dart.library.io) 'media_lyrics_io.dart'
    as implementation;

Future<String?> readEmbeddedLyrics(MediaItem item) =>
    implementation.readEmbeddedLyrics(item);
