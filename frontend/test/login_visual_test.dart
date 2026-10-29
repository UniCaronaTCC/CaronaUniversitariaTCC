import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/cadastro.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/auth_widgets.dart';

import 'atalhos_home_test.dart' as fixtures;

void main() {
  const email = ValueKey('email-login');
  const senha = ValueKey('senha-login');
  const entrar = ValueKey('entrar-login');

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
    WidgetTester tester, {
    LoginTela tela = const LoginTela(),
    double escala = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: tela,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('logo oficial carrega e login nao usa painel compartilhado', (
    tester,
  ) async {
    await abrir(tester);
    final imagem = tester.widget<Image>(
      find.byKey(const ValueKey('logo-login')),
    );
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/imagens/icone_buscaeu.png',
    );
    expect(
      (await rootBundle.load('assets/imagens/icone_buscaeu.png')).lengthInBytes,
      greaterThan(0),
    );
    await tester.runAsync(() async {
      final carregada = Completer<void>();
      final stream = imagem.image.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((info, _) {
        expect(info.image.width, 1024);
        expect(info.image.height, 1024);
        info.dispose();
        carregada.complete();
      }, onError: carregada.completeError);
      stream.addListener(listener);
      try {
        await carregada.future.timeout(const Duration(seconds: 5));
      } finally {
        stream.removeListener(listener);
      }
    });
    expect(find.byType(AuthCard), findsNothing);
    expect(find.text('BuscaEu', findRichText: true), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('campos possuem teclado preenchimento e foco adequados', (
    tester,
  ) async {
    await abrir(tester);
    final campoEmail = tester.widget<TextField>(find.byKey(email));
    final campoSenha = tester.widget<TextField>(find.byKey(senha));
    expect(campoEmail.keyboardType, TextInputType.emailAddress);
    expect(campoEmail.textInputAction, TextInputAction.next);
    expect(campoEmail.autofillHints, contains(AutofillHints.username));
    expect(campoSenha.textInputAction, TextInputAction.done);
    expect(campoSenha.autofillHints, contains(AutofillHints.password));
    expect(campoSenha.enableSuggestions, isFalse);
    await tester.showKeyboard(find.byKey(email));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(senha),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('mostrar e ocultar senha preserva texto e selecao', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(find.byKey(senha), 'senha-teste');
    final controller = tester.widget<TextField>(find.byKey(senha)).controller!;
    controller.selection = const TextSelection.collapsed(offset: 4);
    for (final tooltip in ['Mostrar senha', 'Ocultar senha']) {
      await tester.ensureVisible(find.byTooltip(tooltip));
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      final campo = tester.widget<TextField>(find.byKey(senha));
      expect(campo.obscureText, tooltip == 'Ocultar senha');
      expect(controller.text, 'senha-teste');
      expect(controller.selection.baseOffset, 4);
    }
    expect(tester.takeException(), isNull);
  });

  for (final campoVazio in ['email', 'senha']) {
    testWidgets('campo vazio $campoVazio impede envio e mostra aviso', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        tela: LoginTela(
          autenticar: (_, _) async {
            chamadas++;
            return {'sucesso': false};
          },
        ),
      );
      if (campoVazio == 'senha') {
        await tester.enterText(find.byKey(email), 'usuario@exemplo.com');
      }
      await tester.ensureVisible(find.byKey(entrar));
      await tester.tap(find.byKey(entrar));
      await tester.pumpAndSettle();
      expect(chamadas, 0);
      expect(
        find.text(
          campoVazio == 'email' ? 'Informe seu e-mail' : 'Informe sua senha',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'teclado e botao compartilham bloqueio e falha preserva os dados',
    (tester) async {
      final resposta = Completer<Map<String, dynamic>>();
      var chamadas = 0;
      await abrir(
        tester,
        tela: LoginTela(
          autenticar: (e, s) {
            chamadas++;
            expect(e, 'usuario@exemplo.com');
            expect(s, ' senha-teste ');
            return resposta.future;
          },
        ),
      );
      await tester.enterText(find.byKey(email), ' usuario@exemplo.com ');
      await tester.enterText(find.byKey(senha), ' senha-teste ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      final botao = tester.widget<ElevatedButton>(find.byKey(entrar));
      expect(botao.onPressed, isNull);
      expect(find.text('Entrando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      tester.widget<TextField>(find.byKey(senha)).onSubmitted!(' senha-teste ');
      expect(chamadas, 1);
      resposta.complete({
        'sucesso': false,
        'mensagem': 'E-mail ou senha incorretos',
      });
      await tester.pumpAndSettle();
      expect(find.text('E-mail ou senha incorretos'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(email)).controller!.text,
        ' usuario@exemplo.com ',
      );
      expect(
        tester.widget<TextField>(find.byKey(senha)).controller!.text,
        ' senha-teste ',
      );
      expect(
        tester.widget<ElevatedButton>(find.byKey(entrar)).onPressed,
        isNotNull,
      );
    },
  );

  for (final destino in ['Criar conta', 'Esqueceu sua senha?']) {
    testWidgets('$destino abre tela existente e voltar preserva formulario', (
      tester,
    ) async {
      await abrir(tester);
      await tester.enterText(find.byKey(email), 'usuario@exemplo.com');
      await tester.enterText(find.byKey(senha), 'senha-teste');
      await tester.ensureVisible(find.text(destino));
      await tester.tap(find.text(destino));
      await tester.pumpAndSettle();
      expect(
        find.byType(destino == 'Criar conta' ? CadastroTela : EsqueciSenhaTela),
        findsOneWidget,
      );
      expect(find.byType(AuthCard), findsNothing);
      Navigator.of(
        tester.element(
          find.byType(
            destino == 'Criar conta' ? CadastroTela : EsqueciSenhaTela,
          ),
        ),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(email)).controller!.text,
        'usuario@exemplo.com',
      );
      expect(
        tester.widget<TextField>(find.byKey(senha)).controller!.text,
        'senha-teste',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'sucesso substitui login pela Home mantendo navegacao existente',
    (tester) async {
      await fixtures.executar(() async {
        await abrir(
          tester,
          tela: LoginTela(
            autenticar: (_, _) async => {
              'sucesso': true,
              'dados': {
                'mensagem': 'Login feito com sucesso',
                'usuario': {'nome': 'João'},
              },
            },
          ),
        );
        await tester.enterText(find.byKey(email), 'usuario@exemplo.com');
        await tester.enterText(find.byKey(senha), 'senha-teste');
        await tester.ensureVisible(find.byKey(entrar));
        await tester.tap(find.byKey(entrar));
        await tester.pumpAndSettle();
        expect(find.byType(LoginTela), findsNothing);
        expect(find.byType(TelaInicial), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(TelaInicial))).canPop(),
          isFalse,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  for (final tamanho in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(800, 600),
  ]) {
    for (final escala in [1.0, 2.0, 3.0]) {
      for (final teclado in [0.0, 300.0]) {
        testWidgets('layout ${tamanho.width} fonte $escala teclado $teclado', (
          tester,
        ) async {
          tester.view.physicalSize = tamanho;
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = FakeViewPadding(bottom: teclado);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await abrir(tester, escala: escala);
          for (final campo in [email, senha]) {
            await tester.ensureVisible(find.byKey(campo));
            await tester.pumpAndSettle();
            expect(
              tester.getBottomLeft(find.byKey(campo)).dy,
              lessThanOrEqualTo(tamanho.height - teclado + 1),
            );
          }
          await tester.ensureVisible(find.byKey(entrar));
          await tester.pumpAndSettle();
          expect(
            tester.getBottomLeft(find.byKey(entrar)).dy,
            lessThanOrEqualTo(tamanho.height - teclado + 1),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<RichText>(
                  find.descendant(
                    of: find.byKey(const ValueKey('marca-login')),
                    matching: find.byType(RichText),
                  ),
                )
                .text
                .toPlainText(),
            'BuscaEu',
          );
          final botao = tester.widget<ElevatedButton>(find.byKey(entrar));
          expect(botao.style!.backgroundColor!.resolve({}), AppColors.primary);
          expect(botao.style!.textStyle!.resolve({})!.fontFamily, 'Inter');
        });
      }
    }
  }
}
