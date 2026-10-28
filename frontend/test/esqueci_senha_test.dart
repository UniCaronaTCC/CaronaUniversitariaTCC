import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/esqueci_senha.dart';

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
      find.widgetWithText(TextField, 'E-mail'),
      'joao@email.com',
    );
    await tester.tap(find.text('ENVIAR CÓDIGO'));
    await tester.pumpAndSettle();

    expect(emailSolicitado, 'joao@email.com');
    expect(find.text('SALVAR NOVA SENHA'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '000000'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha'),
      'novaSenha123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar nova senha'),
      'novaSenha123',
    );
    await tester.tap(find.text('SALVAR NOVA SENHA'));
    await tester.pumpAndSettle();

    expect(senhaRecebida, 'novaSenha123');
    expect(codigoRecebido, '123456');
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
      find.widgetWithText(TextField, 'E-mail'),
      'usuario@example.test',
    );
    await tester.tap(find.text('ENVIAR CÓDIGO'));
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
      expect(find.text('SALVANDO...'), findsNothing);
      await tester.tap(find.text('SALVAR NOVA SENHA'));
      await tester.pumpAndSettle();
      expect(chamadas, 2);
      expect(find.text('Entrar'), findsOneWidget);
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
  });
}
