import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/login.dart';

void main() {
  testWidgets('exibe os campos principais da tela de login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginTela()));

    expect(find.text('ENTRAR'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Senha'), findsOneWidget);
    expect(find.text('Não tem uma conta? Cadastre-se'), findsOneWidget);
  });
}
