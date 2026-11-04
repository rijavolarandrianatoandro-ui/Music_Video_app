import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/media_item.dart';
import 'package:maxei/src/screens/media_library_screen.dart';

void main() {
  final older = MediaItem.stored(
    name: 'Bravo.mp4',
    uri: Uri.parse('file:///bravo.mp4'),
    size: 100,
    kind: MediaKind.video,
    title: 'Bravo',
    durationMs: 30000,
    addedAt: DateTime(2024),
  );
  final newer = MediaItem.stored(
    name: 'Alpha.mp4',
    uri: Uri.parse('file:///alpha.mp4'),
    size: 100,
    kind: MediaKind.video,
    title: 'Alpha',
    durationMs: 60000,
    addedAt: DateTime(2025),
  );
  final unknownDuration = MediaItem.stored(
    name: 'Unknown.mp4',
    uri: Uri.parse('file:///unknown.mp4'),
    size: 100,
    kind: MediaKind.video,
    title: 'Unknown',
    addedAt: DateTime(2023),
  );

  test('sorts audio and video collections by name, date, and duration', () {
    expect(sortMediaItems([older, newer], MediaSortOrder.name), [newer, older]);
    expect(sortMediaItems([older, newer], MediaSortOrder.newest), [
      newer,
      older,
    ]);
    expect(sortMediaItems([older, newer], MediaSortOrder.oldest), [
      older,
      newer,
    ]);
    expect(
      sortMediaItems([older, newer, unknownDuration], MediaSortOrder.longest),
      [newer, older, unknownDuration],
    );
  });

  test('gives legacy library entries a usable date for sorting', () {
    final legacyItem = MediaItem.fromJson({
      'name': 'Legacy.mp4',
      'path': '/legacy.mp4',
      'size': 100,
      'kind': 'video',
    });

    expect(legacyItem.addedAt.isAfter(DateTime(2020)), isTrue);
  });
}
