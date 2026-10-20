import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/carona_service.dart';

const caronaJson = {
  'idCarona': 20,
  'origem': 'Centro',
  'destino': 'Campus',
  'dataInicio': '2026-11-01',
  'horario': '19:00:00',
  'vagas': 2,
  'valor': 8,
  'usuario': {'idUsuario': 2, 'nome': 'Motorista teste'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() => AuthService.tokenUsuarioLogado = null);

  Future<Map<String, dynamic>> consultar(http.Response resposta) =>
      http.runWithClient(
        CaronaService.listarCaronas,
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/caronas');
          expect(request.headers['Authorization'], 'Bearer token-teste');
          return resposta;
        }),
      );

  test('lista valida continua sendo convertida para caronas', () async {
    final resultado = await consultar(
      http.Response(
        jsonEncode({
          'sucesso': true,
          'dados': [caronaJson],
        }),
        200,
      ),
    );
    expect(resultado['sucesso'], isTrue);
    expect((resultado['dados'] as List<Carona>).single.id, 20);
  });

  test('lista vazia valida e sucesso, nao erro', () async {
    final resultado = await consultar(
      http.Response('{"sucesso":true,"dados":[]}', 200),
    );
    expect(resultado['sucesso'], isTrue);
    expect(resultado['dados'], isEmpty);
  });

  for (final corpo in [
    '',
    '<html>proxy</html>',
    '[]',
    '{}',
    '{"dados":null}',
    '{"dados":{}}',
    '{"sucesso":false,"dados":[]}',
    '{"dados":[null]}',
    '{"dados":[{}]}',
  ]) {
    test('resposta 200 invalida nao vira lista vazia: $corpo', () async {
      final resultado = await consultar(http.Response(corpo, 200));
      expect(resultado['sucesso'], isFalse);
      expect(resultado['mensagem'], contains('resposta inválida'));
      expect(resultado.containsKey('dados'), isFalse);
    });
  }

  test('registros invalidos nao produzem lista parcial silenciosa', () async {
    final resultado = await consultar(
      http.Response(
        jsonEncode({
          'dados': [caronaJson, {}],
        }),
        200,
      ),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], contains('resposta inválida'));
  });

  for (final status in [500, 502, 503]) {
    test(
      'HTTP $status com HTML e indisponibilidade, nao lista vazia',
      () async {
        final resultado = await consultar(
          http.Response('<html>proxy</html>', status),
        );
        expect(resultado['sucesso'], isFalse);
        expect(resultado['mensagem'], contains('indisponível'));
        expect(AuthService.estaLogado, isTrue);
      },
    );
  }

  test('429 orienta aguardar sem deslogar', () async {
    final resultado = await consultar(http.Response('{}', 429));
    expect(resultado['mensagem'], contains('Aguarde'));
    expect(AuthService.estaLogado, isTrue);
  });

  test('403 preserva aviso de permissao e sessao', () async {
    final resultado = await consultar(
      http.Response('{"message":"Acesso negado"}', 403),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Acesso negado');
    expect(AuthService.estaLogado, isTrue);
  });

  test('401 definitivo nao e apresentado como busca vazia', () async {
    final resultado = await consultar(http.Response('HTML', 401));
    expect(resultado['mensagem'], contains('sessão expirou'));
    expect(AuthService.estaLogado, isFalse);
  });

  test('nao chama servidor sem sessao', () async {
    AuthService.tokenUsuarioLogado = null;
    var chamadas = 0;
    final resultado = await http.runWithClient(
      CaronaService.listarCaronas,
      () => MockClient((_) async {
        chamadas++;
        return http.Response('{}', 200);
      }),
    );
    expect(chamadas, 0);
    expect(resultado['sucesso'], isFalse);
  });

  test('prazo encerra espera sem nova tentativa automatica', () async {
    var chamadas = 0;
    final pendente = Completer<http.Response>();
    final resultado = await http.runWithClient(
      () =>
          CaronaService.listarCaronas(prazo: const Duration(milliseconds: 10)),
      () => MockClient((_) {
        chamadas++;
        return pendente.future;
      }),
    );
    expect(resultado['mensagem'], contains('demorou'));
    expect(chamadas, 1);
    expect(AuthService.estaLogado, isTrue);
    pendente.complete(http.Response('{"dados":[]}', 200));
    await Future<void>.delayed(Duration.zero);
    expect(resultado['sucesso'], isFalse);
  });

  test('falha de conexao retorna erro e preserva sessao', () async {
    final resultado = await http.runWithClient(
      CaronaService.listarCaronas,
      () => MockClient((_) async {
        throw http.ClientException('Falha simulada');
      }),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], contains('conexão'));
    expect(AuthService.estaLogado, isTrue);
  });

  test('Minhas caronas mantem endpoint e conversao anteriores', () async {
    final resultado = await http.runWithClient(
      CaronaService.listarMinhasCaronas,
      () => MockClient((request) async {
        expect(request.url.path, '/caronas/minhas');
        return http.Response(
          jsonEncode({
            'dados': [caronaJson],
          }),
          200,
        );
      }),
    );
    expect(resultado['sucesso'], isTrue);
    expect((resultado['dados'] as List<Carona>).single.id, 20);
  });
}
