import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/cadastro.dart';
import 'package:uni_carona/auth/confirmar_email.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/widgets/auth_secundario.dart';

void main() {
  const ids = ['cadastro', 'confirmacao', 'recuperacao', 'redefinicao'];
  const botoes = {
    'cadastro': 'criar-conta-cadastro',
    'confirmacao': 'confirmar-email',
    'recuperacao': 'solicitar-codigo-senha',
    'redefinicao': 'salvar-nova-senha',
  };

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
    WidgetTester tester,
    String id, {
    double escala = 1,
  }) async {
    final Widget tela = switch (id) {
      'cadastro' => CadastroTela(
        cadastrar: (_, _, _) async => {'sucesso': false},
      ),
      'confirmacao' => ConfirmarEmailTela(
        email: 'pessoa@exemplo.com',
        confirmarCodigo: (_, _) async => {'sucesso': false},
        reenviarCodigo: (_) async => {'sucesso': false},
        agora: () => tester.binding.clock.now(),
      ),
      _ => EsqueciSenhaTela(
        solicitarCodigo: (_) async => {'sucesso': true},
        redefinirSenha: (_, _, _) async => {'sucesso': false},
      ),
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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
    if (id == 'redefinicao') {
      await tester.enterText(
        find.byKey(const ValueKey('email-recuperacao')),
        'pessoa@exemplo.com',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('solicitar-codigo-senha')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('solicitar-codigo-senha')));
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(
        tester.element(find.byType(EsqueciSenhaTela)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
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
          'cabecalhos iguais em $tamanho fonte $escala teclado $teclado',
          (tester) async {
            tester.view.physicalSize = tamanho;
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            tester.view.viewInsets = FakeViewPadding(bottom: teclado);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetViewInsets);
            Rect? logoReferencia;
            Rect? marcaReferencia;
            double? topoTitulo;
            for (final id in ids) {
              await abrir(tester, id, escala: escala);
              expect(find.byType(TelaAuthSecundaria), findsOneWidget);
              final logo = tester.getRect(find.byKey(ValueKey('logo-$id')));
              final marca = tester.getRect(find.byKey(ValueKey('marca-$id')));
              final titulo = tester.getRect(find.byKey(ValueKey('titulo-$id')));
              final descricao = tester.getRect(
                find.byKey(ValueKey('descricao-$id')),
              );
              final seta = tester.getRect(find.byKey(ValueKey('voltar-$id')));
              final barra = tester.getRect(find.byType(AppBar));
              expect(logo.size, const Size(96, 96));
              expect(logo.top - barra.bottom, 24);
              expect(marca.top - logo.bottom, 10);
              expect(titulo.top - marca.bottom, 28);
              expect(descricao.top - titulo.bottom, 8);
              expect(
                tester
                    .widget<Text>(find.byKey(ValueKey('marca-$id')))
                    .style!
                    .fontSize,
                36,
              );
              expect(
                tester
                    .widget<Text>(find.byKey(ValueKey('titulo-$id')))
                    .style!
                    .fontSize,
                26,
              );
              expect(
                tester
                    .widget<Text>(find.byKey(ValueKey('descricao-$id')))
                    .style!
                    .fontSize,
                16,
              );
              logoReferencia ??= logo;
              marcaReferencia ??= marca;
              topoTitulo ??= titulo.top;
              expect(logo, logoReferencia, reason: id);
              expect(marca, marcaReferencia, reason: id);
              expect(titulo.top, topoTitulo, reason: id);
              final fimDescricao = id == 'confirmacao'
                  ? tester
                        .getRect(
                          find.byKey(const ValueKey('email-confirmacao')),
                        )
                        .bottom
                  : id == 'redefinicao'
                  ? tester
                        .getRect(
                          find.byKey(const ValueKey('email-redefinicao')),
                        )
                        .bottom
                  : descricao.bottom;
              final label = switch (id) {
                'cadastro' => 'Nome',
                'confirmacao' => 'Código de confirmação',
                'redefinicao' => 'Código de recuperação',
                _ => 'E-mail',
              };
              expect(tester.getTopLeft(find.text(label)).dy - fimDescricao, 24);
              expect(
                find.ancestor(
                  of: find.byKey(ValueKey('voltar-$id')),
                  matching: find.byType(AppBar),
                ),
                findsOneWidget,
              );
              await tester.ensureVisible(find.byKey(ValueKey(botoes[id]!)));
              await tester.pumpAndSettle();
              expect(tester.getRect(find.byKey(ValueKey('voltar-$id'))), seta);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
              await tester.pump();
            }
          },
        );
      }
    }
  }

  for (final id in ids) {
    testWidgets('erro em $id nao recentraliza o cabecalho', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrir(tester, id);
      final logo = tester.getRect(find.byKey(ValueKey('logo-$id')));
      final titulo = tester.getRect(find.byKey(ValueKey('titulo-$id')));
      final seta = tester.getRect(find.byKey(ValueKey('voltar-$id')));
      tester
          .widget<ElevatedButton>(find.byKey(ValueKey(botoes[id]!)))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(ValueKey('logo-$id'))), logo);
      expect(tester.getRect(find.byKey(ValueKey('titulo-$id'))), titulo);
      expect(tester.getRect(find.byKey(ValueKey('voltar-$id'))), seta);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('login continua independente com logo e marca originais', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const LoginTela()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TelaAuthSecundaria), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('logo-login'))),
      const Size(128, 128),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('marca-login')))
          .style!
          .fontSize,
      40,
    );
  });

  testWidgets('senha e confirmacao possuem visibilidade independente', (
    tester,
  ) async {
    await abrir(tester, 'redefinicao');
    const nova = ValueKey('nova-senha-recuperacao');
    const confirmacao = ValueKey('confirmar-nova-senha');
    await tester.enterText(find.byKey(nova), 'novaSenha123');
    await tester.enterText(find.byKey(confirmacao), 'outraSenha123');
    for (final chave in [nova, confirmacao]) {
      final olho = find.descendant(
        of: find.byKey(chave),
        matching: find.byTooltip('Mostrar senha'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(olho);
      await tester.pumpAndSettle();
      await tester.tap(olho);
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(chave)).obscureText, isFalse);
      if (chave == nova) {
        expect(
          tester.widget<TextField>(find.byKey(confirmacao)).obscureText,
          isTrue,
        );
      }
    }
    expect(
      tester.widget<TextField>(find.byKey(nova)).controller!.text,
      'novaSenha123',
    );
    expect(
      tester.widget<TextField>(find.byKey(confirmacao)).controller!.text,
      'outraSenha123',
    );
  });
}
