import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surco/ui/update_dialog.dart';

void main() {
  testWidgets('"Ver" en el aviso abre el diálogo de actualización', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => checkForUpdate(
                context,
                fetch: () async => (version: '99.0.0', notes: 'Novedades', apks: const <String, String>{}),
              ),
              child: const Text('buscar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Surco 99.0.0 está disponible.'), findsOneWidget);
    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.text('Actualizar'), findsOneWidget);
  });

  test('notas del release sin Markdown', () {
    expect(
      plainNotes('### Agregado\n- Guarda en `Music/Surco`.\n- **Ecualizador**'),
      'Agregado\n• Guarda en Music/Surco.\n• Ecualizador',
    );
    expect(plainNotes('  '), 'Versión nueva disponible.');
  });
}
