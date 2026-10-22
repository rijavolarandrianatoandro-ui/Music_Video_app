import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/media_item.dart';
import 'package:maxei/src/media/media_library.dart';
import 'package:maxei/src/media/media_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'restores media metadata and playlists from local preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = MediaLibrary();
      final lastPlayedAt = DateTime.utc(2026, 10, 22, 12);
      final item =
          MediaItem.downloaded(
              name: 'Artist - Track.mp3',
              path: '/app/media/track.mp3',
              size: 4096,
              kind: MediaKind.audio,
            )
            ..isFavorite = true
            ..playCount = 3
            ..lastPlayedAt = lastPlayedAt;
      final playlist = MediaPlaylist('Evening mix')..mediaIds.add(item.id);

      await library.save([item], [playlist]);
      final restored = await library.restore();

      expect(restored.items, hasLength(1));
      expect(restored.items.single.title, 'Track');
      expect(restored.items.single.isFavorite, isTrue);
      expect(restored.items.single.playCount, 3);
      expect(restored.items.single.lastPlayedAt, lastPlayedAt);
      expect(restored.playlists, hasLength(1));
      expect(restored.playlists.single.name, 'Evening mix');
      expect(restored.playlists.single.mediaIds, [item.id]);
    },
  );
}
