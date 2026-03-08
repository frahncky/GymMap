import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymmap/main.dart';

void main() {
  testWidgets('renders collaborative gym experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(showMap: false));
    await tester.pumpAndSettle();

    expect(find.text('GymMap'), findsOneWidget);
    expect(find.text('Mapa desativado no modo de teste'), findsOneWidget);
    expect(find.textContaining('Toque no marcador'), findsNothing);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.textContaining('Publicidade:'), findsOneWidget);
    expect(find.text('Enviar relato colaborativo'), findsNothing);
  });
}
