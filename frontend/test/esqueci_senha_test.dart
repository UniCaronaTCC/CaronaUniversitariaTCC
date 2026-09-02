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

    await tester.enterText(find.widgetWithText(TextField, '00000000'), '12345678');
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
    expect(codigoRecebido, '12345678');
    expect(find.text('ENTRAR'), findsWidgets);
  });
}
