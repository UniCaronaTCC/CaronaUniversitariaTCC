import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/auth_widgets.dart';

void main() {
  testWidgets('mostra e oculta a senha', (tester) async {
    final controller = TextEditingController(text: 'senha123');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthCampoTexto(
            hint: 'Senha',
            icone: Icons.lock,
            controller: controller,
            obscureText: true,
          ),
        ),
      ),
    );

    TextField campoSenha() => tester.widget<TextField>(find.byType(TextField));

    expect(campoSenha().obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();

    expect(campoSenha().obscureText, isFalse);

    await tester.tap(find.byTooltip('Ocultar senha'));
    await tester.pump();

    expect(campoSenha().obscureText, isTrue);

    controller.dispose();
  });
}
