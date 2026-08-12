import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/dialogo_avaliacao.dart';

void main() {
  testWidgets('seleciona nota e comentario', (tester) async {
    DadosAvaliacao? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await mostrarDialogoAvaliacao(context, 'Maria');
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Avaliar Maria'), findsOneWidget);

    await tester.tap(find.byTooltip('5 estrelas'));
    await tester.enterText(find.byType(TextField), 'Muito pontual');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(resultado?.nota, 5);
    expect(resultado?.comentario, 'Muito pontual');
  });
}
