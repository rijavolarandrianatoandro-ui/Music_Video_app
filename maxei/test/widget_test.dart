// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maxei/src/maxei_app.dart';

void main() {
  testWidgets('Monthly listening recap can be skipped until next month', (
    WidgetTester tester,
  ) async {
    final today = DateTime.now();
    final recapMonth = DateTime(today.year, today.month - 1);
    final monthKey =
        '${recapMonth.year}-${recapMonth.month.toString().padLeft(2, '0')}';
    const deviceMediaChannel = MethodChannel('app.maxei/device_media');
    SharedPreferences.setMockInitialValues({
      'discovery.artistSetupCompleted': true,
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'maxei.library.listeningHistory.v1',
      '[{"id":"session-1","mediaId":"local-track-1","title":"Track","artist":"Artist","startedAt":"${DateTime(recapMonth.year, recapMonth.month, 4, 20).toIso8601String()}","listenedMilliseconds":65000}]',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceMediaChannel, (call) async {
          if (call.method == 'scanMedia') {
            return {
              'audioPermissionGranted': true,
              'videoPermissionGranted': true,
              'items': <Object>[],
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceMediaChannel, null),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaxeiApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Votre mois en musique est prêt'), findsOneWidget);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(preferences.getString('settings.dismissedRecapMonth'), monthKey);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaxeiApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Votre mois en musique est prêt'), findsNothing);
  });

  testWidgets('Three-tab media navigation and playlist creation work', (
    WidgetTester tester,
  ) async {
    const deviceMediaChannel = MethodChannel('app.maxei/device_media');
    SharedPreferences.setMockInitialValues({
      'discovery.artistSetupCompleted': true,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceMediaChannel, (call) async {
          if (call.method == 'scanMedia') {
            return {
              'audioPermissionGranted': true,
              'videoPermissionGranted': true,
              'items': <Object>[],
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceMediaChannel, null),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaxeiApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Votre collection'), findsOneWidget);

    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Récapitulatif musical'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Récapitulatif musical'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fichiers masqués'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Fichiers masqués'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun fichier masqué'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Récapitulatif musical'));
    await tester.pumpAndSettle();
    expect(find.text('Pas encore d’écoutes ce mois-ci.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morceaux'));
    await tester.pumpAndSettle();
    expect(find.text('Votre bibliothèque'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Votre collection'), findsOneWidget);

    await tester.tap(find.text('Vidéos').first);
    await tester.pumpAndSettle();
    expect(find.text('Bibliothèque vide.'), findsOneWidget);
    await tester.tap(find.byTooltip('Trier la bibliothèque'));
    await tester.pumpAndSettle();
    expect(find.text('Plus récent'), findsOneWidget);
    expect(find.text('Plus ancien'), findsOneWidget);
    expect(find.text('Plus long'), findsOneWidget);
    await tester.tap(find.text('Plus long'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Votre collection'), findsOneWidget);

    await tester.tap(find.text('Playlists').last);
    await tester.pumpAndSettle();
    expect(find.text('Créez votre première playlist'), findsOneWidget);

    await tester.tap(find.text('Créer une playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Favoris du soir');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(find.text('Favoris du soir'), findsOneWidget);
    await tester.tap(find.text('Favoris du soir'));
    await tester.pumpAndSettle();
    expect(find.text('0 titres'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Analyser un lien média'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://www.youtube.com/watch?v=abc123',
    );
    await tester.tap(find.text('Analyser le lien'));
    await tester.pumpAndSettle();
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Identifiant public : abc123'), findsOneWidget);
  });
}
