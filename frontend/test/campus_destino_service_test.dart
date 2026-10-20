import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/campus_destino_service.dart';

import 'campus_destino_test.dart' show campusJson;

const cidade = CidadeCampus('Araçatuba', 'SP');

class ClienteObservavel extends MockClient {
  bool fechado = false;
  ClienteObservavel(super.fn);
  @override
  void close() {
    fechado = true;
    super.close();
  }
}

void main() {
  const service = CampusDestinoService();
  test('consulta a nova rota sem exigir termo e preserva acentos', () async {
    final cliente = ClienteObservavel((request) async {
      expect(request.url.path, '/instituicoes/destinos');
      expect(request.url.queryParameters, {'cidade': 'Araçatuba', 'uf': 'SP'});
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'sucesso': true,
            'dados': [campusJson(), campusJson()],
          }),
        ),
        200,
      );
    });
    final lista = await http.runWithClient(
      () => service.listar(cidade),
      () => cliente,
    );
    expect(lista, hasLength(1));
    expect(lista.single.cidade.cidade, 'Araçatuba');
    expect(cliente.fechado, isTrue);
  });
  test('aceita lista realmente vazia', () async {
    expect(
      await http.runWithClient(
        () => service.listar(cidade),
        () => MockClient(
          (_) async => http.Response('{"sucesso":true,"dados":[]}', 200),
        ),
      ),
      isEmpty,
    );
  });
  for (final status in [400, 401, 404, 429, 500, 503]) {
    test('HTTP $status não vira lista vazia', () async {
      await http.runWithClient(() async {
        await expectLater(service.listar(cidade), throwsFormatException);
      }, () => MockClient((_) async => http.Response('{}', status)));
    });
  }
  for (final corpo in [
    '<html>erro</html>',
    '{}',
    '[]',
    '{"sucesso":false,"dados":[]}',
    '{"sucesso":true,"dados":{}}',
    '{"sucesso":true,"dados":[{}]}',
  ]) {
    test(
      'não trata resposta incorreta como ausência de campi: $corpo',
      () async {
        await http.runWithClient(() async {
          await expectLater(service.listar(cidade), throwsFormatException);
        }, () => MockClient((_) async => http.Response(corpo, 200)));
      },
    );
  }
  test('não mistura outra cidade nem outra UF na lista', () async {
    for (final dados in [
      {...campusJson(), 'municipio': 'Lins'},
      {...campusJson(), 'uf': 'MS'},
    ]) {
      await http.runWithClient(
        () async {
          await expectLater(service.listar(cidade), throwsFormatException);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'sucesso': true,
              'dados': [dados],
            }),
            200,
          ),
        ),
      );
    }
  });
  test('preserva campi diferentes da mesma instituição', () async {
    final lista = await http.runWithClient(
      () => service.listar(cidade),
      () => MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'sucesso': true,
              'dados': [
                campusJson(),
                {...campusJson(), 'idCampus': 11, 'campus': 'Veterinária'},
              ],
            }),
          ),
          200,
        ),
      ),
    );
    expect(lista, hasLength(2));
  });
  test('encerra conexão no prazo e permite uma tentativa nova', () async {
    final pendente = Completer<http.Response>();
    final cliente = ClienteObservavel((_) => pendente.future);
    await http.runWithClient(() async {
      await expectLater(
        service.listar(cidade, prazo: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
    }, () => cliente);
    expect(cliente.fechado, isTrue);
    pendente.complete(http.Response('{"sucesso":true,"dados":[]}', 200));
    final nova = await http.runWithClient(
      () => service.listar(cidade),
      () => MockClient(
        (_) async => http.Response('{"sucesso":true,"dados":[]}', 200),
      ),
    );
    expect(nova, isEmpty);
  });
  test('falha de conexão é propagada sem mascarar lista vazia', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          service.listar(cidade),
          throwsA(isA<http.ClientException>()),
        );
      },
      () =>
          MockClient((_) async => throw http.ClientException('Falha simulada')),
    );
  });
}
