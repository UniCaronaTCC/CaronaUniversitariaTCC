import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/confirmar_email.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/widgets/auth_widgets.dart';

void main() {
  const campo = ValueKey('codigo-confirmacao');
  const confirmar = ValueKey('confirmar-email');
  const reenviar = ValueKey('reenviar-confirmacao');
  const voltar = ValueKey('voltar-confirmacao');
  const login = ValueKey('login-confirmacao');
  const sucesso = {'sucesso': true};
  const falha = {'sucesso': false, 'mensagem': 'Código inválido ou expirado'};

  setUpAll(() async {
    final fontes = FontLoader('Inter');
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fontes.addFont(rootBundle.load('assets/fontes/Inter_18pt-$peso.ttf'));
    }
    await fontes.load();
  });

  setUp(() {
    final anterior = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = anterior);
  });

  Future<void> abrir(
    WidgetTester tester, {
    Future<Map<String, dynamic>> Function(String, String)? verificar,
    Future<Map<String, dynamic>> Function(String)? enviar,
    DateTime Function()? agora,
    double escala = 1,
    String email = 'usuario@exemplo.com',
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
        home: ConfirmarEmailTela(
          email: email,
          confirmarCodigo: verificar ?? (_, _) async => falha,
          reenviarCodigo: enviar ?? (_) async => sucesso,
          agora: agora ?? () => tester.binding.clock.now(),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Key chave) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(chave));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(chave));
    await tester.pump();
  }

  Future<void> liberar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextButton>(find.byKey(reenviar)).onPressed,
      isNotNull,
    );
  }

  testWidgets('logo estilo e campo unico seguem o novo cadastro', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.byType(AuthCard), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(find.text('usuario@exemplo.com'), findsOneWidget);
    final imagem = tester.widget<Image>(
      find.byKey(const ValueKey('logo-confirmacao')),
    );
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/imagens/icone_buscaeu.png',
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    final botao = tester.widget<ElevatedButton>(find.byKey(confirmar));
    expect(botao.style!.backgroundColor!.resolve({}), AppColors.primary);
    expect(botao.style!.textStyle!.resolve({})!.fontFamily, 'Inter');
    for (final chave in [reenviar, login]) {
      expect(
        tester
            .widget<TextButton>(find.byKey(chave))
            .style!
            .foregroundColor!
            .resolve({}),
        AppColors.primary,
      );
    }
    final codigo = tester.widget<TextField>(find.byKey(campo));
    expect(codigo.maxLength, 6);
    expect(codigo.keyboardType, TextInputType.number);
    expect(codigo.textInputAction, TextInputAction.done);
    expect(codigo.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(codigo.autocorrect, isFalse);
    expect(codigo.enableSuggestions, isFalse);
    expect(codigo.style!.letterSpacing, isNull);
  });

  testWidgets('erro fica junto ao codigo e desaparece ao editar', (
    tester,
  ) async {
    await abrir(tester);
    await tocar(tester, confirmar);
    expect(find.text('Informe o código de 6 dígitos'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.enterText(find.byKey(campo), '001234');
    expect(
      tester.widget<TextField>(find.byKey(campo)).controller!.text,
      '001234',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('erro-confirmacao')), findsNothing);
  });

  testWidgets('confirmar bloqueia reenvio teclado e callbacks antigos', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    var verificacoes = 0;
    var reenvios = 0;
    await abrir(
      tester,
      verificar: (email, codigo) {
        verificacoes++;
        expect(email, 'usuario@exemplo.com');
        expect(codigo, '001234');
        return resposta.future;
      },
      enviar: (_) async {
        reenvios++;
        return sucesso;
      },
    );
    await liberar(tester);
    await tester.enterText(find.byKey(campo), '001234');
    final verificar = tester
        .widget<ElevatedButton>(find.byKey(confirmar))
        .onPressed!;
    final reenvio = tester.widget<TextButton>(find.byKey(reenviar)).onPressed!;
    final sair = tester.widget<TextButton>(find.byKey(login)).onPressed!;
    final seta = tester.widget<IconButton>(find.byKey(voltar)).onPressed!;
    final teclado = tester.widget<TextField>(find.byKey(campo)).onSubmitted!;
    verificar();
    verificar();
    reenvio();
    sair();
    seta();
    teclado('001234');
    await tester.pump();
    expect(verificacoes, 1);
    expect(reenvios, 0);
    expect(find.text('Confirmando...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(campo)).enabled, isFalse);
    expect(
      tester.widget<ElevatedButton>(find.byKey(confirmar)).onPressed,
      isNull,
    );
    for (final chave in [reenviar, login]) {
      expect(tester.widget<TextButton>(find.byKey(chave)).onPressed, isNull);
    }
    expect(tester.widget<IconButton>(find.byKey(voltar)).onPressed, isNull);
    resposta.complete(falha);
    await tester.pumpAndSettle();
    expect(find.text('Código inválido ou expirado'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(campo)).controller!.text,
      '001234',
    );
    expect(
      tester.widget<TextButton>(find.byKey(reenviar)).onPressed,
      isNotNull,
    );
  });

  testWidgets('reenvio bloqueia confirmacao e so limpa codigo apos sucesso', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    var verificacoes = 0;
    var reenvios = 0;
    await abrir(
      tester,
      verificar: (_, _) async {
        verificacoes++;
        return falha;
      },
      enviar: (email) {
        expect(email, 'usuario@exemplo.com');
        reenvios++;
        return resposta.future;
      },
    );
    await liberar(tester);
    await tester.enterText(find.byKey(campo), '001234');
    final verificar = tester
        .widget<ElevatedButton>(find.byKey(confirmar))
        .onPressed!;
    final reenvio = tester.widget<TextButton>(find.byKey(reenviar)).onPressed!;
    final teclado = tester.widget<TextField>(find.byKey(campo)).onSubmitted!;
    reenvio();
    reenvio();
    verificar();
    teclado('001234');
    await tester.pump();
    expect(reenvios, 1);
    expect(verificacoes, 0);
    expect(find.text('Reenviando...'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(campo)).enabled, isFalse);
    expect(
      tester.widget<TextField>(find.byKey(campo)).controller!.text,
      '001234',
    );
    expect(
      tester.widget<ElevatedButton>(find.byKey(confirmar)).onPressed,
      isNull,
    );
    resposta.complete(sucesso);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(campo)).controller!.text,
      isEmpty,
    );
    expect(find.text('Reenviar código em 60s'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(campo)).enabled, isTrue);
    expect(tester.widget<TextButton>(find.byKey(reenviar)).onPressed, isNull);
  });

  for (final excecao in [false, true]) {
    testWidgets(
      'falha de confirmacao excecao=$excecao preserva codigo e libera nova tentativa',
      (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          verificar: (_, _) async {
            chamadas++;
            if (excecao) throw StateError('Falha simulada');
            return falha;
          },
        );
        await tester.enterText(find.byKey(campo), '001234');
        await tocar(tester, confirmar);
        await tester.pumpAndSettle();
        expect(
          find.text(
            excecao
                ? 'Não foi possível confirmar o e-mail. Tente novamente'
                : 'Código inválido ou expirado',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byKey(campo)).controller!.text,
          '001234',
        );
        expect(
          tester.widget<ElevatedButton>(find.byKey(confirmar)).onPressed,
          isNotNull,
        );
        await tocar(tester, confirmar);
        await tester.pumpAndSettle();
        expect(chamadas, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'falha de reenvio excecao=$excecao preserva codigo sem reiniciar espera',
      (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          enviar: (_) async {
            chamadas++;
            if (excecao) throw StateError('Falha simulada');
            return {'sucesso': false, 'mensagem': 'Reenvio indisponível'};
          },
        );
        await liberar(tester);
        await tester.enterText(find.byKey(campo), '001234');
        await tocar(tester, reenviar);
        await tester.pumpAndSettle();
        expect(
          find.text(
            excecao
                ? 'Não foi possível reenviar o código. Tente novamente'
                : 'Reenvio indisponível',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byKey(campo)).controller!.text,
          '001234',
        );
        expect(
          tester.widget<TextButton>(find.byKey(reenviar)).onPressed,
          isNotNull,
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(ConfirmarEmailTela)),
        ).removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tocar(tester, reenviar);
        await tester.pumpAndSettle();
        expect(chamadas, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('teclado confirma e sucesso limpa pilha ate o login', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      verificar: (_, codigo) async {
        chamadas++;
        expect(codigo, '001234');
        return sucesso;
      },
    );
    await tester.enterText(find.byKey(campo), '001234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(chamadas, 1);
    expect(find.byType(LoginTela), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(LoginTela))).canPop(),
      isFalse,
    );
    expect(
      tester.testTextInput.log.where(
        (call) =>
            call.method == 'TextInput.finishAutofillContext' &&
            call.arguments == true,
      ),
      isEmpty,
    );
  });

  testWidgets('reenvio aguarda sessenta segundos completos', (tester) async {
    await abrir(tester);
    expect(find.text('Reenviar código em 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Reenviar código em 1s'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(reenviar)).onPressed, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reenviar código'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byKey(reenviar)).onPressed,
      isNotNull,
    );
  });

  for (final decorrido in [30, 75]) {
    testWidgets(
      'retorno do segundo plano recalcula espera apos $decorrido segundos',
      (tester) async {
        var agora = DateTime.utc(2026, 10, 29, 12);
        await abrir(tester, agora: () => agora);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        agora = agora.add(Duration(seconds: decorrido));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          find.text(
            decorrido < 60 ? 'Reenviar código em 30s' : 'Reenviar código',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextButton>(find.byKey(reenviar)).onPressed,
          decorrido < 60 ? isNull : isNotNull,
        );
      },
    );
  }

  for (final chave in [voltar, login]) {
    testWidgets('$chave retorna ao login sem deixar confirmacao na pilha', (
      tester,
    ) async {
      await abrir(tester);
      await tocar(tester, chave);
      await tester.pumpAndSettle();
      expect(find.byType(LoginTela), findsOneWidget);
      expect(find.byType(ConfirmarEmailTela), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginTela))).canPop(),
        isFalse,
      );
    });
  }

  for (final acao in ['confirmar', 'reenviar']) {
    for (final remover in [false, true]) {
      for (final resultado in ['sucesso', 'falha', 'excecao']) {
        testWidgets(
          '$acao com tela ${remover ? 'removida' : 'coberta'} ignora navegacao e avisos de $resultado tardio',
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
              verificar: (_, _) => executar(),
              enviar: (_) => executar(),
            );
            await liberar(tester);
            await tester.enterText(find.byKey(campo), '001234');
            final confirmarAntigo = tester
                .widget<ElevatedButton>(find.byKey(confirmar))
                .onPressed!;
            final reenviarAntigo = tester
                .widget<TextButton>(find.byKey(reenviar))
                .onPressed!;
            if (acao == 'confirmar') {
              confirmarAntigo();
            } else {
              reenviarAntigo();
            }
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
            confirmarAntigo();
            reenviarAntigo();
            expect(chamadas, 1);
            if (!remover) {
              navigator.currentState!.pop();
              await tester.pumpAndSettle();
              expect(
                tester.widget<TextField>(find.byKey(campo)).enabled,
                isTrue,
              );
              if (acao == 'reenviar' && resultado == 'sucesso') {
                expect(
                  tester.widget<TextField>(find.byKey(campo)).controller!.text,
                  isEmpty,
                );
                expect(
                  tester.widget<TextButton>(find.byKey(reenviar)).onPressed,
                  isNull,
                );
              }
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final tamanho in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(800, 600),
  ]) {
    for (final escala in [1.0, 2.0, 3.0]) {
      for (final teclado in [0.0, 300.0]) {
        testWidgets(
          'layout ${tamanho.width} fonte $escala teclado $teclado com email longo',
          (tester) async {
            tester.view.physicalSize = tamanho;
            tester.view.devicePixelRatio = 1;
            tester.view.viewInsets = FakeViewPadding(bottom: teclado);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetViewInsets);
            await abrir(
              tester,
              escala: escala,
              email:
                  'nomedousuariomuitolongoparatestardispositivospequenos@universidade.exemplo.com',
            );
            for (final chave in [
              const ValueKey('email-confirmacao'),
              campo,
              confirmar,
              reenviar,
              login,
              voltar,
            ]) {
              await tester.ensureVisible(find.byKey(chave));
              await tester.pumpAndSettle();
              final rect = tester.getRect(find.byKey(chave));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(tamanho.width));
              if (chave == const ValueKey('email-confirmacao')) {
                expect(rect.top, lessThan(tamanho.height - teclado));
                expect(rect.bottom, greaterThan(0));
              } else {
                expect(rect.top, greaterThanOrEqualTo(0));
                expect(
                  rect.bottom,
                  lessThanOrEqualTo(tamanho.height - teclado + 1),
                  reason: '$chave $rect',
                );
              }
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final estado in ['erro', 'confirmando', 'reenviando']) {
    testWidgets('$estado cabe em tela estreita com fonte triplicada', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resposta = Completer<Map<String, dynamic>>();
      await abrir(
        tester,
        escala: 3,
        verificar: (_, _) => resposta.future,
        enviar: (_) => resposta.future,
      );
      if (estado == 'erro') {
        await tocar(tester, confirmar);
        expect(find.text('Informe o código de 6 dígitos'), findsOneWidget);
      } else {
        await liberar(tester);
        await tester.enterText(find.byKey(campo), '001234');
        await tocar(tester, estado == 'confirmando' ? confirmar : reenviar);
      }
      expect(tester.takeException(), isNull);
      if (estado != 'erro') {
        resposta.complete(falha);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
