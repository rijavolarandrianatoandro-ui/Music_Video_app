import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maxei/src/media/youtube_catalog_service.dart';
import 'package:maxei/src/media/youtube_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('searches through the Worker and parses official metadata', () async {
    final service = YoutubeCatalogService(
      workerUrl: 'https://catalog.example.workers.dev',
      client: MockClient((request) async {
        expect(request.url.path, '/api/search');
        expect(request.url.queryParameters['q'], 'ambient study');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': {'videoId': 'abcdefghijk'},
                'snippet': {
                  'title': 'Quiet Focus',
                  'channelTitle': 'Maxei Records',
                  'publishedAt': '2025-01-01T00:00:00Z',
                  'thumbnails': {
                    'medium': {
                      'url': 'https://i.ytimg.com/vi/abcdefghijk/mq.jpg',
                    },
                  },
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final videos = await service.search(' ambient study ');

    expect(videos, hasLength(1));
    expect(videos.single, isA<YoutubeVideo>());
    expect(videos.single.id, 'abcdefghijk');
    expect(videos.single.title, 'Quiet Focus');
    expect(videos.single.youtubeUri.toString(), contains('v=abcdefghijk'));
    service.dispose();
  });

  test('rejects invalid Worker URLs and query lengths', () async {
    final service = YoutubeCatalogService(
      workerUrl: 'http://catalog.example.workers.dev',
    );

    await expectLater(service.search('music'), throwsA(isA<StateError>()));
    await expectLater(service.search('a'), throwsA(isA<FormatException>()));
    service.dispose();
  });

  test(
    'requests regional charts using only the selected country code',
    () async {
      final service = YoutubeCatalogService(
        workerUrl: 'https://catalog.example.workers.dev',
        client: MockClient((request) async {
          expect(request.url.path, '/api/trending');
          expect(request.url.queryParameters, {'region': 'MG'});
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );

      expect(await service.loadRegionalTrends('mg'), isEmpty);
      await expectLater(
        service.loadRegionalTrends('XXX'),
        throwsA(isA<FormatException>()),
      );
      service.dispose();
    },
  );

  test('favorites persist only validated video IDs', () async {
    final service = YoutubeCatalogService(
      workerUrl: 'https://catalog.example.workers.dev',
    );
    await service.setFavorite('abcdefghijk', true);
    await expectLater(
      service.setFavorite('invalid-id', true),
      throwsA(isA<FormatException>()),
    );

    expect(await service.favoriteIds(), {'abcdefghijk'});
    await service.setFavorite('abcdefghijk', false);
    expect(await service.favoriteIds(), isEmpty);
    service.dispose();
  });
}
