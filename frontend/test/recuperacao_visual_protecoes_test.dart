import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/utils/validacao_email.dart';
import 'package:uni_carona/widgets/auth_widgets.dart';

void main() {
  const email = ValueKey('email-recuperacao');
  const enviar = ValueKey('solicitar-codigo-senha');
  const voltar = ValueKey('voltar-recuperacao');
  const login = ValueKey('login-recuperacao');
  const sucesso = {'sucesso': true, 'mensagem': 'Código enviado'};
  const falha = {'sucesso': false, 'mensagem': 'Serviço indisponível'};

  setUp(() {
    final anterior = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = anterior);
  });

  Future<void> abrir(
    WidgetTester tester, {
    SolicitarCodigoSenha? solicitar,
    RedefinirSenha? redefinir,
    double escala = 1,
    GlobalKey<NavigatorState>? navigator,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: EsqueciSenhaTela(
          solicitarCodigo: solicitar ?? (_) async => falha,
          redefinirSenha: redefinir ?? (_, _, _) async => falha,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder alvo) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
    await tester.tap(alvo);
    await tester.pump();
  }

  void removerAviso(WidgetTester tester) {
    ScaffoldMessenger.of(
      tester.element(find.byType(EsqueciSenhaTela)),
    ).removeCurrentSnackBar();
  }

  Future<void> preencherSenha(WidgetTester tester) async {
    removerAviso(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '000000'), '001234');
    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha'),
      'novaSenha123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar nova senha'),
      'novaSenha123',
    );
  }

  testWidgets('primeira etapa tem logo campo unico e estilo consistente', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.byType(AuthCard), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Esqueceu sua senha?'), findsOneWidget);
    expect(
      find.text('Informe seu e-mail para receber um código de recuperação.'),
      findsOneWidget,
    );
    final imagem = tester.widget<Image>(
      find.byKey(const ValueKey('logo-recuperacao')),
    );
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/imagens/icone_buscaeu.png',
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    final botao = tester.widget<ElevatedButton>(find.byKey(enviar));
    expect(botao.style!.backgroundColor!.resolve({}), AppColors.primary);
    expect(botao.style!.textStyle!.resolve({})!.fontFamily, 'Inter');
    final campo = tester.widget<TextField>(find.byKey(email));
    expect(campo.keyboardType, TextInputType.emailAddress);
    expect(campo.textInputAction, TextInputAction.done);
    expect(campo.autofillHints, contains(AutofillHints.email));
    expect(campo.autocorrect, isFalse);
    expect(campo.enableSuggestions, isFalse);
  });

  for (final valor in ['', '   ', 'email-invalido', 'joao@']) {
    testWidgets(
      'email invalido "$valor" nao chama servico e erro fica junto ao campo',
      (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          solicitar: (_) async {
            chamadas++;
            return sucesso;
          },
        );
        await tester.enterText(find.byKey(email), valor);
        await tocar(tester, find.byKey(enviar));
        await tester.pumpAndSettle();
        expect(chamadas, 0);
        expect(find.text(ValidacaoEmail.mensagem), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        await tester.enterText(find.byKey(email), 'joao@exemplo.com');
        await tester.pump();
        expect(find.byKey(const ValueKey('erro-recuperacao')), findsNothing);
      },
    );
  }

  testWidgets('envio bloqueia campos botoes e callbacks antigos', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    var chamadas = 0;
    await abrir(
      tester,
      solicitar: (e) {
        chamadas++;
        expect(e, 'Pessoa@Exemplo.com');
        return resposta.future;
      },
    );
    await tester.enterText(find.byKey(email), ' Pessoa@Exemplo.com ');
    final enviarAntigo = tester
        .widget<ElevatedButton>(find.byKey(enviar))
        .onPressed!;
    final voltarAntigo = tester
        .widget<IconButton>(find.byKey(voltar))
        .onPressed!;
    final loginAntigo = tester.widget<TextButton>(find.byKey(login)).onPressed!;
    final teclado = tester.widget<TextField>(find.byKey(email)).onSubmitted!;
    enviarAntigo();
    enviarAntigo();
    voltarAntigo();
    loginAntigo();
    teclado('outro@exemplo.com');
    await tester.pump();
    expect(chamadas, 1);
    expect(find.text('Enviando...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(email)).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(find.byKey(enviar)).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(voltar)).onPressed, isNull);
    expect(tester.widget<TextButton>(find.byKey(login)).onPressed, isNull);
    resposta.complete(falha);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(email)).controller!.text,
      ' Pessoa@Exemplo.com ',
    );
    expect(
      tester.widget<ElevatedButton>(find.byKey(enviar)).onPressed,
      isNotNull,
    );
    expect(find.text('Serviço indisponível'), findsOneWidget);
  });

  testWidgets('sucesso fixa o email enviado para reenvio e redefinicao', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    final emails = <String>[];
    String? emailRedefinido;
    await abrir(
      tester,
      solicitar: (e) {
        emails.add(e);
        return emails.length == 1 ? resposta.future : Future.value(sucesso);
      },
      redefinir: (e, codigo, senha) async {
        emailRedefinido = e;
        expect(codigo, '001234');
        expect(senha, 'novaSenha123');
        return {'sucesso': false, 'mensagem': 'Falha simulada'};
      },
    );
    await tester.enterText(find.byKey(email), ' original@exemplo.com ');
    final controller = tester.widget<TextField>(find.byKey(email)).controller!;
    await tocar(tester, find.byKey(enviar));
    controller.text = 'alterado@exemplo.com';
    resposta.complete(sucesso);
    await tester.pumpAndSettle();
    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.textContaining('original@exemplo.com'), findsOneWidget);
    expect(find.textContaining('alterado@exemplo.com'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));
    removerAviso(tester);
    await tocar(tester, find.text('Reenviar código'));
    await tester.pumpAndSettle();
    expect(emails, ['original@exemplo.com', 'original@exemplo.com']);
    await preencherSenha(tester);
    await tocar(tester, find.text('SALVAR NOVA SENHA'));
    await tester.pumpAndSettle();
    expect(emailRedefinido, 'original@exemplo.com');
  });

  testWidgets('concluir pelo teclado solicita o codigo uma vez', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      solicitar: (_) async {
        chamadas++;
        return sucesso;
      },
    );
    await tester.enterText(find.byKey(email), 'pessoa@exemplo.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(chamadas, 1);
    expect(find.byType(AuthCard), findsOneWidget);
    expect(
      tester.testTextInput.log.where(
        (call) =>
            call.method == 'TextInput.finishAutofillContext' &&
            call.arguments == true,
      ),
      isEmpty,
    );
  });

  for (final tipo in ['falha', 'excecao', 'timeout']) {
    testWidgets('$tipo no envio preserva email e permite tentar novamente', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        solicitar: (_) async {
          chamadas++;
          if (tipo == 'timeout') throw TimeoutException('Falha simulada');
          if (tipo == 'excecao') throw StateError('Falha simulada');
          return falha;
        },
      );
      await tester.enterText(find.byKey(email), 'pessoa@exemplo.com');
      await tocar(tester, find.byKey(enviar));
      await tester.pumpAndSettle();
      expect(
        find.text(
          tipo == 'falha'
              ? 'Serviço indisponível'
              : 'Não foi possível enviar o código. Tente novamente',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byKey(email)).controller!.text,
        'pessoa@exemplo.com',
      );
      expect(
        tester.widget<ElevatedButton>(find.byKey(enviar)).onPressed,
        isNotNull,
      );
      await tocar(tester, find.byKey(enviar));
      await tester.pumpAndSettle();
      expect(chamadas, 2);
      expect(tester.takeException(), isNull);
    });
  }

  for (final chave in [voltar, login]) {
    testWidgets('$chave retorna ao login existente preservando formulario', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const LoginTela()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-login')),
        'login@exemplo.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('senha-login')),
        'senha123',
      );
      await tocar(tester, find.text('Esqueceu sua senha?'));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(chave));
      await tester.pumpAndSettle();
      expect(find.byType(LoginTela), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('email-login')))
            .controller!
            .text,
        'login@exemplo.com',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('senha-login')))
            .controller!
            .text,
        'senha123',
      );
      expect(
        Navigator.of(tester.element(find.byType(LoginTela))).canPop(),
        isFalse,
      );
    });

    testWidgets('$chave abre login quando recuperacao e a raiz', (
      tester,
    ) async {
      await abrir(tester);
      await tocar(tester, find.byKey(chave));
      await tester.pumpAndSettle();
      expect(find.byType(LoginTela), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginTela))).canPop(),
        isFalse,
      );
    });
  }

  for (final etapa in ['envio', 'redefinicao']) {
    for (final remover in [false, true]) {
      for (final resultado in ['sucesso', 'falha', 'excecao']) {
        testWidgets(
          '$etapa com tela ${remover ? 'removida' : 'coberta'} ignora $resultado tardio',
          (tester) async {
            final navigator = GlobalKey<NavigatorState>();
            final resposta = Completer<Map<String, dynamic>>();
            var chamadas = 0;
            Future<Map<String, dynamic>> executar() {
              chamadas++;
              return resposta.future;
            }

            await abrir(
              tester,
              navigator: navigator,
              solicitar: (_) =>
                  etapa == 'envio' ? executar() : Future.value(sucesso),
              redefinir: (_, _, _) => executar(),
            );
            await tester.enterText(find.byKey(email), 'pessoa@exemplo.com');
            if (etapa == 'redefinicao') {
              await tocar(tester, find.byKey(enviar));
              await tester.pumpAndSettle();
              await preencherSenha(tester);
            }
            final alvo = etapa == 'envio'
                ? find.byKey(enviar)
                : find.widgetWithText(ElevatedButton, 'SALVAR NOVA SENHA');
            final enviarAntigo = tester.widget<ElevatedButton>(alvo).onPressed!;
            enviarAntigo();
            await tester.pump();
            final rota = MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Outra tela')),
            );
            if (remover) {
              navigator.currentState!.pushReplacement(rota);
            } else {
              navigator.currentState!.push(rota);
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            if (resultado == 'excecao') {
              resposta.completeError(StateError('Falha simulada'));
            } else {
              resposta.complete(resultado == 'sucesso' ? sucesso : falha);
            }
            await tester.pumpAndSettle();
            expect(find.text('Outra tela'), findsOneWidget);
            expect(find.byType(LoginTela), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            enviarAntigo();
            expect(chamadas, 1);
            if (!remover) {
              navigator.currentState!.pop();
              await tester.pumpAndSettle();
              final liberado = etapa == 'envio'
                  ? find.byKey(enviar)
                  : find.widgetWithText(ElevatedButton, 'SALVAR NOVA SENHA');
              expect(
                tester.widget<ElevatedButton>(liberado).onPressed,
                isNotNull,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final operacao in ['reenvio', 'redefinicao']) {
    testWidgets(
      '$operacao bloqueia operacao concorrente e recupera apos excecao',
      (tester) async {
        final resposta = Completer<Map<String, dynamic>>();
        var reenvios = 0;
        var redefinicoes = 0;
        await abrir(
          tester,
          solicitar: (_) {
            reenvios++;
            return reenvios == 1 ? Future.value(sucesso) : resposta.future;
          },
          redefinir: (_, _, _) {
            redefinicoes++;
            return resposta.future;
          },
        );
        await tester.enterText(find.byKey(email), 'pessoa@exemplo.com');
        await tocar(tester, find.byKey(enviar));
        await tester.pumpAndSettle();
        await preencherSenha(tester);
        final reenvioAntigo = tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Reenviar código'),
            )
            .onPressed!;
        final redefinicaoAntiga = tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'SALVAR NOVA SENHA'),
            )
            .onPressed!;
        if (operacao == 'reenvio') {
          reenvioAntigo();
        } else {
          redefinicaoAntiga();
        }
        reenvioAntigo();
        redefinicaoAntiga();
        await tester.pump();
        expect(reenvios, operacao == 'reenvio' ? 2 : 1);
        expect(redefinicoes, operacao == 'redefinicao' ? 1 : 0);
        expect(
          tester
              .widget<AbsorbPointer>(
                find
                    .ancestor(
                      of: find.byType(AuthCard),
                      matching: find.byType(AbsorbPointer),
                    )
                    .first,
              )
              .absorbing,
          isTrue,
        );
        resposta.completeError(StateError('Falha simulada'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'SALVAR NOVA SENHA'),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Nova senha'))
              .controller!
              .text,
          'novaSenha123',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
          for (final chave in [email, enviar, login, voltar]) {
            await tester.ensureVisible(find.byKey(chave));
            await tester.pumpAndSettle();
            final rect = tester.getRect(find.byKey(chave));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(tamanho.width));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(
              rect.bottom,
              lessThanOrEqualTo(tamanho.height - teclado + 1),
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final estado in ['erro', 'carregando']) {
    testWidgets('$estado cabe com fonte triplicada em tela estreita', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resposta = Completer<Map<String, dynamic>>();
      await abrir(tester, escala: 3, solicitar: (_) => resposta.future);
      if (estado == 'carregando') {
        await tester.enterText(find.byKey(email), 'pessoa@exemplo.com');
      }
      await tocar(tester, find.byKey(enviar));
      expect(tester.takeException(), isNull);
      if (estado == 'carregando') {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        resposta.complete(falha);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
