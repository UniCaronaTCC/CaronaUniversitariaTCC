import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/services/auth_service.dart';

void main() {
  tearDown(AuthService.sair);

  testWidgets('exibe os dados do usuário e permite sair', (tester) async {
    AuthService.tokenUsuarioLogado = 'token-teste';
    AuthService.usuarioLogado = {
      'id': 1,
      'nome': 'João',
      'email': 'joao@email.com',
    };

    await tester.pumpWidget(const MaterialApp(home: PerfilTela()));

    expect(find.text('João'), findsNWidgets(2));
    expect(find.text('joao@email.com'), findsNWidgets(2));
    expect(find.text('Sair'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginTela), findsOneWidget);
    expect(AuthService.estaLogado, isFalse);
  });
}
