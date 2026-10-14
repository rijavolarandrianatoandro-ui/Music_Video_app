// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:maxei/main.dart';

void main() {
  testWidgets('Chat suggestions and notebook navigation work', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Bonjour, que souhaitez-vous explorer ?'), findsOneWidget);

    await tester.tap(find.text('Trouver des idées'));
    await tester.pumpAndSettle();
    expect(
      find.text('Aide-moi à trouver des idées pour un nouveau projet.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Je peux vous aider à explorer cette idée.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes notebooks'));
    await tester.pumpAndSettle();
    expect(find.text('Vos sources, réunies.'), findsOneWidget);
  });
}
