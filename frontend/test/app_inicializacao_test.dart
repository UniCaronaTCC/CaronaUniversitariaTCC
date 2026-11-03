import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/home/conversas.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/inicializacao/tela_abertura.dart';
import 'package:uni_carona/main.dart';
import 'package:uni_carona/navigation/navegacao_principal.dart';
import 'package:uni_carona/services/auth_service.dart';

import 'avisos_caronas_solicitacoes_test.dart' as fixtures;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  for (final autenticado in [false, true]) {
    testWidgets(
      'destino correto somente apos concluir autenticado=$autenticado',
      (tester) async {
        final pendente = Completer<void>();
        var chamadas = 0;
        await fixtures.executar(tester, () async {
          await tester.pumpWidget(
            BuscaEuApp(
              inicializar: () async {
                chamadas++;
                await pendente.future;
                if (autenticado) {
                  AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa teste'};
                  AuthService.tokenUsuarioLogado = 'token-sintetico';
                }
              },
            ),
          );
          expect(find.byKey(const ValueKey('tela-abertura')), findsOneWidget);
          expect(find.byType(LoginTela), findsNothing);
          expect(find.byType(TelaInicial), findsNothing);
          pendente.complete();
          await tester.pumpAndSettle();
          expect(
            find.byType(autenticado ? TelaInicial : LoginTela),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('tela-abertura')), findsNothing);
          final contexto = tester.element(
            find.byType(autenticado ? TelaInicial : LoginTela),
          );
          expect(Navigator.canPop(contexto), isFalse);
          expect(chamadas, 1);
        }, (_) async => fixtures.resposta({'sucesso': true, 'dados': []}));
      },
    );
  }

  testWidgets('falha nao abre login nem limpa uma sessao por conta propria', (
    tester,
  ) async {
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa teste'};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
    await tester.pumpWidget(
      BuscaEuApp(inicializar: () async => throw StateError('Falha sintetica')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível iniciar'), findsOneWidget);
    expect(find.byType(LoginTela), findsNothing);
    expect(find.byType(TelaInicial), findsNothing);
    expect(AuthService.usuarioLogado?['id'], 7);
    expect(AuthService.tokenUsuarioLogado, 'token-sintetico');
  });

  testWidgets('rotas existentes continuam registradas sem outro Navigator', (
    tester,
  ) async {
    await tester.pumpWidget(BuscaEuApp(inicializar: () async {}));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final contexto = tester.element(find.byType(LoginTela));
    expect(app.routes!.keys, [
      NavegacaoPrincipal.rotaChat,
      NavegacaoPrincipal.rotaCaronas,
      NavegacaoPrincipal.rotaPerfil,
    ]);
    expect(
      app.routes![NavegacaoPrincipal.rotaChat]!(contexto),
      isA<ConversasTela>(),
    );
    expect(
      app.routes![NavegacaoPrincipal.rotaCaronas]!(contexto),
      isA<MinhasCaronasTela>(),
    );
    expect(
      app.routes![NavegacaoPrincipal.rotaPerfil]!(contexto),
      isA<PerfilTela>(),
    );
    expect(find.byType(Navigator), findsOneWidget);
    expect(find.byType(TelaAbertura), findsOneWidget);
    expect(find.byKey(const ValueKey('tela-abertura')), findsNothing);
  });
}
