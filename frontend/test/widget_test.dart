import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/login.dart';

void main() {
  testWidgets('exibe os campos principais da tela de login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginTela()));

    expect(find.text('Entre na sua conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Seu e-mail'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Sua senha'), findsOneWidget);
    expect(find.byKey(const ValueKey('logo-login')), findsOneWidget);
    expect(find.text('Esqueceu sua senha?'), findsOneWidget);
    expect(find.text('Ainda não tem uma conta?'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });
}
