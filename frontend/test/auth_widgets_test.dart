import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/auth_widgets.dart';

void main() {
  testWidgets('capitalizacao configuravel sem afetar email e senha', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AuthCampoTexto(
                hint: 'Nome',
                icone: Icons.person,
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
              ),
              AuthCampoTexto(
                hint: 'Email',
                icone: Icons.email,
                controller: controller,
              ),
              AuthCampoTexto(
                hint: 'Senha',
                icone: Icons.lock,
                controller: controller,
                obscureText: true,
              ),
            ],
          ),
        ),
      ),
    );
    final campos = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(campos[0].textCapitalization, TextCapitalization.sentences);
    expect(campos[1].textCapitalization, TextCapitalization.none);
    expect(campos[2].textCapitalization, TextCapitalization.none);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

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
