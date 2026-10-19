import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/core/widgets/dialog_text_controllers.dart';

void main() {
  testWidgets('closing the dialog keeps the fields alive until it is gone', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder:
                        (dialogContext) => DialogTextControllers(
                          initialTexts: const ['inicial'],
                          builder:
                              (context, controllers) => AlertDialog(
                                content: TextField(
                                  controller: controllers.single,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(
                                          dialogContext,
                                          controllers.single.text,
                                        ),
                                    child: const Text('ok'),
                                  ),
                                ],
                              ),
                        ),
                  );
                },
                child: const Text('abrir'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('inicial'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'senha');
    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, 'senha');
    expect(find.byType(TextField), findsNothing);
  });
}
