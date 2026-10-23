// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maxei/src/maxei_app.dart';

void main() {
  testWidgets('Three-tab media navigation and playlist creation work', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaxeiApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('La musique.\nÀ votre façon.'), findsOneWidget);

    await tester.tap(find.text('Morceaux'));
    await tester.pumpAndSettle();
    expect(find.text('Votre bibliothèque'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('La musique.\nÀ votre façon.'), findsOneWidget);

    await tester.tap(find.text('Vidéos').first);
    await tester.pumpAndSettle();
    expect(find.text('Votre collection commence ici.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('La musique.\nÀ votre façon.'), findsOneWidget);

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
