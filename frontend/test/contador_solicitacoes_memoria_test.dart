import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/memoria_solicitacoes.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

import 'memoria_solicitacoes_test.dart' show dadosSolicitacao;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = {'id': 1};
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  test(
    'contador compartilha o par de requisicoes ja iniciado pela tela',
    () async {
      final pendente = Completer<http.Response>();
      var gets = 0;
      await http.runWithClient(
        () async {
          final tela = SolicitacaoService.atualizarListas();
          final contador =
              SolicitacaoService.atualizarTotalSolicitacoesPendentes();
          await Future<void>.delayed(Duration.zero);
          expect(gets, 2);
          pendente.complete(
            http.Response(
              jsonEncode({
                'dados': [dadosSolicitacao(status: 'ACEITA')],
              }),
              200,
            ),
          );
          await tela;
          await contador;
          expect(SolicitacaoService.totalSolicitacoesPendentes.value, 1);
        },
        () => MockClient((_) {
          gets++;
          return pendente.future;
        }),
      );
    },
  );

  testWidgets('mantem intervalo de 30 segundos e nao duplica timers', (
    tester,
  ) async {
    var gets = 0;
    await http.runWithClient(
      () async {
        final primeiro =
            SolicitacaoService.iniciarContadorSolicitacoesPendentes();
        final segundo =
            SolicitacaoService.iniciarContadorSolicitacoesPendentes();
        await tester.pump();
        await Future.wait([primeiro, segundo]);
        expect(gets, 2);
        await tester.pump(const Duration(seconds: 29));
        expect(gets, 2);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(gets, 4);
        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(gets, 6);
        SolicitacaoService.pararContadorSolicitacoesPendentes();
      },
      () => MockClient((_) async {
        gets++;
        return http.Response('{"dados":[]}', 200);
      }),
    );
  });

  testWidgets(
    'parar durante inicializacao nao recria timer nem atualiza total',
    (tester) async {
      final pendente = Completer<http.Response>();
      var gets = 0;
      await http.runWithClient(
        () async {
          final inicio =
              SolicitacaoService.iniciarContadorSolicitacoesPendentes();
          await tester.pump();
          SolicitacaoService.pararContadorSolicitacoesPendentes();
          pendente.complete(
            http.Response(
              jsonEncode({
                'dados': [dadosSolicitacao()],
              }),
              200,
            ),
          );
          await tester.pump();
          await inicio;
          await tester.pump(const Duration(minutes: 2));
          expect(gets, 2);
          expect(SolicitacaoService.totalSolicitacoesPendentes.value, 0);
        },
        () => MockClient((_) {
          gets++;
          return pendente.future;
        }),
      );
    },
  );

  test(
    'resposta anterior ao logout nao altera contador da nova sessao',
    () async {
      final pendente = Completer<http.Response>();
      await http.runWithClient(() async {
        final consulta =
            SolicitacaoService.atualizarTotalSolicitacoesPendentes();
        await Future<void>.delayed(Duration.zero);
        await AuthService.sair();
        AuthService.usuarioLogado = {'id': 2};
        AuthService.tokenUsuarioLogado = 'novo-token';
        SolicitacaoService.totalSolicitacoesPendentes.value = 9;
        pendente.complete(http.Response('{"dados":[]}', 200));
        await consulta;
        expect(SolicitacaoService.totalSolicitacoesPendentes.value, 9);
        expect(SolicitacaoService.lerListas(), isNull);
      }, () => MockClient((_) => pendente.future));
    },
  );

  test(
    'falha parcial preserva contador e snapshot sem considera-lo confirmado',
    () async {
      await http.runWithClient(
        SolicitacaoService.atualizarTotalSolicitacoesPendentes,
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'dados': [dadosSolicitacao()],
            }),
            200,
          ),
        ),
      );
      final anterior = SolicitacaoService.lerListas();
      final total = SolicitacaoService.totalSolicitacoesPendentes.value;
      await http.runWithClient(
        SolicitacaoService.atualizarTotalSolicitacoesPendentes,
        () => MockClient(
          (request) async => http.Response(
            request.url.path.endsWith('/recebidas') ? '{}' : '{"dados":[]}',
            200,
          ),
        ),
      );
      expect(identical(SolicitacaoService.lerListas(), anterior), isTrue);
      expect(SolicitacaoService.totalSolicitacoesPendentes.value, total);
      expect(SolicitacaoService.listasConfirmadas, isFalse);
      expect(MemoriaSolicitacoes.compartilhada.erroAtualizacao, isNotNull);
    },
  );
}
