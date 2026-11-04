import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/screens/artist_selection_dialog.dart';

void main() {
  testWidgets('requires exactly five choices and returns local artist ids', (
    tester,
  ) async {
    List<String>? result;
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<List<String>>(
                  context: context,
                  builder: (_) =>
                      const ArtistSelectionDialog(initialSelection: []),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('0 sur 5 sélectionnés'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Enregistrer'),
          )
          .onPressed,
      isNull,
    );

    for (final artistId in [
      'taylor-swift',
      'the-weeknd',
      'bad-bunny',
      'drake',
      'billie-eilish',
    ]) {
      await tester.tap(find.byKey(ValueKey('artist-$artistId')));
      await tester.pump();
    }

    expect(find.text('5 sur 5 sélectionnés'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(result, hasLength(5));
    expect(result, contains('taylor-swift'));
    expect(tester.takeException(), isNull);
  });
}
