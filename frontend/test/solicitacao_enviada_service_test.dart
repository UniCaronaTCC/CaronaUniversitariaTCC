import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

const solicitacaoJson = {
  'id': 23,
  'status': 'ACEITA',
  'pagamentoConfirmado': true,
  'motorista': {'nome': 'Motorista teste'},
  'carona': {
    'id': 1,
    'destino': 'Campus teste',
    'dataInicio': '2026-11-01',
    'horario': '19:00:00',
    'valor': 5,
    'status': 'ATIVA',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    SolicitacaoService.pararContadorSolicitacoesPendentes();
  });

  Future<Map<String, dynamic>> consultar(http.Response resposta) =>
      http.runWithClient(
        SolicitacaoService.listarEnviadas,
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/solicitacoes/enviadas');
          expect(request.headers['Authorization'], 'Bearer token-teste');
          return resposta;
        }),
      );

  for (final incluirSucesso in [true, false]) {
    test(
      'lista valida preserva estado e pagamento, envelope=$incluirSucesso',
      () async {
        final resultado = await consultar(
          http.Response(
            jsonEncode({
              if (incluirSucesso) 'sucesso': true,
              'dados': [solicitacaoJson],
            }),
            200,
          ),
        );
        expect(resultado['sucesso'], isTrue);
        final solicitacao =
            (resultado['dados'] as List<SolicitacaoEnviada>).single;
        expect(solicitacao.id, 23);
        expect(solicitacao.idCarona, 1);
        expect(solicitacao.status, 'ACEITA');
        expect(solicitacao.pagamentoConfirmado, isTrue);
      },
    );

    test(
      'lista vazia valida continua sendo sucesso, envelope=$incluirSucesso',
      () async {
        final resultado = await consultar(
          http.Response(
            jsonEncode({if (incluirSucesso) 'sucesso': true, 'dados': []}),
            200,
          ),
        );
        expect(resultado['sucesso'], isTrue);
        expect(resultado['dados'], isA<List<SolicitacaoEnviada>>());
        expect(resultado['dados'], isEmpty);
      },
    );
  }

  for (final corpo in [
    '',
    '<html>proxy indisponivel</html>',
    '{',
    '[]',
    'null',
    '{}',
    '{"dados":null}',
    '{"dados":{}}',
    '{"dados":"lista"}',
    '{"sucesso":false,"dados":[]}',
    '{"dados":[null]}',
    '{"dados":["registro incompleto"]}',
    '{"dados":[42]}',
    '{"dados":[false]}',
    '{"dados":[[]]}',
    '{"dados":[{}]}',
  ]) {
    test('resposta 200 invalida nao vira consulta vazia: $corpo', () async {
      final resultado = await consultar(http.Response(corpo, 200));
      expect(resultado['sucesso'], isFalse);
      expect(resultado['mensagem'], contains('resposta inválida'));
      expect(resultado.containsKey('dados'), isFalse);
      expect(AuthService.estaLogado, isTrue);
    });
  }

  for (final itemInvalido in [
    null,
    'registro incompleto',
    <String, dynamic>{},
  ]) {
    test('item invalido nao produz lista parcial: $itemInvalido', () async {
      final resultado = await consultar(
        http.Response(
          jsonEncode({
            'dados': [solicitacaoJson, itemInvalido],
          }),
          200,
        ),
      );
      expect(resultado['sucesso'], isFalse);
      expect(resultado['mensagem'], contains('resposta inválida'));
      expect(resultado.containsKey('dados'), isFalse);
    });
  }

  test('falha HTTP preserva mensagem do backend', () async {
    final resultado = await consultar(
      http.Response('{"message":"Acesso negado"}', 403),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Acesso negado');
    expect(AuthService.estaLogado, isTrue);
  });

  test('falha de conexao continua sendo tratada como conexao', () async {
    final resultado = await http.runWithClient(
      SolicitacaoService.listarEnviadas,
      () => MockClient((_) async => throw http.ClientException('sem conexao')),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Não foi possível conectar ao servidor');
  });

  test('consulta invalida nao apaga contador de pendencias', () async {
    SolicitacaoService.totalSolicitacoesPendentes.value = 3;
    await http.runWithClient(
      SolicitacaoService.atualizarTotalSolicitacoesPendentes,
      () => MockClient(
        (request) async => http.Response(
          request.url.path == '/solicitacoes/enviadas' ? '{}' : '{"dados":[]}',
          200,
        ),
      ),
    );
    expect(SolicitacaoService.totalSolicitacoesPendentes.value, 3);
  });
}
