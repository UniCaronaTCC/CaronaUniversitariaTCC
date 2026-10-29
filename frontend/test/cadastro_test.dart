import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/cadastro.dart';
import 'package:uni_carona/auth/confirmar_email.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/utils/validacao_email.dart';
import 'package:uni_carona/utils/validacao_senha.dart';
import 'package:uni_carona/widgets/auth_widgets.dart';

void main() {
  const nome = ValueKey('nome-cadastro');
  const email = ValueKey('email-cadastro');
  const senha = ValueKey('senha-cadastro');
  const criar = ValueKey('criar-conta-cadastro');
  const entrar = ValueKey('entrar-cadastro');
  const voltar = ValueKey('voltar-cadastro');
  const sucesso = {
    'sucesso': true,
    'dados': {'mensagem': 'Confira seu e-mail'},
  };
  const falha = {'sucesso': false, 'mensagem': 'Cadastro indisponível'};

  setUp(() {
    final anterior = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = anterior);
  });

  Future<void> abrir(
    WidgetTester tester, {
    CadastroTela tela = const CadastroTela(),
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
        home: tela,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preencher(WidgetTester tester) async {
    await tester.enterText(find.byKey(nome), 'João');
    await tester.enterText(find.byKey(email), ' Usuario@Exemplo.com ');
    await tester.enterText(find.byKey(senha), ' senha123 ');
    await tester.ensureVisible(find.byKey(criar));
  }

  Future<void> enviar(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(criar));
    await tester.tap(find.byKey(criar));
    await tester.pump();
  }

  testWidgets('usa logo oficial campos atuais e estilo do login', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.byType(AuthCard), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Crie sua conta'), findsOneWidget);
    expect(find.text('Sua próxima carona começa aqui.'), findsOneWidget);
    expect(find.text('BuscaEu', findRichText: true), findsOneWidget);
    expect(
      find.text('Pelo menos 8 caracteres, com letras e números.'),
      findsOneWidget,
    );
    final logo = tester.widget<Image>(
      find.byKey(const ValueKey('logo-cadastro')),
    );
    expect(
      (logo.image as AssetImage).assetName,
      'assets/imagens/icone_buscaeu.png',
    );
    expect(
      (await rootBundle.load('assets/imagens/icone_buscaeu.png')).lengthInBytes,
      greaterThan(0),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    final botao = tester.widget<ElevatedButton>(find.byKey(criar));
    expect(botao.style!.backgroundColor!.resolve({}), AppColors.primary);
    expect(botao.style!.textStyle!.resolve({})!.fontFamily, 'Inter');
    expect(tester.takeException(), isNull);
  });

  testWidgets('teclado autofill e foco respeitam cada campo', (tester) async {
    await abrir(tester);
    final campoNome = tester.widget<TextField>(find.byKey(nome));
    final campoEmail = tester.widget<TextField>(find.byKey(email));
    final campoSenha = tester.widget<TextField>(find.byKey(senha));
    expect(campoNome.keyboardType, TextInputType.name);
    expect(campoNome.textCapitalization, TextCapitalization.sentences);
    expect(campoNome.autofillHints, contains(AutofillHints.name));
    expect(campoEmail.keyboardType, TextInputType.emailAddress);
    expect(campoEmail.autocorrect, isFalse);
    expect(campoEmail.autofillHints, contains(AutofillHints.email));
    expect(campoSenha.autofillHints, contains(AutofillHints.newPassword));
    expect(campoSenha.autocorrect, isFalse);
    expect(campoSenha.enableSuggestions, isFalse);
    expect(campoSenha.textInputAction, TextInputAction.done);
    for (final chave in [nome, email]) {
      await tester.showKeyboard(find.byKey(chave));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final proximo = chave == nome ? email : senha;
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(proximo),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
    }
  });

  testWidgets('olho preserva senha e selecao', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byKey(senha), 'senha123');
    final controller = tester.widget<TextField>(find.byKey(senha)).controller!;
    controller.selection = const TextSelection.collapsed(offset: 3);
    for (final tooltip in ['Mostrar senha', 'Ocultar senha']) {
      await tester.ensureVisible(find.byTooltip(tooltip));
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(senha)).obscureText,
        tooltip == 'Ocultar senha',
      );
      expect(controller.text, 'senha123');
      expect(controller.selection.baseOffset, 3);
    }
  });

  for (final caso in [
    ('', 'pessoa@exemplo.com', 'senha123', 'Informe seu nome'),
    ('   ', 'pessoa@exemplo.com', 'senha123', 'Informe seu nome'),
    ('Pessoa', '', 'senha123', 'Informe seu e-mail'),
    ('Pessoa', 'invalido', 'senha123', ValidacaoEmail.mensagem),
    ('Pessoa', '   ', 'senha123', ValidacaoEmail.mensagem),
    ('Pessoa', 'pessoa@exemplo.com', '', 'Informe sua senha'),
    ('Pessoa', 'pessoa@exemplo.com', 'abc1234', ValidacaoSenha.mensagem),
    ('Pessoa', 'pessoa@exemplo.com', 'abcdefgh', ValidacaoSenha.mensagem),
    ('Pessoa', 'pessoa@exemplo.com', '12345678', ValidacaoSenha.mensagem),
  ]) {
    testWidgets(
      'validacao ${caso.$4} entrada ${caso.$1}/${caso.$2}/${caso.$3}',
      (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          tela: CadastroTela(
            cadastrar: (_, _, _) async {
              chamadas++;
              return falha;
            },
          ),
        );
        await tester.enterText(find.byKey(nome), caso.$1);
        await tester.enterText(find.byKey(email), caso.$2);
        await tester.enterText(find.byKey(senha), caso.$3);
        await enviar(tester);
        await tester.pumpAndSettle();
        expect(chamadas, 0);
        expect(find.text(caso.$4), findsOneWidget);
      },
    );
  }

  testWidgets('sucesso normaliza email e abre confirmacao sem autenticar', (
    tester,
  ) async {
    List<String>? dados;
    await abrir(
      tester,
      tela: CadastroTela(
        cadastrar: (n, e, s) async {
          dados = [n, e, s];
          return sucesso;
        },
      ),
    );
    await preencher(tester);
    await enviar(tester);
    await tester.pumpAndSettle();
    expect(dados, ['João', 'usuario@exemplo.com', ' senha123 ']);
    expect(find.byType(CadastroTela), findsNothing);
    expect(find.byType(LoginTela), findsNothing);
    expect(
      tester.widget<ConfirmarEmailTela>(find.byType(ConfirmarEmailTela)).email,
      'usuario@exemplo.com',
    );
    expect(
      tester.testTextInput.log.where(
        (call) =>
            call.method == 'TextInput.finishAutofillContext' &&
            call.arguments == true,
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('envio bloqueia controles teclado e callbacks antigos', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    var chamadas = 0;
    await abrir(
      tester,
      tela: CadastroTela(
        cadastrar: (_, _, _) {
          chamadas++;
          return resposta.future;
        },
      ),
    );
    await preencher(tester);
    final enviarAntigo = tester
        .widget<ElevatedButton>(find.byKey(criar))
        .onPressed!;
    final entrarAntigo = tester
        .widget<TextButton>(find.byKey(entrar))
        .onPressed!;
    final voltarAntigo = tester
        .widget<IconButton>(find.byKey(voltar))
        .onPressed!;
    final tecladoAntigo = tester
        .widget<TextField>(find.byKey(senha))
        .onSubmitted!;
    enviarAntigo();
    entrarAntigo();
    voltarAntigo();
    enviarAntigo();
    tecladoAntigo('senha123');
    await tester.pump();
    expect(chamadas, 1);
    expect(find.byType(LoginTela), findsNothing);
    expect(find.text('Criando conta...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final chave in [nome, email, senha]) {
      expect(tester.widget<TextField>(find.byKey(chave)).enabled, isFalse);
    }
    expect(tester.widget<ElevatedButton>(find.byKey(criar)).onPressed, isNull);
    expect(tester.widget<TextButton>(find.byKey(entrar)).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(voltar)).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.visibility_outlined),
          )
          .onPressed,
      isNull,
    );
    resposta.complete(falha);
    await tester.pumpAndSettle();
    expect(find.text('Cadastro indisponível'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(nome)).controller!.text, 'João');
    expect(
      tester.widget<TextField>(find.byKey(email)).controller!.text,
      ' Usuario@Exemplo.com ',
    );
    expect(
      tester.widget<TextField>(find.byKey(senha)).controller!.text,
      ' senha123 ',
    );
    expect(
      tester.widget<ElevatedButton>(find.byKey(criar)).onPressed,
      isNotNull,
    );
    await enviar(tester);
    await tester.pumpAndSettle();
    expect(chamadas, 2);
  });

  testWidgets('concluir teclado envia apenas uma vez', (tester) async {
    final resposta = Completer<Map<String, dynamic>>();
    var chamadas = 0;
    await abrir(
      tester,
      tela: CadastroTela(
        cadastrar: (_, _, _) {
          chamadas++;
          return resposta.future;
        },
      ),
    );
    await preencher(tester);
    await tester.showKeyboard(find.byKey(senha));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(chamadas, 1);
    expect(tester.widget<ElevatedButton>(find.byKey(criar)).onPressed, isNull);
    resposta.complete(falha);
    await tester.pumpAndSettle();
  });

  testWidgets('excecao libera envio e permite tentar novamente', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      tela: CadastroTela(
        cadastrar: (_, _, _) async {
          chamadas++;
          throw StateError('Falha simulada');
        },
      ),
    );
    await preencher(tester);
    await enviar(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível criar sua conta. Tente novamente'),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.byKey(criar)).onPressed,
      isNotNull,
    );
    await enviar(tester);
    await tester.pumpAndSettle();
    expect(chamadas, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha sem mensagem usa aviso existente', (tester) async {
    await abrir(
      tester,
      tela: CadastroTela(cadastrar: (_, _, _) async => {'sucesso': false}),
    );
    await preencher(tester);
    await enviar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Erro ao cadastrar'), findsOneWidget);
  });

  for (final acao in [entrar, voltar]) {
    testWidgets('$acao retorna ao login existente preservando os dados', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const LoginTela()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-login')),
        'pessoa@exemplo.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('senha-login')),
        'senha123',
      );
      await tester.ensureVisible(find.text('Criar conta'));
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(acao));
      await tester.tap(find.byKey(acao));
      await tester.pumpAndSettle();
      expect(find.byType(CadastroTela), findsNothing);
      expect(find.byType(LoginTela), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('email-login')))
            .controller!
            .text,
        'pessoa@exemplo.com',
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

    testWidgets('$acao funciona com cadastro na raiz', (tester) async {
      await abrir(tester);
      await tester.ensureVisible(find.byKey(acao));
      await tester.tap(find.byKey(acao));
      await tester.pumpAndSettle();
      expect(find.byType(CadastroTela), findsNothing);
      expect(find.byType(LoginTela), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginTela))).canPop(),
        isFalse,
      );
    });
  }

  for (final remover in [false, true]) {
    for (final resultado in ['sucesso', 'falha', 'excecao']) {
      testWidgets(
        'resposta $resultado com tela ${remover ? 'removida' : 'coberta'} nao navega nem mostra aviso',
        (tester) async {
          final navigator = GlobalKey<NavigatorState>();
          final resposta = Completer<Map<String, dynamic>>();
          var chamadas = 0;
          await abrir(
            tester,
            navigator: navigator,
            tela: CadastroTela(
              cadastrar: (_, _, _) {
                chamadas++;
                return resposta.future;
              },
            ),
          );
          await preencher(tester);
          final enviarAntigo = tester
              .widget<ElevatedButton>(find.byKey(criar))
              .onPressed!;
          await enviar(tester);
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
          expect(find.byType(ConfirmarEmailTela), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          if (!remover) {
            enviarAntigo();
            expect(chamadas, 1);
            navigator.currentState!.pop();
            await tester.pumpAndSettle();
            expect(
              tester.widget<ElevatedButton>(find.byKey(criar)).onPressed,
              isNotNull,
            );
            expect(
              tester.widget<TextField>(find.byKey(email)).controller!.text,
              ' Usuario@Exemplo.com ',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('sair apos falha nao pede para salvar credenciais', (
    tester,
  ) async {
    await abrir(
      tester,
      tela: CadastroTela(cadastrar: (_, _, _) async => falha),
    );
    await preencher(tester);
    await enviar(tester);
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(CadastroTela)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(entrar));
    await tester.tap(find.byKey(entrar));
    await tester.pumpAndSettle();
    expect(find.byType(CadastroTela), findsNothing);
    expect(find.byType(LoginTela), findsOneWidget);
    expect(
      tester.testTextInput.log.where(
        (call) =>
            call.method == 'TextInput.finishAutofillContext' &&
            call.arguments == true,
      ),
      isEmpty,
    );
  });

  for (final valor in ['senha123', 'ábcdefg1']) {
    testWidgets('aceita senha no limite de oito caracteres: $valor', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        tela: CadastroTela(
          cadastrar: (_, _, s) async {
            chamadas++;
            expect(s, valor);
            return falha;
          },
        ),
      );
      await preencher(tester);
      await tester.enterText(find.byKey(senha), valor);
      await enviar(tester);
      await tester.pumpAndSettle();
      expect(chamadas, 1);
      expect(find.text('Cadastro indisponível'), findsOneWidget);
    });
  }

  for (final resultado in ['sucesso', 'falha', 'excecao']) {
    testWidgets('voltar pelo sistema durante envio ignora $resultado tardio', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final resposta = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          navigatorKey: navigator,
          home: const LoginTela(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-login')),
        'login@exemplo.com',
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CadastroTela(cadastrar: (_, _, _) => resposta.future),
        ),
      );
      await tester.pumpAndSettle();
      await preencher(tester);
      await enviar(tester);
      expect(await navigator.currentState!.maybePop(), isTrue);
      await tester.pumpAndSettle();
      if (resultado == 'excecao') {
        resposta.completeError(StateError('Falha simulada'));
      } else {
        resposta.complete(resultado == 'sucesso' ? sucesso : falha);
      }
      await tester.pumpAndSettle();
      expect(find.byType(LoginTela), findsOneWidget);
      expect(find.byType(ConfirmarEmailTela), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('email-login')))
            .controller!
            .text,
        'login@exemplo.com',
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final tamanho in [const Size(320, 700), const Size(800, 600)]) {
    testWidgets('carregamento cabe com fonte triplicada em $tamanho', (
      tester,
    ) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resposta = Completer<Map<String, dynamic>>();
      await abrir(
        tester,
        escala: 3,
        tela: CadastroTela(cadastrar: (_, _, _) => resposta.future),
      );
      await preencher(tester);
      await enviar(tester);
      await tester.ensureVisible(find.byKey(criar));
      await tester.pump();
      expect(find.text('Criando conta...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      resposta.complete(falha);
      await tester.pumpAndSettle();
    });
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
          for (final chave in [nome, email, senha, criar, entrar, voltar]) {
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
}
