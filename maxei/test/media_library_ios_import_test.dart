import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/media_item.dart';
import 'package:maxei/src/media/media_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.maxei/ios_folder_media_import');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'imports copied audio and video metadata from the iOS folder picker',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'importFolder');
            return [
              {
                'name': 'song.mp3',
                'path': '/app/Media/song.mp3',
                'kind': 'audio',
                'size': 1024,
                'addedAtMs': 1790000000000,
              },
              {
                'name': 'clip.mp4',
                'path': '/app/Media/clip.mp4',
                'kind': 'video',
                'size': 4096,
                'addedAtMs': 1790000000000,
              },
            ];
          });

      final items = await MediaLibrary().importFiles();

      expect(items, hasLength(2));
      expect(items.map((item) => item.kind), [
        MediaKind.audio,
        MediaKind.video,
      ]);
      expect(items.first.uri, Uri.file('/app/Media/song.mp3'));
      expect(items.last.sizeBytes, 4096);
    },
  );

  test('surfaces invalid native folder import metadata', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => [
            {'name': 'invalid.mp3'},
          ],
        );

    await expectLater(
      MediaLibrary().importFiles(),
      throwsA(isA<FormatException>()),
    );
  });
}
