import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';
import 'package:uni_carona/utils/validacao_senha.dart';
import 'package:uni_carona/widgets/aviso_app.dart';

void main() {
  testWidgets('solicita código e redefine a senha', (tester) async {
    String? emailSolicitado;
    String? senhaRecebida;
    String? codigoRecebido;

    await tester.pumpWidget(
      MaterialApp(
        home: EsqueciSenhaTela(
          solicitarCodigo: (email) async {
            emailSolicitado = email;
            return {'sucesso': true, 'mensagem': 'Código enviado'};
          },
          redefinirSenha: (email, codigo, senha) async {
            codigoRecebido = codigo;
            senhaRecebida = senha;
            return {
              'sucesso': true,
              'mensagem': 'Senha redefinida com sucesso',
            };
          },
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Seu e-mail'),
      'joao@email.com',
    );
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(emailSolicitado, 'joao@email.com');
    expect(find.text('SALVAR NOVA SENHA'), findsOneWidget);
    expect(
      tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
      TipoAviso.informacao,
    );
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 3),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(AvisoApp), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha'),
      'novaSenha123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar nova senha'),
      'novaSenha123',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SALVAR NOVA SENHA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SALVAR NOVA SENHA'));
    await tester.pumpAndSettle();

    expect(senhaRecebida, 'novaSenha123');
    expect(codigoRecebido, '123456');
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Senha redefinida com sucesso'), findsOneWidget);
    expect(
      tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
      TipoAviso.sucesso,
    );
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 2),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(AvisoApp), findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
  });

  Future<void> abrirFormulario(
    WidgetTester tester, {
    required RedefinirSenha redefinir,
    SolicitarCodigoSenha? solicitar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EsqueciSenhaTela(
          solicitarCodigo:
              solicitar ??
              (_) async => {'sucesso': true, 'mensagem': 'Código enviado'},
          redefinirSenha: redefinir,
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Seu e-mail'),
      'usuario@example.test',
    );
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(EsqueciSenhaTela)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  for (final codigo in ['', '12345']) {
    testWidgets('recuperacao nao envia codigo incompleto "$codigo"', (
      tester,
    ) async {
      var chamadas = 0;
      await abrirFormulario(
        tester,
        redefinir: (_, _, _) async {
          chamadas++;
          return {'sucesso': false};
        },
      );
      await tester.enterText(find.widgetWithText(TextField, '000000'), codigo);
      await tester.ensureVisible(find.text('SALVAR NOVA SENHA'));
      await tester.tap(find.text('SALVAR NOVA SENHA'));
      await tester.pumpAndSettle();
      expect(chamadas, 0);
      expect(find.text('Informe o código de 6 dígitos'), findsOneWidget);
      expect(
        tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
        TipoAviso.atencao,
      );
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 4),
      );
    });
  }

  testWidgets('recuperacao limita campo a seis numeros', (tester) async {
    await abrirFormulario(
      tester,
      redefinir: (_, _, _) async => {'sucesso': false},
    );
    final campo = find.widgetWithText(TextField, '000000');
    expect(tester.widget<TextField>(campo).maxLength, 6);
    await tester.enterText(campo, '12a345678');
    expect(tester.widget<TextField>(campo).controller!.text, '123456');
  });

  testWidgets(
    'codigo recusado permanece no formulario e permite nova tentativa',
    (tester) async {
      var chamadas = 0;
      await abrirFormulario(
        tester,
        redefinir: (_, codigo, _) async {
          chamadas++;
          expect(codigo, '001234');
          return {
            'sucesso': chamadas > 1,
            'mensagem': chamadas == 1
                ? 'Código inválido ou expirado'
                : 'Senha redefinida',
          };
        },
      );
      await tester.enterText(
        find.widgetWithText(TextField, '000000'),
        '001234',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nova senha'),
        'novaSenha123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirmar nova senha'),
        'novaSenha123',
      );
      await tester.ensureVisible(find.text('SALVAR NOVA SENHA'));
      await tester.tap(find.text('SALVAR NOVA SENHA'));
      await tester.pumpAndSettle();
      expect(find.text('Código inválido ou expirado'), findsOneWidget);
      expect(
        tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
        TipoAviso.erro,
      );
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 5),
      );
      expect(find.text('SALVANDO...'), findsNothing);
      ScaffoldMessenger.of(
        tester.element(find.byType(EsqueciSenhaTela)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALVAR NOVA SENHA'));
      await tester.pumpAndSettle();
      expect(chamadas, 2);
      expect(find.text('Entrar'), findsOneWidget);
      expect(
        tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
        TipoAviso.sucesso,
      );
    },
  );

  testWidgets('reenvio de recuperacao preserva email e solicita novo codigo', (
    tester,
  ) async {
    var pedidos = 0;
    await abrirFormulario(
      tester,
      solicitar: (email) async {
        pedidos++;
        expect(email, 'usuario@example.test');
        return {'sucesso': true, 'mensagem': 'Código enviado'};
      },
      redefinir: (_, _, _) async => {'sucesso': false},
    );
    await tester.ensureVisible(find.text('Reenviar código'));
    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle();
    expect(pedidos, 2);
    expect(find.widgetWithText(TextField, '000000'), findsOneWidget);
    expect(
      tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
      TipoAviso.informacao,
    );
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 3),
    );
  });

  for (final senha in ['curta', 'novaSenha123']) {
    testWidgets('validacao de senha $senha usa aviso de atencao sem enviar', (
      tester,
    ) async {
      var chamadas = 0;
      await abrirFormulario(
        tester,
        redefinir: (_, _, _) async {
          chamadas++;
          return {'sucesso': true};
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('codigo-recuperacao')),
        '001234',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nova-senha-recuperacao')),
        senha,
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirmar-nova-senha')),
        'diferente123',
      );
      await tester.ensureVisible(find.text('SALVAR NOVA SENHA'));
      await tester.tap(find.text('SALVAR NOVA SENHA'));
      await tester.pumpAndSettle();
      expect(chamadas, 0);
      expect(
        find.text(
          senha == 'curta'
              ? ValidacaoSenha.mensagem
              : 'As senhas não são iguais',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
        TipoAviso.atencao,
      );
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 4),
      );
    });
  }

  for (final excecao in [false, true]) {
    testWidgets(
      'falha de reenvio excecao=$excecao usa erro e permite tentar novamente',
      (tester) async {
        var pedidos = 0;
        await abrirFormulario(
          tester,
          solicitar: (email) async {
            expect(email, 'usuario@example.test');
            pedidos++;
            if (pedidos == 2) {
              if (excecao) throw StateError('Falha simulada');
              return {'sucesso': false, 'mensagem': 'Reenvio indisponível'};
            }
            return {'sucesso': true, 'mensagem': 'Código enviado'};
          },
          redefinir: (_, _, _) async => {'sucesso': false},
        );
        await tester.enterText(
          find.byKey(const ValueKey('codigo-recuperacao')),
          '001234',
        );
        await tester.ensureVisible(find.text('Reenviar código'));
        await tester.tap(find.text('Reenviar código'));
        await tester.pumpAndSettle();
        expect(pedidos, 2);
        expect(
          tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
          TipoAviso.erro,
        );
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).duration,
          const Duration(seconds: 5),
        );
        expect(
          find.text(
            excecao
                ? 'Não foi possível enviar o código. Tente novamente'
                : 'Reenvio indisponível',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('codigo-recuperacao')),
              )
              .controller!
              .text,
          '001234',
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(EsqueciSenhaTela)),
        ).removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reenviar código'));
        await tester.pumpAndSettle();
        expect(pedidos, 3);
        expect(
          tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
          TipoAviso.informacao,
        );
        expect(find.text('Código enviado'), findsOneWidget);
      },
    );

    testWidgets(
      'falha de redefinicao excecao=$excecao usa erro e mantem os campos',
      (tester) async {
        await abrirFormulario(
          tester,
          redefinir: (_, _, _) async {
            if (excecao) throw StateError('Falha simulada');
            return {'sucesso': false};
          },
        );
        for (final campo in [
          'codigo-recuperacao',
          'nova-senha-recuperacao',
          'confirmar-nova-senha',
        ]) {
          await tester.enterText(
            find.byKey(ValueKey(campo)),
            campo == 'codigo-recuperacao' ? '001234' : 'novaSenha123',
          );
        }
        await tester.ensureVisible(find.text('SALVAR NOVA SENHA'));
        await tester.tap(find.text('SALVAR NOVA SENHA'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
          TipoAviso.erro,
        );
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).duration,
          const Duration(seconds: 5),
        );
        expect(
          find.text(
            excecao
                ? 'Não foi possível redefinir a senha. Tente novamente'
                : 'Não foi possível redefinir a senha',
          ),
          findsOneWidget,
        );
        expect(find.text('SALVAR NOVA SENHA'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('codigo-recuperacao')),
              )
              .controller!
              .text,
          '001234',
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('nova-senha-recuperacao')),
              )
              .controller!
              .text,
          'novaSenha123',
        );
      },
    );
  }
}
