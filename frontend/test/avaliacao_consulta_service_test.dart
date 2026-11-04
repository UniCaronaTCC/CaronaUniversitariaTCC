import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/avaliacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = {'id': 1, 'nome': 'Pessoa de teste'};
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  Future<Map<String, dynamic>> consultar(String corpo, {int status = 200}) =>
      http.runWithClient(
        () => AvaliacaoService.listarRecebidas(7, pagina: 2),
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/usuarios/7/avaliacoes');
          expect(request.url.queryParameters, {'pagina': '2'});
          expect(request.headers['Authorization'], 'Bearer token-teste');
          return http.Response(corpo, status);
        }),
      );

  for (final envelope in [false, true]) {
    test('preserva pagina, resumo e itens; envelope=$envelope', () async {
      final dados = {
        'media': 4.5,
        'total': 30,
        'pagina': 2,
        'totalPaginas': 2,
        'avaliacoes': [
          {'id': 9, 'nota': 5},
        ],
      };
      final resultado = await consultar(
        jsonEncode({if (envelope) 'sucesso': true, 'dados': dados}),
      );
      expect(resultado['sucesso'], isTrue);
      expect(resultado['dados'], dados);
      expect(AuthService.usuarioLogado, {'id': 1, 'nome': 'Pessoa de teste'});
    });
  }

  for (final corpo in [
    '',
    '<html>proxy</html>',
    '{',
    '[]',
    'null',
    '{}',
    '{"dados":null}',
    '{"dados":[]}',
    '{"dados":"invalido"}',
    '{"sucesso":false,"dados":{"media":0,"total":0}}',
  ]) {
    test('resposta 200 invalida nao vira sucesso: $corpo', () async {
      final resultado = await consultar(corpo);
      expect(resultado['sucesso'], isFalse);
      expect(resultado['mensagem'], contains('resposta inválida'));
      expect(resultado.containsKey('dados'), isFalse);
      expect(AuthService.estaLogado, isTrue);
    });
  }

  for (final status in [403, 404, 409, 429, 500, 503]) {
    test('HTTP $status preserva sessao e mensagem do servidor', () async {
      final resultado = await consultar(
        '{"message":"Aviso do servidor"}',
        status: status,
      );
      expect(resultado['sucesso'], isFalse);
      expect(resultado['mensagem'], 'Aviso do servidor');
      expect(AuthService.estaLogado, isTrue);
    });
  }

  test(
    '401 em HTML encerra sessao em vez de tratar como lista vazia',
    () async {
      final resultado = await consultar(
        '<html>Unauthorized</html>',
        status: 401,
      );
      expect(resultado['sucesso'], isFalse);
      expect(AuthService.estaLogado, isFalse);
      expect(AuthService.usuarioLogado, isNull);
    },
  );

  test('falha de rede nao remove sessao nem perfil', () async {
    final resultado = await http.runWithClient(
      () => AvaliacaoService.listarRecebidas(1),
      () => MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(resultado['sucesso'], isFalse);
    expect(AuthService.estaLogado, isTrue);
    expect(AuthService.usuarioLogado?['id'], 1);
  });

  testWidgets('timeout encerra cliente e ignora resposta tardia', (
    tester,
  ) async {
    final pendente = Completer<http.Response>();
    final cliente = _ClienteObservado(() => pendente.future);
    final consulta = http.runWithClient(
      () => AvaliacaoService.listarRecebidas(1),
      () => cliente,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    final resultado = await consulta;
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], contains('demorou'));
    expect(cliente.fechado, isTrue);
    expect(AuthService.estaLogado, isTrue);
    pendente.complete(http.Response('{"dados":{"media":5,"total":1}}', 200));
    await tester.pump();
    expect(AuthService.usuarioLogado?['id'], 1);
  });

  test('sem token nao inicia GET', () async {
    AuthService.tokenUsuarioLogado = null;
    var consultas = 0;
    final resultado = await http.runWithClient(
      () => AvaliacaoService.listarRecebidas(1),
      () => MockClient((_) async {
        consultas++;
        return http.Response('{}', 200);
      }),
    );
    expect(resultado['sucesso'], isFalse);
    expect(consultas, 0);
  });
}

class _ClienteObservado extends http.BaseClient {
  final Future<http.Response> Function() responder;
  late final http.Client _cliente = MockClient((_) => responder());
  bool fechado = false;
  _ClienteObservado(this.responder);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _cliente.send(request);

  @override
  void close() {
    fechado = true;
    _cliente.close();
  }
}
