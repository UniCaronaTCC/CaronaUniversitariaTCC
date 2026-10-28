import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/login.dart';

void main() {
  Future<void> preencher(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField).at(0),
      'usuario@example.test',
    );
    await tester.enterText(find.byType(TextField).at(1), 'senha-teste');
    await tester.ensureVisible(find.byKey(const ValueKey('entrar-login')));
  }

  testWidgets('excecao libera botao e permite tentar novamente', (
    tester,
  ) async {
    var chamadas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginTela(
          autenticar: (_, _) async {
            chamadas++;
            throw StateError('falha simulada');
          },
        ),
      ),
    );
    await preencher(tester);
    await tester.tap(find.byKey(const ValueKey('entrar-login')));
    await tester.pumpAndSettle();
    expect(find.text('Entrando...'), findsNothing);
    expect(
      find.text('Não foi possível entrar. Tente novamente'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('entrar-login')));
    await tester.pumpAndSettle();
    expect(chamadas, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('impede envio duplicado enquanto aguarda resultado', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    var chamadas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginTela(
          autenticar: (_, _) {
            chamadas++;
            return resposta.future;
          },
        ),
      ),
    );
    await preencher(tester);
    await tester.tap(find.byKey(const ValueKey('entrar-login')));
    await tester.pump();
    await tester.tap(find.text('Entrando...'));
    expect(chamadas, 1);
    resposta.complete({'sucesso': false, 'mensagem': 'Servidor indisponivel'});
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('resposta apos sair da tela nao atualiza widget descartado', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(home: LoginTela(autenticar: (_, _) => resposta.future)),
    );
    await preencher(tester);
    await tester.tap(find.byKey(const ValueKey('entrar-login')));
    await tester.pumpWidget(const SizedBox());
    resposta.complete({'sucesso': false, 'mensagem': 'Erro'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
