import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/seletor_horario.dart';

void main() {
  testWidgets('abre o seletor e permite cancelar', (tester) async {
    TimeOfDay? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await SeletorHorario.abrir(
                context,
                titulo: 'Escolha o horário',
                horarioInicial: const TimeOfDay(hour: 19, minute: 30),
              );
            },
            child: const Text('ABRIR'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ABRIR'));
    await tester.pumpAndSettle();

    expect(find.text('Escolha o horário'), findsOneWidget);
    expect(find.text('CONFIRMAR'), findsOneWidget);

    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(resultado, isNull);
  });
}
