import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/device_media_scanner.dart';
import 'package:maxei/src/media/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.maxei/device_media');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('parses video entries when audio is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'scanMedia');
          return {
            'audioPermissionGranted': false,
            'videoPermissionGranted': true,
            'items': [
              {
                'uri': 'content://media/external/video/media/7',
                'name': 'Weekend Drive.mp4',
                'title': 'Weekend Drive',
                'size': 2048,
                'durationMs': 12000,
                'dateAdded': 1735689600,
                'kind': 'video',
              },
            ],
          };
        });

    final result = await DeviceMediaScanner().scan();

    expect(result.audioPermissionGranted, isFalse);
    expect(result.videoPermissionGranted, isTrue);
    expect(result.items, hasLength(1));
    expect(result.items.single.kind, MediaKind.video);
    expect(result.items.single.title, 'Weekend Drive');
    expect(result.items.single.durationMs, 12000);
    expect(
      result.items.single.addedAt,
      DateTime.fromMillisecondsSinceEpoch(1735689600 * 1000),
    );
  });
}
