import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/services/auth_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(AuthService.sair);

  testWidgets('exibe os dados do usuário e permite sair', (tester) async {
    AuthService.tokenUsuarioLogado = 'token-teste';
    AuthService.usuarioLogado = {
      'id': 1,
      'nome': 'João',
      'email': 'joao@email.com',
      'instituicao': 'UniSalesiano',
      'campus': 'Araçatuba',
      'avaliacaoMedia': 4.7,
      'totalAvaliacoes': 12,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: PerfilTela(
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': AuthService.usuarioLogado,
          },
          atualizarPerfil: (instituicao, campus) async => {
            'sucesso': true,
            'mensagem': 'Perfil atualizado com sucesso',
            'dados': {
              ...AuthService.usuarioLogado!,
              'instituicao': instituicao,
              'campus': campus,
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('João'), findsNWidgets(2));
    expect(find.text('joao@email.com'), findsOneWidget);
    expect(find.text('UniSalesiano - Campus Araçatuba'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('4,7 / 5'), 200);

    expect(find.text('4,7 / 5'), findsOneWidget);
    expect(find.text('12 avaliações'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Editar perfil'), 200);
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Fatec');
    await tester.enterText(find.byType(TextField).at(1), 'Araçatuba');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Fatec - Campus Araçatuba'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sair'), 200);

    expect(find.text('Sair'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginTela), findsOneWidget);
    expect(AuthService.estaLogado, isFalse);
  });
}
