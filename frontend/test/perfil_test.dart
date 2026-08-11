import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/auth/login.dart';
import 'package:uni_carona/home/avaliacoes_recebidas.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/services/auth_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(AuthService.sair);

  testWidgets('exibe os dados do usuário e permite editar e sair', (
    tester,
  ) async {
    AuthService.tokenUsuarioLogado = 'token-teste';
    AuthService.usuarioLogado = {
      'id': 1,
      'nome': 'João',
      'email': 'joao@email.com',
      'instituicao': 'UniSalesiano',
      'campus': 'Araçatuba',
      'tipoPerfil': 'AMBOS',
      'statusVerificacao': 'APROVADO',
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
          carregarAvaliacoes: (idUsuario, pagina) async => {
            'sucesso': true,
            'dados': {
              'media': 4.7,
              'total': 12,
              'pagina': 1,
              'totalPaginas': 1,
              'avaliacoes': [
                {
                  'id': 1,
                  'nota': 5,
                  'comentario': 'Ótima companhia',
                  'criadoEm': '2026-08-10T12:00:00.000Z',
                  'avaliador': {'id': 2, 'nome': 'Maria'},
                },
              ],
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('João'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('joao@email.com'), 200);
    expect(find.text('joao@email.com'), findsOneWidget);
    expect(find.text('UniSalesiano - Campus Araçatuba'), findsOneWidget);
    expect(find.text('Motorista e passageiro'), findsOneWidget);
    expect(find.text('Perfil verificado'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('4,7 / 5'), 200);

    expect(find.text('4,7 / 5'), findsOneWidget);
    expect(find.text('12 avaliações'), findsOneWidget);

    await tester.tap(find.text('12 avaliações'));
    await tester.pumpAndSettle();

    expect(find.byType(AvaliacoesRecebidasTela), findsOneWidget);
    expect(find.text('Ótima companhia'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Editar perfil'), 200);
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Fatec');
    await tester.enterText(find.byType(TextField).at(1), 'Araçatuba');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Fatec - Campus Araçatuba'), findsOneWidget);
    expect(find.text('Motorista e passageiro'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sair'), 200);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginTela), findsOneWidget);
    expect(AuthService.estaLogado, isFalse);
  });
}
