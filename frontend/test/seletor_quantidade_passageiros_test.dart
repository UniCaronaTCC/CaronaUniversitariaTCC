import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/seletor_quantidade_passageiros.dart';

void main() {
  testWidgets('permite escolher de um a quatro passageiros', (tester) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeletorQuantidadePassageiros(controller: controller),
        ),
      ),
    );

    final seletorInicial = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(seletorInicial.selected, {1});
    expect(find.text('Sem contar o motorista.'), findsOneWidget);

    await tester.tap(find.text('3'));
    await tester.pump();

    final seletorAtualizado = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(controller.text, '3');
    expect(seletorAtualizado.selected, {3});
  });
}
