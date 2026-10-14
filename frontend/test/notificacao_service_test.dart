import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/notificacao.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/notificacao_service.dart';

Map<String, dynamic> pagina() => {
  'itens': [
    {
      'id': 8,
      'tipo': 'CNH',
      'titulo': 'CNH conferida',
      'descricao': 'Resultado disponivel',
      'referencias': {'tela': 'CNH'},
      'criadoEm': '2026-10-14T12:00:00Z',
      'lidaEm': '2026-10-14T12:01:00Z',
    },
  ],
  'totalNaoLidas': 0,
  'temMais': false,
  'proximoAntesDe': null,
};

void main() {
  setUp(() {
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
  });

  test('abrir envia POST autenticado e converte avisos lidos', () async {
    final client = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/notificacoes/abrir');
      expect(req.headers['Authorization'], 'Bearer token-sintetico');
      expect(req.body, isEmpty);
      return http.Response(
        jsonEncode({'sucesso': true, 'dados': pagina()}),
        201,
      );
    });
    final resultado = await NotificacaoService(cliente: client).abrir();
    expect(resultado['sucesso'], isTrue);
    final dados = resultado['dados'] as PaginaNotificacoes;
    expect(dados.itens.single.id, 8);
    expect(dados.itens.single.lidaEm, isNotNull);
    expect(dados.totalNaoLidas, 0);
    client.close();
  });

  test('consulta contador nao executa marcacao', () async {
    final client = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/notificacoes/nao-lidas');
      return http.Response('{"sucesso":true,"dados":{"total":3}}', 200);
    });
    expect((await NotificacaoService(cliente: client).contar())['dados'], 3);
    client.close();
  });

  test('paginacao usa GET e cursor sem identificador de usuario', () async {
    final client = MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.path, '/notificacoes');
      expect(req.url.queryParameters, {'antesDe': '8'});
      return http.Response(
        jsonEncode({'sucesso': true, 'dados': pagina()}),
        200,
      );
    });
    expect(
      (await NotificacaoService(cliente: client).listar(antesDe: 8))['sucesso'],
      isTrue,
    );
    client.close();
  });

  for (final resposta in [
    http.Response('<html>indisponivel</html>', 502),
    http.Response('', 503),
    http.Response('[]', 200),
    http.Response('{"sucesso":false}', 403),
    http.Response('{"sucesso":true,"dados":{"total":-1}}', 200),
    http.Response('{"sucesso":true,"dados":{"total":"invalido"}}', 200),
  ]) {
    test(
      'resposta invalida nao apaga silenciosamente contador ${resposta.statusCode} ${resposta.body}',
      () async {
        final client = MockClient((_) async => resposta);
        final resultado = await NotificacaoService(cliente: client).contar();
        expect(resultado['sucesso'], isFalse);
        expect(resultado.containsKey('dados'), isFalse);
        client.close();
      },
    );
  }

  test('falha de conexao retorna erro sem dados pessoais', () async {
    final client = MockClient(
      (req) async =>
          throw http.ClientException('dado-sensivel-sintetico', req.url),
    );
    final resultado = await NotificacaoService(cliente: client).abrir();
    expect(resultado['sucesso'], isFalse);
    expect(
      resultado['mensagem'].toString(),
      isNot(contains('dado-sensivel-sintetico')),
    );
    client.close();
  });

  test('sem sessao nao chama API', () async {
    AuthService.tokenUsuarioLogado = null;
    final client = MockClient(
      (_) async => throw StateError('Nao deveria consultar'),
    );
    final resultado = await NotificacaoService(cliente: client).abrir();
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'].toString(), contains('Entre novamente'));
    client.close();
  });

  test('cursor ausente em pagina com mais dados e rejeitado', () {
    expect(
      () => PaginaNotificacoes.fromJson({...pagina(), 'temMais': true}),
      throwsFormatException,
    );
  });
}
