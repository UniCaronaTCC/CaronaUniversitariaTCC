import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/cadastro.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/services/auth_service.dart';

import 'atalhos_home_test.dart' as fixtures;

void main() {
  const entrar = ValueKey('entrar-login');
  const email = ValueKey('email-login');
  const senha = ValueKey('senha-login');
  const sucesso = {
    'sucesso': true,
    'dados': {
      'mensagem': 'Login realizado',
      'usuario': {'nome': 'Pessoa'},
    },
  };
  const falha = {'sucesso': false, 'mensagem': 'Senha incorreta'};

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  Future<void> abrir(
    WidgetTester tester,
    Future<Map<String, dynamic>> Function(String, String) autenticar, {
    GlobalKey<NavigatorState>? navigator,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorKey: navigator,
        home: LoginTela(autenticar: autenticar),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(email), 'usuario@exemplo.test');
    await tester.enterText(find.byKey(senha), 'senha-simulada');
    await tester.ensureVisible(find.byKey(entrar));
  }

  VoidCallback? link(WidgetTester tester, String texto) => tester
      .widget<TextButton>(find.widgetWithText(TextButton, texto))
      .onPressed;

  Future<void> transicao(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  List<bool> pedidosAutofill(WidgetTester tester) => tester.testTextInput.log
      .where((call) => call.method == 'TextInput.finishAutofillContext')
      .map((call) => call.arguments as bool)
      .toList();

  for (final texto in ['Criar conta', 'Esqueceu sua senha?']) {
    testWidgets('callback antigo de $texto nao abre rota durante login', (
      tester,
    ) async {
      final resposta = Completer<Map<String, dynamic>>();
      var chamadas = 0;
      await abrir(tester, (_, _) {
        chamadas++;
        return resposta.future;
      });
      final navegar = link(tester, texto)!;
      final enviar = tester
          .widget<ElevatedButton>(find.byKey(entrar))
          .onPressed!;
      enviar();
      navegar();
      enviar();
      await tester.pump();
      expect(chamadas, 1);
      expect(find.byType(LoginTela), findsOneWidget);
      expect(find.byType(CadastroTela), findsNothing);
      expect(find.byType(EsqueciSenhaTela), findsNothing);
      for (final rotulo in ['Criar conta', 'Esqueceu sua senha?']) {
        expect(link(tester, rotulo), isNull);
      }
      for (final chave in [email, senha]) {
        expect(tester.widget<TextField>(find.byKey(chave)).enabled, isFalse);
      }
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(senha),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      resposta.complete(falha);
      await tester.pumpAndSettle();
      expect(link(tester, texto), isNotNull);
      expect(tester.widget<TextField>(find.byKey(email)).enabled, isTrue);
      expect(tester.widget<TextField>(find.byKey(senha)).enabled, isTrue);
      expect(
        tester.widget<TextField>(find.byKey(senha)).controller!.text,
        'senha-simulada',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'toques rapidos em $texto nao duplicam rotas nem iniciam login oculto',
      (tester) async {
        var chamadas = 0;
        final navigator = GlobalKey<NavigatorState>();
        await abrir(tester, (_, _) async {
          chamadas++;
          return falha;
        }, navigator: navigator);
        final navegar = link(tester, texto)!;
        final enviar = tester
            .widget<ElevatedButton>(find.byKey(entrar))
            .onPressed!;
        navegar();
        navegar();
        enviar();
        await tester.pumpAndSettle();
        expect(chamadas, 0);
        expect(
          find.byType(texto == 'Criar conta' ? CadastroTela : EsqueciSenhaTela),
          findsOneWidget,
        );
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(LoginTela), findsOneWidget);
        expect(navigator.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final destino in ['cadastro', 'recuperacao']) {
    for (final resultado in ['sucesso', 'falha', 'excecao']) {
      testWidgets('resposta tardia $resultado nao interfere em $destino', (
        tester,
      ) async {
        final resposta = Completer<Map<String, dynamic>>();
        final navigator = GlobalKey<NavigatorState>();
        await fixtures.executar(() async {
          await abrir(tester, (_, _) => resposta.future, navigator: navigator);
          await tester.tap(find.byKey(entrar));
          await tester.pump();
          // Uma navegacao externa ainda pode cobrir a rota de login.
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => destino == 'cadastro'
                  ? const CadastroTela()
                  : const EsqueciSenhaTela(),
            ),
          );
          await transicao(tester);
          tester.testTextInput.log.clear();
          AuthService.tokenUsuarioLogado = 'sessao-preservada';
          if (resultado == 'excecao') {
            resposta.completeError(StateError('Falha de login tardia'));
          } else {
            resposta.complete(resultado == 'sucesso' ? sucesso : falha);
          }
          await tester.pumpAndSettle();
          expect(
            find.byType(
              destino == 'cadastro' ? CadastroTela : EsqueciSenhaTela,
            ),
            findsOneWidget,
          );
          expect(find.byType(TelaInicial), findsNothing);
          expect(find.text('Senha incorreta'), findsNothing);
          expect(
            find.text('Não foi possível entrar. Tente novamente'),
            findsNothing,
          );
          expect(pedidosAutofill(tester), isNot(contains(true)));
          expect(AuthService.tokenUsuarioLogado, 'sessao-preservada');
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(
            tester.widget<ElevatedButton>(find.byKey(entrar)).onPressed,
            isNotNull,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      });
    }
  }

  for (final resultado in ['abandono', 'falha', 'excecao']) {
    testWidgets('autofill nao solicita salvar em $resultado', (tester) async {
      final resposta = Completer<Map<String, dynamic>>();
      await abrir(tester, (_, _) => resposta.future);
      tester.testTextInput.log.clear();
      if (resultado != 'abandono') {
        await tester.tap(find.byKey(entrar));
        await tester.pump();
        if (resultado == 'excecao') {
          resposta.completeError(StateError('Falha simulada'));
        } else {
          resposta.complete(falha);
        }
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(find.byKey(email)).enabled, isTrue);
        expect(tester.widget<TextField>(find.byKey(senha)).enabled, isTrue);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(pedidosAutofill(tester), [false]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sucesso solicita salvar uma vez e continua para Home', (
    tester,
  ) async {
    await fixtures.executar(() async {
      final resposta = Completer<Map<String, dynamic>>();
      await abrir(tester, (_, _) => resposta.future);
      final enviar = tester
          .widget<ElevatedButton>(find.byKey(entrar))
          .onPressed!;
      tester.testTextInput.log.clear();
      enviar();
      enviar();
      await tester.pump();
      resposta.complete(sucesso);
      await tester.pumpAndSettle();
      expect(pedidosAutofill(tester).where((salvar) => salvar).length, 1);
      expect(find.byType(TelaInicial), findsOneWidget);
      expect(find.byType(LoginTela), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  for (final resultado in ['sucesso', 'falha', 'excecao']) {
    testWidgets(
      'resposta $resultado apos descarte nao navega nem salva autofill',
      (tester) async {
        final resposta = Completer<Map<String, dynamic>>();
        await abrir(tester, (_, _) => resposta.future);
        await tester.tap(find.byKey(entrar));
        await tester.pump();
        tester.testTextInput.log.clear();
        await tester.pumpWidget(const SizedBox());
        if (resultado == 'excecao') {
          resposta.completeError(StateError('Falha simulada'));
        } else {
          resposta.complete(resultado == 'sucesso' ? sucesso : falha);
        }
        await tester.pumpAndSettle();
        expect(pedidosAutofill(tester), [false]);
        expect(find.byType(TelaInicial), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('nova tentativa apos falha salva apenas quando aprovada', (
    tester,
  ) async {
    await fixtures.executar(() async {
      var chamadas = 0;
      await abrir(tester, (_, _) async => ++chamadas == 1 ? falha : sucesso);
      tester.testTextInput.log.clear();
      await tester.tap(find.byKey(entrar));
      await tester.pumpAndSettle();
      expect(find.text('Senha incorreta'), findsOneWidget);
      expect(pedidosAutofill(tester), isNot(contains(true)));
      expect(link(tester, 'Criar conta'), isNotNull);
      await tester.tap(find.byKey(entrar));
      await tester.pumpAndSettle();
      expect(chamadas, 2);
      expect(pedidosAutofill(tester).where((salvar) => salvar).length, 1);
      expect(find.byType(TelaInicial), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets(
    'callback de entrar nao reenvia apos iniciar transicao para Home',
    (tester) async {
      await fixtures.executar(() async {
        final resposta = Completer<Map<String, dynamic>>();
        var chamadas = 0;
        await abrir(tester, (_, _) {
          chamadas++;
          return resposta.future;
        });
        final enviar = tester
            .widget<ElevatedButton>(find.byKey(entrar))
            .onPressed!;
        enviar();
        await tester.pump();
        resposta.complete(sucesso);
        await tester.pump();
        enviar();
        await tester.pumpAndSettle();
        expect(chamadas, 1);
        expect(find.byType(TelaInicial), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets('resposta incompleta nao solicita salvar credenciais', (
    tester,
  ) async {
    await abrir(tester, (_, _) async => {'sucesso': true, 'dados': {}});
    tester.testTextInput.log.clear();
    await tester.tap(find.byKey(entrar));
    await tester.pumpAndSettle();
    expect(find.byType(LoginTela), findsOneWidget);
    expect(
      find.text('Não foi possível entrar. Tente novamente'),
      findsOneWidget,
    );
    expect(pedidosAutofill(tester), isNot(contains(true)));
    expect(tester.takeException(), isNull);
  });
}
