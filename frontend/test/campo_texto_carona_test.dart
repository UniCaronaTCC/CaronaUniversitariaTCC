import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/campo_texto_carona.dart';

void main() {
  testWidgets('aceita caracteres acentuados em campos de texto', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoTextoCarona(
            label: 'Endereço',
            icone: Icons.location_on_outlined,
            controller: controller,
            keyboardType: TextInputType.streetAddress,
          ),
        ),
      ),
    );

    const texto = 'São João, ação, avó, você, açúcar';
    await tester.enterText(find.byType(TextField), texto);

    expect(controller.text, texto);

    controller.dispose();
  });
}
